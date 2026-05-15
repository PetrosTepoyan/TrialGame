class_name SettingsPanel
extends PanelContainer

signal closed

@onready var _music_check: CheckButton = $VBox/Music
@onready var _sfx_check: CheckButton = $VBox/Sfx
@onready var _haptics_check: CheckButton = $VBox/Haptics
@onready var _music_volume: HSlider = $VBox/MusicVolumeRow/MusicVolume
@onready var _sfx_volume: HSlider = $VBox/SfxVolumeRow/SfxVolume
@onready var _close_btn: Button = $VBox/Close

# Volume sliders shape the Master bus in dB. The on/off check buttons remain
# the source-of-truth for "play music at all" — the slider rides on top of it
# so a player who keeps music on but mostly quiet can do that.
const _MIN_DB: float = -40.0
const _MAX_DB: float = 0.0

func _ready() -> void:
	_music_check.button_pressed = AudioBus.music_enabled()
	_sfx_check.button_pressed = AudioBus.sfx_enabled()
	_haptics_check.button_pressed = Haptics.enabled()
	_music_check.toggled.connect(_on_music_toggled)
	_sfx_check.toggled.connect(_on_sfx_toggled)
	_haptics_check.toggled.connect(_on_haptics_toggled)
	_music_volume.value_changed.connect(_on_music_volume_changed)
	_sfx_volume.value_changed.connect(_on_sfx_volume_changed)
	_close_btn.pressed.connect(_on_close_pressed)
	# Init slider values from current Master-bus dB if possible.
	_music_volume.value = _read_volume_linear()
	_sfx_volume.value = _read_volume_linear()

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

func _on_music_volume_changed(value: float) -> void:
	# Mirror the slider to the on/off toggle: hard-zero counts as "muted".
	_music_check.button_pressed = value > 0.001
	AudioBus.set_music_enabled(value > 0.001)
	_apply_master_volume(value)

func _on_sfx_volume_changed(value: float) -> void:
	_sfx_check.button_pressed = value > 0.001
	AudioBus.set_sfx_enabled(value > 0.001)
	_apply_master_volume(value)

func _on_close_pressed() -> void:
	AudioBus.play_ui_click()
	AudioBus.play_panel_close()
	Haptics.light_tap()
	visible = false
	emit_signal("closed")

func _read_volume_linear() -> float:
	var idx: int = AudioServer.get_bus_index("Master")
	if idx < 0:
		return 1.0
	var db: float = AudioServer.get_bus_volume_db(idx)
	if db <= _MIN_DB:
		return 0.0
	return clamp(db_to_linear(db), 0.0, 1.0)

func _apply_master_volume(linear: float) -> void:
	var idx: int = AudioServer.get_bus_index("Master")
	if idx < 0:
		return
	if linear <= 0.001:
		AudioServer.set_bus_volume_db(idx, _MIN_DB)
	else:
		AudioServer.set_bus_volume_db(idx, clamp(linear_to_db(linear), _MIN_DB, _MAX_DB))
