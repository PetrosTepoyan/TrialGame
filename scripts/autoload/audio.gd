extends Node

# Audio autoload. Preloads a small set of SFX from assets/audio/sfx and exposes
# semantic methods (play_swap, play_match, ...). Missing files degrade silently
# — useful so the project runs even before assets are imported.

@onready var _sfx: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var _music: AudioStreamPlayer = AudioStreamPlayer.new()

var muted: bool = false

var sfx_swap: AudioStream
var sfx_match: AudioStream
var sfx_invalid: AudioStream
var sfx_hit: AudioStream
var sfx_round: AudioStream

func _ready() -> void:
	add_child(_sfx)
	add_child(_music)
	_music.volume_db = -6
	_sfx.volume_db = -3
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

func play_sfx(stream: AudioStream) -> void:
	if muted or stream == null:
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
	# Both AudioStreamMP3 and AudioStreamOggVorbis expose a `loop` property.
	if loop:
		if stream is AudioStreamMP3:
			(stream as AudioStreamMP3).loop = true
		elif stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
	_music.stream = stream
	_music.play()

func load_music(path: String) -> AudioStream:
	return _try_load(path)

func stop_music() -> void:
	_music.stop()

func toggle_mute() -> void:
	muted = not muted
	_music.volume_db = -80 if muted else -6
	_sfx.volume_db = -80 if muted else -3
