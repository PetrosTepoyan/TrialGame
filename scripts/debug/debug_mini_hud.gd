extends Control

## Tiny top-right FPS counter + overrides-active dot.

const FONT_SIZE: int = 18
const PADDING: int = 8
const DOT_RADIUS: float = 4.0

var _overlay: Node = null
var _fps_label: Label = null
var _dot: ColorRect = null
var _enabled: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	custom_minimum_size = Vector2(120, 24)
	# Position from the top-right corner.
	offset_left = -120
	offset_top = 0
	offset_right = 0
	offset_bottom = 32

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", PADDING)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(row)

	_dot = ColorRect.new()
	_dot.custom_minimum_size = Vector2(8, 8)
	_dot.color = Color(0.2, 1.0, 0.4, 0.6)
	_dot.visible = false
	row.add_child(_dot)

	_fps_label = Label.new()
	_fps_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_fps_label.modulate = Color(1, 1, 1, 0.7)
	_fps_label.text = "-- fps"
	row.add_child(_fps_label)

	set_process(true)


func set_overlay(overlay: Node) -> void:
	_overlay = overlay
	refresh()


func set_hud_enabled(state: bool) -> void:
	_enabled = state
	visible = state


func refresh() -> void:
	if _overlay and _dot:
		_dot.visible = _overlay.has_any_overrides()


func _process(_delta: float) -> void:
	if not _enabled:
		return
	if _fps_label:
		_fps_label.text = "%d fps" % Engine.get_frames_per_second()
	refresh()


func _gui_input(event: InputEvent) -> void:
	# Tap to toggle, but the control ignores input by default — leave for future.
	pass
