extends Control

@onready var _retry: Button = $Center/VBox/Retry
@onready var _back: Button = $Center/VBox/Back

func _ready() -> void:
	SafeArea.apply(self)
	_retry.pressed.connect(_on_retry_pressed)
	_back.pressed.connect(_on_back_pressed)

func _on_retry_pressed() -> void:
	Haptics.medium_tap()
	SceneRouter.goto_battle()

func _on_back_pressed() -> void:
	Haptics.light_tap()
	SceneRouter.goto_chapter_map()
