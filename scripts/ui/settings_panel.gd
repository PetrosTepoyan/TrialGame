class_name SettingsPanel
extends PanelContainer

signal closed

@onready var _music_check: CheckButton = $VBox/Music
@onready var _sfx_check: CheckButton = $VBox/Sfx
@onready var _close_btn: Button = $VBox/Close

func _ready() -> void:
	_music_check.button_pressed = AudioBus.music_enabled()
	_sfx_check.button_pressed = AudioBus.sfx_enabled()
	_music_check.toggled.connect(_on_music_toggled)
	_sfx_check.toggled.connect(_on_sfx_toggled)
	_close_btn.pressed.connect(_on_close_pressed)

func _on_music_toggled(value: bool) -> void:
	AudioBus.set_music_enabled(value)

func _on_sfx_toggled(value: bool) -> void:
	AudioBus.set_sfx_enabled(value)

func _on_close_pressed() -> void:
	visible = false
	emit_signal("closed")
