extends Control

@onready var _continue: Button = $Center/VBox/Continue
@onready var _label: Label = $Center/VBox/Label
@onready var _detail: Label = $Center/VBox/Detail

func _ready() -> void:
	SafeArea.apply(self)
	_continue.pressed.connect(_on_continue_pressed)
	_label.text = "Castle Conquered"
	_detail.text = "%s falls. You ride to the next stronghold." % GameState.current_castle.castle_name

func _on_continue_pressed() -> void:
	Haptics.light_tap()
	SceneRouter.goto_chapter_map()
