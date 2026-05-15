extends Control

@onready var _retry: Button = $Center/VBox/Retry
@onready var _back: Button = $Center/VBox/Back

func _ready() -> void:
	SafeArea.apply(self)
	_retry.pressed.connect(_on_retry_pressed)
	_back.pressed.connect(_on_back_pressed)
	AudioBus.play_defeat_sting()

func _on_retry_pressed() -> void:
	AudioBus.play_ui_click()
	Haptics.medium_tap()
	SceneRouter.goto_battle()

func _on_back_pressed() -> void:
	AudioBus.play_ui_click()
	Haptics.light_tap()
	SceneRouter.goto_chapter_map()
