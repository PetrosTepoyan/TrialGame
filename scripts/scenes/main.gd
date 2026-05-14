extends Node

# Boot scene: routes immediately to main menu. Kept as a separate scene so
# autoloads have a frame to initialize before we touch state.

func _ready() -> void:
	await get_tree().process_frame
	SceneRouter.goto_main_menu()
