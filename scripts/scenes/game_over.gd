extends Control

@onready var _retry: Button = $Center/VBox/Retry
@onready var _back: Button = $Center/VBox/Back

func _ready() -> void:
	_retry.pressed.connect(SceneRouter.goto_battle)
	_back.pressed.connect(SceneRouter.goto_chapter_map)
