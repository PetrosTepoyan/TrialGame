extends Node

@onready var _sfx: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var _music: AudioStreamPlayer = AudioStreamPlayer.new()

var muted: bool = false

func _ready() -> void:
	add_child(_sfx)
	add_child(_music)
	_music.volume_db = -6
	_sfx.volume_db = -3

func play_sfx(stream: AudioStream) -> void:
	if muted or stream == null:
		return
	_sfx.stream = stream
	_sfx.play()

func play_music(stream: AudioStream, loop: bool = true) -> void:
	if stream == null:
		_music.stop()
		return
	if _music.stream == stream and _music.playing:
		return
	_music.stream = stream
	_music.play()
	# Loop handling delegated to the imported stream's loop flag.

func stop_music() -> void:
	_music.stop()

func toggle_mute() -> void:
	muted = not muted
	_music.volume_db = -80 if muted else -6
	_sfx.volume_db = -80 if muted else -3
