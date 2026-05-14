extends Node

# Audio autoload. Preloads SFX from assets/audio/sfx and exposes semantic
# play_*() methods plus toggleable music + sfx channels persisted on
# GameState's save (via _music_enabled / _sfx_enabled).

@onready var _sfx: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var _music: AudioStreamPlayer = AudioStreamPlayer.new()

const SFX_DB_ON: float = -3.0
const MUSIC_DB_ON: float = -6.0
const DB_OFF: float = -80.0

var _music_enabled: bool = true
var _sfx_enabled: bool = true

var sfx_swap: AudioStream
var sfx_match: AudioStream
var sfx_invalid: AudioStream
var sfx_hit: AudioStream
var sfx_round: AudioStream

func _ready() -> void:
	add_child(_sfx)
	add_child(_music)
	_sfx.volume_db = SFX_DB_ON
	_music.volume_db = MUSIC_DB_ON
	sfx_swap = _try_load("res://assets/audio/sfx/swap.ogg")
	sfx_match = _try_load("res://assets/audio/sfx/match.ogg")
	sfx_invalid = _try_load("res://assets/audio/sfx/invalid.ogg")
	sfx_hit = _try_load("res://assets/audio/sfx/hit.ogg")
	sfx_round = _try_load("res://assets/audio/sfx/round_execute.ogg")

func _try_load(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	var res: Resource = load(path)
	if res is AudioStream:
		return res
	return null

func load_music(path: String) -> AudioStream:
	return _try_load(path)

func play_sfx(stream: AudioStream) -> void:
	if not _sfx_enabled or stream == null:
		return
	_sfx.stream = stream
	_sfx.play()

func play_swap() -> void: play_sfx(sfx_swap)
func play_match() -> void: play_sfx(sfx_match)
func play_invalid() -> void: play_sfx(sfx_invalid)
func play_hit() -> void: play_sfx(sfx_hit)
func play_round_execute() -> void: play_sfx(sfx_round)

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

# Settings toggles ----------------------------------------------------------

func music_enabled() -> bool:
	return _music_enabled

func sfx_enabled() -> bool:
	return _sfx_enabled

func set_music_enabled(value: bool) -> void:
	_music_enabled = value
	_music.volume_db = MUSIC_DB_ON if value else DB_OFF
	if not value and _music.playing:
		_music.stop()
	elif value and _music.stream != null and not _music.playing:
		_music.play()

func set_sfx_enabled(value: bool) -> void:
	_sfx_enabled = value
	_sfx.volume_db = SFX_DB_ON if value else DB_OFF
