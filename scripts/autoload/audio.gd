extends Node

# Preload (not class_name lookup) — autoloads parse before any class_name
# scripts have been registered, so we have to reference the procedural helper
# by its absolute path.
const ProceduralAudioCls := preload("res://scripts/util/procedural_audio.gd")

# Audio autoload. Preloads SFX from assets/audio/sfx and exposes semantic
# play_*() methods plus toggleable music + sfx channels persisted on
# GameState's save (via _music_enabled / _sfx_enabled).
#
# Layered design:
#   - A small pool of one-shot AudioStreamPlayers so overlapping events
#     (UI click during a match cascade, status blip on top of a hit) don't
#     cut each other off.
#   - Pitch / volume modulation per call, so a single sample doubles as
#     several flavored cues (combo length, per-piece-kind hits).
#   - Procedural fallback streams synthesized at boot when a .ogg is missing
#     — keeps the audio surface alive before licensed packs land.

const SFX_DB_ON: float = -3.0
const MUSIC_DB_ON: float = -6.0
const DB_OFF: float = -80.0
const DUCK_DB: float = -16.0

# Concurrent SFX channels. Five lets a UI click, a status blip, a hit, and a
# combo zap all coexist without clobbering. Round-robin assignment.
const SFX_PLAYER_COUNT: int = 5

# Pitch-by-combo-length curve.
const PITCH_MATCH_3: float = 1.00
const PITCH_MATCH_4: float = 1.18
const PITCH_MATCH_5_PLUS: float = 1.42

@onready var _music: AudioStreamPlayer = AudioStreamPlayer.new()

var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_next_index: int = 0

var _music_enabled: bool = true
var _sfx_enabled: bool = true
var _sfx_volume: float = 1.0   # 0..1 user slider, multiplies SFX_DB_ON
var _music_volume: float = 1.0 # 0..1 user slider, multiplies MUSIC_DB_ON

var sfx_swap: AudioStream
var sfx_match: AudioStream
var sfx_invalid: AudioStream
var sfx_hit: AudioStream
var sfx_round: AudioStream

# UI / combat extras (procedurally generated when no .ogg exists).
var sfx_ui_click: AudioStream
var sfx_ui_hover: AudioStream
var sfx_panel_open: AudioStream
var sfx_panel_close: AudioStream
var sfx_combo_l1: AudioStream
var sfx_combo_l2: AudioStream
var sfx_combo_l3: AudioStream
var sfx_victory: AudioStream
var sfx_defeat: AudioStream
var sfx_status: Array[AudioStream] = []  # indexed by StatusEffect.Kind ordinal

var _duck_tween: Tween = null

func _ready() -> void:
	add_child(_music)
	_music.volume_db = _music_target_db()
	for i in range(SFX_PLAYER_COUNT):
		var p := AudioStreamPlayer.new()
		p.volume_db = _sfx_target_db()
		add_child(p)
		_sfx_players.append(p)
	# Disk SFX — these all exist today (assets/audio/sfx/*.ogg).
	sfx_swap = _try_load("res://assets/audio/sfx/swap.ogg")
	sfx_match = _try_load("res://assets/audio/sfx/match.ogg")
	sfx_invalid = _try_load("res://assets/audio/sfx/invalid.ogg")
	sfx_hit = _try_load("res://assets/audio/sfx/hit.ogg")
	sfx_round = _try_load("res://assets/audio/sfx/round_execute.ogg")
	# Optional UI / stinger SFX — if missing, synthesize procedural fallbacks.
	sfx_ui_click = _try_load_or("res://assets/audio/sfx/ui_click.ogg", ProceduralAudioCls.ui_click())
	sfx_ui_hover = _try_load_or("res://assets/audio/sfx/ui_hover.ogg", ProceduralAudioCls.ui_hover())
	sfx_panel_open = _try_load_or("res://assets/audio/sfx/panel_open.ogg", ProceduralAudioCls.panel_open())
	sfx_panel_close = _try_load_or("res://assets/audio/sfx/panel_close.ogg", ProceduralAudioCls.panel_close())
	sfx_combo_l1 = _try_load_or("res://assets/audio/sfx/combo_l1.ogg", ProceduralAudioCls.combo_zap(1))
	sfx_combo_l2 = _try_load_or("res://assets/audio/sfx/combo_l2.ogg", ProceduralAudioCls.combo_zap(2))
	sfx_combo_l3 = _try_load_or("res://assets/audio/sfx/combo_l3.ogg", ProceduralAudioCls.combo_zap(3))
	sfx_victory = _try_load_or("res://assets/audio/sfx/victory.ogg", ProceduralAudioCls.victory_sting())
	sfx_defeat = _try_load_or("res://assets/audio/sfx/defeat.ogg", ProceduralAudioCls.defeat_sting())
	# Build a status-effect blip per kind, with a procedural default.
	sfx_status.resize(6)
	for k in range(6):
		sfx_status[k] = ProceduralAudioCls.status_blip(k)

