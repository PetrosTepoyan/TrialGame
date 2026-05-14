class_name SaveSystem
extends Object

# Thin facade over GameState's save/load. Kept for clarity / future
# expansion (e.g. cloud sync). All write operations use a .tmp + rename
# pattern in GameState to avoid corrupt writes on app kill.

static func save() -> void:
	GameState.save_game()

static func load_save() -> void:
	GameState.load_game()

static func reset() -> void:
	GameState.reset_save()
