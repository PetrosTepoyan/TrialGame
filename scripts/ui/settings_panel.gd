class_name SettingsPanel
extends PanelContainer

signal closed

@onready var _music_check: CheckButton = $VBox/Music
@onready var _sfx_check: CheckButton = $VBox/Sfx
@onready var _haptics_check: CheckButton = $VBox/Haptics
@onready var _close_btn: Button = $VBox/Close

func _ready() -> void:
	_music_check.button_pressed = AudioBus.music_enabled()
	_sfx_check.button_pressed = AudioBus.sfx_enabled()
	_haptics_check.button_pressed = Haptics.enabled()
	_music_check.toggled.connect(_on_music_toggled)
	_sfx_check.toggled.connect(_on_sfx_toggled)
	_haptics_check.toggled.connect(_on_haptics_toggled)
	_close_btn.pressed.connect(_on_close_pressed)

func _on_music_toggled(value: bool) -> void:
	AudioBus.play_ui_click()
	AudioBus.set_music_enabled(value)

func _on_sfx_toggled(value: bool) -> void:
	AudioBus.set_sfx_enabled(value)
	# Play the click *after* enabling so a re-enable produces audible feedback.
	AudioBus.play_ui_click()

func _on_haptics_toggled(value: bool) -> void:
	Haptics.set_enabled(value)
	if value:
		Haptics.light_tap()

func _on_close_pressed() -> void:
	AudioBus.play_ui_click()
	AudioBus.play_panel_close()
	Haptics.light_tap()
	visible = false
	emit_signal("closed")
