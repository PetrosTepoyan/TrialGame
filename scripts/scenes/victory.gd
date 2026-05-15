extends Control

@onready var _continue: Button = $Center/VBox/Continue
@onready var _label: Label = $Center/VBox/Label
@onready var _title: Label = $Center/VBox/Title
@onready var _detail: Label = $Center/VBox/Detail

func _ready() -> void:
	SafeArea.apply(self)
	_continue.pressed.connect(_on_continue_pressed)
	_title.text = "Castle Conquered"
	_detail.text = "%s falls. You ride to the next stronghold." % GameState.current_castle.castle_name
	AudioBus.play_victory_sting()
	_animate_entry()

func _on_continue_pressed() -> void:
	AudioBus.play_ui_click()
	Haptics.light_tap()
	SceneRouter.goto_chapter_map()

func _animate_entry() -> void:
	# Big VICTORY heading drops in with a punch-then-settle, while the
	# detail/title fade in underneath it.
	_label.pivot_offset = _label.size * 0.5
	_label.scale = Vector2(0.4, 0.4)
	_label.modulate.a = 0.0
	_title.modulate.a = 0.0
	_detail.modulate.a = 0.0
	_continue.modulate.a = 0.0

	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_label, "modulate:a", 1.0, 0.35)
	t.tween_property(_label, "scale", Vector2(1.08, 1.08), 0.45)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.chain().tween_property(_label, "scale", Vector2(1.0, 1.0), 0.18)\
		.set_trans(Tween.TRANS_SINE)
	t.chain().tween_property(_title, "modulate:a", 1.0, 0.4)
	t.chain().tween_property(_detail, "modulate:a", 1.0, 0.4)
	t.chain().tween_property(_continue, "modulate:a", 1.0, 0.4)
