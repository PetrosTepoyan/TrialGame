extends CanvasLayer

## Autoload. Owns the ShakeDetector, opens the debug menu, persists overrides.

const OVERRIDES_PATH: String = "user://debug_overrides.json"
const DEBUG_ENABLED_PATH: String = "user://debug_enabled"
const DEBUG_MENU_SCENE_PATH: String = "res://scenes/ui/debug_menu.tscn"

var _enabled: bool = false
var _overrides: Dictionary = {}
var _menu: Control = null
var _mini_hud: Control = null
var _shake_detector: Node = null


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

	_enabled = (
		OS.is_debug_build()
		or OS.has_feature("template_debug")
		or FileAccess.file_exists(DEBUG_ENABLED_PATH)
	)
	if not _enabled:
		return

	_load_overrides()

	var ShakeDetectorScript: Script = load("res://scripts/debug/shake_detector.gd")
	if ShakeDetectorScript:
		_shake_detector = ShakeDetectorScript.new()
		_shake_detector.name = "ShakeDetector"
		add_child(_shake_detector)
		if _shake_detector.has_signal("shake_detected"):
			_shake_detector.connect("shake_detected", Callable(self, "_on_shake_detected"))

	_build_mini_hud()


func _on_shake_detected() -> void:
	toggle_menu()


func toggle_menu() -> void:
	if not _enabled:
		return
	if _menu == null:
		_lazy_load_menu()
	if _menu == null:
		return
	if _menu.visible:
		close_menu()
	else:
		open_menu()


func open_menu() -> void:
	if _menu == null:
		_lazy_load_menu()
	if _menu == null:
		return
	_menu.visible = true
	get_tree().paused = true


func close_menu() -> void:
	if _menu == null:
		return
	_menu.visible = false
	get_tree().paused = false


func _lazy_load_menu() -> void:
	var packed := load(DEBUG_MENU_SCENE_PATH)
	if packed == null:
		push_warning("DebugOverlay: failed to load debug_menu.tscn")
		return
	_menu = packed.instantiate()
	_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	_menu.visible = false
	add_child(_menu)
	if _menu.has_method("setup"):
		_menu.setup(self)


# ---- Persistence -----------------------------------------------------------

func _load_overrides() -> void:
	if not FileAccess.file_exists(OVERRIDES_PATH):
		_overrides = {}
		return
	var f := FileAccess.open(OVERRIDES_PATH, FileAccess.READ)
	if f == null:
		_overrides = {}
		return
	var text: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY:
		_overrides = parsed
	else:
		_overrides = {}


func _save_overrides() -> void:
	var f := FileAccess.open(OVERRIDES_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(_overrides))
	f.close()


func set_override(path: String, value: Variant) -> void:
	_overrides[path] = value
	_save_overrides()
	_refresh_mini_hud()


func get_override(path: String, default_value: Variant = null) -> Variant:
	if _overrides.has(path):
		return _overrides[path]
	return default_value


func clear_overrides() -> void:
	_overrides.clear()
	_save_overrides()
	_refresh_mini_hud()


func has_any_overrides() -> bool:
	return not _overrides.is_empty()


func is_enabled() -> bool:
	return _enabled


# ---- Mini HUD --------------------------------------------------------------

func _build_mini_hud() -> void:
	var MiniHudScript: Script = load("res://scripts/debug/debug_mini_hud.gd")
	if MiniHudScript == null:
		return
	_mini_hud = MiniHudScript.new()
	_mini_hud.process_mode = Node.PROCESS_MODE_ALWAYS
	_mini_hud.name = "DebugMiniHud"
	add_child(_mini_hud)
	if _mini_hud.has_method("set_overlay"):
		_mini_hud.set_overlay(self)


func _refresh_mini_hud() -> void:
	if _mini_hud and _mini_hud.has_method("refresh"):
		_mini_hud.refresh()
