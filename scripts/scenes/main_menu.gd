extends Control

@onready var _play_button: Button = $Center/VBox/PlayButton
@onready var _reset_button: Button = $Center/VBox/ResetButton
@onready var _quit_button: Button = $Center/VBox/QuitButton
@onready var _mute_button: Button = $Center/VBox/MuteButton
@onready var _title: Label = $Center/VBox/Title
@onready var _subtitle: Label = $Center/VBox/Subtitle

func _ready() -> void:
	_title.text = "Three Towers"
	_subtitle.text = "A medieval match-3 war"
	_play_button.pressed.connect(_on_play_pressed)
	_reset_button.pressed.connect(_on_reset_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_mute_button.pressed.connect(_on_mute_pressed)
	AudioBus.play_music(AudioBus.load_music("res://assets/audio/music/menu.mp3"))

func _on_play_pressed() -> void:
	SceneRouter.goto_chapter_map()

func _on_reset_pressed() -> void:
	GameState.reset_save()

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_mute_pressed() -> void:
	AudioBus.toggle_mute()
	_mute_button.text = "Sound: OFF" if AudioBus.muted else "Sound: ON"