func _try_load(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	var res: Resource = load(path)
	if res is AudioStream:
		return res
	return null

func _try_load_or(path: String, fallback: AudioStream) -> AudioStream:
	var loaded: AudioStream = _try_load(path)
	if loaded != null:
		return loaded
	return fallback

func load_music(path: String) -> AudioStream:
	return _try_load(path)

# --- Core playback ---------------------------------------------------------

func _next_player() -> AudioStreamPlayer:
	# Prefer an idle player to avoid stealing a still-playing cue. Round-robin
	# fallback when every player is busy keeps the eviction predictable.
	for i in range(SFX_PLAYER_COUNT):
		var idx: int = (_sfx_next_index + i) % SFX_PLAYER_COUNT
		var p: AudioStreamPlayer = _sfx_players[idx]
		if not p.playing:
			_sfx_next_index = (idx + 1) % SFX_PLAYER_COUNT
			return p
	var fallback: AudioStreamPlayer = _sfx_players[_sfx_next_index]
	_sfx_next_index = (_sfx_next_index + 1) % SFX_PLAYER_COUNT
	return fallback

func play_sfx(stream: AudioStream, pitch: float = 1.0, db_offset: float = 0.0) -> void:
	if not _sfx_enabled or stream == null:
		return
	var p: AudioStreamPlayer = _next_player()
	p.stream = stream
	p.pitch_scale = max(0.01, pitch)
	p.volume_db = _sfx_target_db() + db_offset
	p.play()

# --- Backward-compatible semantic helpers (additive args) ------------------

func play_swap() -> void:
	play_sfx(sfx_swap)

func play_match(combo_length: int = 3) -> void:
	# Pitch the same sample up for longer runs so a 5-match feels distinct
	# from a 3-match without needing extra assets.
	var pitch: float = PITCH_MATCH_3
	if combo_length >= 5:
		pitch = PITCH_MATCH_5_PLUS
	elif combo_length == 4:
		pitch = PITCH_MATCH_4
	play_sfx(sfx_match, pitch)

func play_invalid() -> void:
	play_sfx(sfx_invalid)

func play_hit() -> void:
	# Untyped hit — kept for callers that don't know the source kind yet.
	play_sfx(sfx_hit)

func play_kind_hit(kind: int) -> void:
	# Each piece kind gets its own pitch shape so the player can hear what
	# delivered the damage. Reuses the single hit sample.
	if sfx_hit == null:
		return
	var pitch: float = 1.0
	var db: float = 0.0
	match kind:
		0: # SWORD — meaty, dead-center pitch
			pitch = 0.96
		1: # SHIELD — slightly damp, lower
			pitch = 0.82
			db = -2.0
		2: # STAFF — airy, higher
			pitch = 1.22
		3: # BOW — sharp, even higher
			pitch = 1.35
		_:
			pitch = 1.0
	play_sfx(sfx_hit, pitch, db)

func play_round_execute() -> void:
	play_sfx(sfx_round)

# --- UI ---------------------------------------------------------------------

func play_ui_click() -> void:
	play_sfx(sfx_ui_click)

func play_ui_hover() -> void:
	play_sfx(sfx_ui_hover, 1.0, -4.0)

func play_panel_open() -> void:
	play_sfx(sfx_panel_open)

func play_panel_close() -> void:
	play_sfx(sfx_panel_close)

# --- Combo / status / stingers --------------------------------------------

func play_combo(level: int) -> void:
	var stream: AudioStream = sfx_combo_l1
	var db: float = -3.0
	match level:
		1:
			stream = sfx_combo_l1
			db = -3.0
		2:
			stream = sfx_combo_l2
			db = -1.0
		_:
			stream = sfx_combo_l3
			db = 0.0
	play_sfx(stream, 1.0, db)

func play_status(kind: int) -> void:
	# Status blips lean on the procedural set, but if a real DoT/stun sample
	# lands later just drop it into sfx_status[k] and this keeps working.
	if kind < 0 or kind >= sfx_status.size():
		return
	var stream: AudioStream = sfx_status[kind]
	# Burns/cold/etc. are background flavor — keep them quieter than hits.
	play_sfx(stream, 1.0, -4.0)

func play_victory_sting() -> void:
	play_sfx(sfx_victory, 1.0, 1.0)

func play_defeat_sting() -> void:
	play_sfx(sfx_defeat, 1.0, 1.0)

# --- Music ------------------------------------------------------------------

func play_music(stream: AudioStream, loop: bool = true) -> void:
	if stream == null:
		_music.stop()
		return
	if _music.stream == stream and _music.playing:
		return
	if loop:
		if stream is AudioStreamMP3:
			(stream as AudioStreamMP3).loop = true
		elif stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
	_music.stream = stream
	if _music_enabled:
		_music.play()

func stop_music() -> void:
	_music.stop()

func duck_music_briefly() -> void:
	# Pull music volume down to DUCK_DB instantly, then ramp back up to the
	# user's configured target. Used when a round resolves so the resolution
	# SFX cuts through cleanly.
	if not _music_enabled:
		return
	if _duck_tween != null and _duck_tween.is_valid():
		_duck_tween.kill()
	var target: float = _music_target_db()
	_music.volume_db = DUCK_DB
	_duck_tween = create_tween()
	_duck_tween.tween_interval(0.15)
	_duck_tween.tween_property(_music, "volume_db", target, 0.45)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

# --- Settings toggles & volume -------------------------------------------

func music_enabled() -> bool:
	return _music_enabled

func sfx_enabled() -> bool:
	return _sfx_enabled

func sfx_volume() -> float:
	return _sfx_volume

func music_volume() -> float:
	return _music_volume

func set_music_enabled(value: bool) -> void:
	_music_enabled = value
	_music.volume_db = _music_target_db()
	if not value and _music.playing:
		_music.stop()
	elif value and _music.stream != null and not _music.playing:
		_music.play()

func set_sfx_enabled(value: bool) -> void:
	_sfx_enabled = value
	var db: float = _sfx_target_db()
	for p in _sfx_players:
		p.volume_db = db

func set_sfx_volume(value: float) -> void:
	# 0..1 multiplier on top of the on/off boolean — at value=0 we drive down
	# to DB_OFF, at value=1 we sit at SFX_DB_ON. Linear-in-decibels feels
	# closer to user expectations than a pure dB scale here.
	_sfx_volume = clamp(value, 0.0, 1.0)
	for p in _sfx_players:
		p.volume_db = _sfx_target_db()

func set_music_volume(value: float) -> void:
	_music_volume = clamp(value, 0.0, 1.0)
	_music.volume_db = _music_target_db()

# --- Internal volume math -------------------------------------------------

func _sfx_target_db() -> float:
	if not _sfx_enabled:
		return DB_OFF
	if _sfx_volume <= 0.0:
		return DB_OFF
	# Map slider 0..1 -> [DB_OFF .. SFX_DB_ON], with most of the perceptual
	# range concentrated in the top half.
	return lerp(DB_OFF, SFX_DB_ON, sqrt(_sfx_volume))

func _music_target_db() -> float:
	if not _music_enabled:
		return DB_OFF
	if _music_volume <= 0.0:
		return DB_OFF
	return lerp(DB_OFF, MUSIC_DB_ON, sqrt(_music_volume))
