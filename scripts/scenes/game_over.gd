extends Control

@onready var _retry: Button = $Center/VBox/Retry
@onready var _back: Button = $Center/VBox/Back
@onready var _heading: Label = $Center/VBox/Heading
@onready var _title: Label = $Center/VBox/Title
@onready var _detail: Label = $Center/VBox/Detail

func _ready() -> void:
	SafeArea.apply(self)
	_retry.pressed.connect(_on_retry_pressed)
	# "Quit to Menu" — return to the main menu rather than the chapter map.
	_back.pressed.connect(_on_back_pressed)
	AudioBus.play_defeat_sting()
	_animate_entry()

func _on_retry_pressed() -> void:
	AudioBus.play_ui_click()
	Haptics.medium_tap()
	SceneRouter.goto_battle()

func _on_back_pressed() -> void:
	AudioBus.play_ui_click()
	Haptics.light_tap()
	SceneRouter.goto_main_menu()

func _animate_entry() -> void:
	# Blood-red heading drops in like a slam; supporting copy fades in after.
	_heading.pivot_offset = _heading.size * 0.5
	_heading.scale = Vector2(1.25, 1.25)
	_heading.modulate.a = 0.0
	_title.modulate.a = 0.0
	_detail.modulate.a = 0.0
	_retry.modulate.a = 0.0
	_back.modulate.a = 0.0

	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_heading, "modulate:a", 1.0, 0.35)
	t.tween_property(_heading, "scale", Vector2(1.0, 1.0), 0.45)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.chain().tween_property(_title, "modulate:a", 1.0, 0.35)
	t.chain().tween_property(_detail, "modulate:a", 1.0, 0.35)
	t.chain().tween_property(_retry, "modulate:a", 1.0, 0.35)
	t.chain().tween_property(_back, "modulate:a", 1.0, 0.35)
