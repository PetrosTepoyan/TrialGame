extends Control

const FLAVOR_LINES: Array[String] = [
	"\"The crown is heavy. Heavier still is the road to it.\"",
	"\"Three towers. Three wardens. Then the King.\"",
	"\"Match steel to steel, and the wall will fall.\"",
	"\"They say the throne remembers every name on the wall.\"",
	"\"A banner is only cloth, until you carry it past the gate.\"",
	"\"The Watchtower never sleeps. Neither will you.\"",
]

@onready var _play_button: Button = $Center/VBox/PlayButton
@onready var _reset_button: Button = $Center/VBox/ResetButton
@onready var _quit_button: Button = $Center/VBox/QuitButton
@onready var _settings_button: Button = $Center/VBox/SettingsButton
@onready var _settings_panel: SettingsPanel = $SettingsPanel
@onready var _title: Label = $Center/VBox/Title
@onready var _flavor: Label = $Flavor
@onready var _top_glow: ColorRect = $TopGlow

var _flavor_index: int = 0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	SafeArea.apply(self)
	_rng.randomize()
	_play_button.pressed.connect(_on_play_pressed)
	_reset_button.pressed.connect(_on_reset_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	AudioBus.play_music(AudioBus.load_music("res://assets/audio/music/menu.mp3"))

	_flavor_index = _rng.randi() % FLAVOR_LINES.size()
	_flavor.text = FLAVOR_LINES[_flavor_index]
	_flavor.modulate.a = 0.0

	_start_title_pulse()
	_start_torch_flicker()
	_start_flavor_rotation()
	_fade_in_flavor()

func _start_title_pulse() -> void:
	# Gentle glow on the title — modulate alpha drifts between two values.
	var t := create_tween().set_loops()
	t.tween_property(_title, "modulate", Color(1.0, 0.95, 0.78, 1.0), 2.2)\
		.set_trans(Tween.TRANS_SINE)
	t.tween_property(_title, "modulate", Color(0.97, 0.84, 0.42, 1.0), 2.2)\
		.set_trans(Tween.TRANS_SINE)

func _start_torch_flicker() -> void:
	# The top glow rect simulates torchlight bleeding down the wall — its alpha
	# wobbles on a short random interval rather than a smooth tween.
	var timer := Timer.new()
	timer.wait_time = 0.18
	timer.autostart = true
	timer.timeout.connect(_flicker)
	add_child(timer)

func _flicker() -> void:
	var a: float = 0.04 + _rng.randf() * 0.08
	var c := _top_glow.color
	c.a = a
	_top_glow.color = c

func _start_flavor_rotation() -> void:
	var timer := Timer.new()
	timer.wait_time = 7.0
	timer.autostart = true
	timer.timeout.connect(_rotate_flavor)
	add_child(timer)

func _rotate_flavor() -> void:
	var next_idx: int = (_flavor_index + 1) % FLAVOR_LINES.size()
	if next_idx == _flavor_index:
		next_idx = (next_idx + 1) % FLAVOR_LINES.size()
	_flavor_index = next_idx
	var t := create_tween()
	t.tween_property(_flavor, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE)
	t.tween_callback(func() -> void: _flavor.text = FLAVOR_LINES[_flavor_index])
	t.tween_property(_flavor, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)

func _fade_in_flavor() -> void:
	var t := create_tween()
	t.tween_interval(0.4)
	t.tween_property(_flavor, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE)

func _on_play_pressed() -> void:
	AudioBus.play_ui_click()
	Haptics.light_tap()
	SceneRouter.goto_chapter_map()

func _on_reset_pressed() -> void:
	AudioBus.play_ui_click()
	Haptics.light_tap()
	GameState.reset_save()

func _on_quit_pressed() -> void:
	AudioBus.play_ui_click()
	Haptics.light_tap()
	get_tree().quit()

func _on_settings_pressed() -> void:
	AudioBus.play_ui_click()
	Haptics.light_tap()
	_settings_panel.visible = true
	AudioBus.play_panel_open()
