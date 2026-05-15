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
	# Bleed Ink (matches the boot splash) into the safe-area bands so we don't
	# show a seam against a battle's level colour if we just came back from one.
	RenderingServer.set_default_clear_color(Color(0.07, 0.05, 0.09))
	_rng.randomize()
	_play_button.pressed.connect(_on_play_pressed)
	# Phase E rename: "Start Fresh Run" is the canonical voluntary-reset action.
	_reset_button.text = "Start Fresh Run"
	_reset_button.pressed.connect(_on_reset_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	AudioBus.play_music(AudioBus.load_music("res://assets/audio/music/menu.mp3"))

	_flavor_index = _rng.randi() % FLAVOR_LINES.size()
	_flavor.text = FLAVOR_LINES[_flavor_index]
	_flavor.modulate.a = 0.0

	# Subtle bounce on hover / press — applied via tween so each button feels
	# tactile without per-button shader work (iOS GL Compatibility-safe).
	_wire_bounce(_play_button)
	_wire_bounce(_settings_button)
	_wire_bounce(_reset_button)
	_wire_bounce(_quit_button)

	_start_title_pulse()
	_start_torch_flicker()
	_start_flavor_rotation()
	_fade_in_flavor()

	# v2 save-format wipe notice. Shown once, then dismissed.
	if not GameState.save_v1_wipe_notice_shown:
		call_deferred("_show_save_wipe_banner")

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
	_show_reset_confirmation()

func _show_reset_confirmation() -> void:
	# Use ConfirmationDialog so we get cross-platform OK/Cancel without bespoke
	# UI. Same dialog wording works for the in-battle settings panel too.
	var d := ConfirmationDialog.new()
	d.dialog_text = "Start a fresh run? This deletes all progress."
	d.title = "Start Fresh Run"
	d.ok_button_text = "Start Fresh"
	d.get_cancel_button().text = "Cancel"
	add_child(d)
	d.confirmed.connect(_on_reset_confirmed.bind(d))
	d.canceled.connect(func() -> void: d.queue_free())
	d.popup_centered()

func _on_reset_confirmed(d: ConfirmationDialog) -> void:
	GameState.reset_save()
	d.queue_free()
	# Reload the menu so its widgets reflect the freshly-wiped state.
	SceneRouter.goto_main_menu()

func _show_save_wipe_banner() -> void:
	# One-time banner after a v1 → v2 save migration. Acknowledgement dismisses
	# the flag so the player only sees it once.
	var d := AcceptDialog.new()
	d.dialog_text = "Save format updated for new game version — fresh start required."
	d.title = "Save Reset"
	add_child(d)
	d.confirmed.connect(func() -> void:
		GameState.dismiss_save_wipe_notice()
		d.queue_free()
	)
	d.canceled.connect(func() -> void:
		GameState.dismiss_save_wipe_notice()
		d.queue_free()
	)
	d.popup_centered()

func _on_quit_pressed() -> void:
	AudioBus.play_ui_click()
	Haptics.light_tap()
	get_tree().quit()

func _on_settings_pressed() -> void:
	AudioBus.play_ui_click()
	Haptics.light_tap()
	_settings_panel.visible = true
	AudioBus.play_panel_open()

func _wire_bounce(btn: Button) -> void:
	# Tween scale on enter/exit/down/up — gives the button a "press" feel.
	btn.pivot_offset = btn.size * 0.5
	btn.resized.connect(func() -> void: btn.pivot_offset = btn.size * 0.5)
	btn.mouse_entered.connect(func() -> void: _tween_scale(btn, Vector2(1.03, 1.03), 0.12))
	btn.mouse_exited.connect(func() -> void: _tween_scale(btn, Vector2(1.0, 1.0), 0.18))
	btn.button_down.connect(func() -> void: _tween_scale(btn, Vector2(0.96, 0.96), 0.06))
	btn.button_up.connect(func() -> void: _tween_scale(btn, Vector2(1.0, 1.0), 0.14))

func _tween_scale(btn: Button, target: Vector2, duration: float) -> void:
	if not is_instance_valid(btn):
		return
	var t := create_tween()
	t.tween_property(btn, "scale", target, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
