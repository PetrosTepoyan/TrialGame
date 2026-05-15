extends Node

# Applies the platform's safe-area insets (iPhone dynamic island / home indicator,
# Android cutouts, etc.) to a full-screen scene-root Control. Scenes call
# SafeArea.apply(self) from _ready(); on desktop this is a no-op.

func apply(root: Control) -> void:
	if root == null:
		return
	# Always start from the clean full-screen rect, then push the inner content
	# inward by the safe-area margins. _ready may run before the viewport size
	# is final, so re-apply on resize too.
	_apply_once(root)
	if not root.is_inside_tree():
		return
	if not root.get_viewport().size_changed.is_connected(_apply_once.bind(root)):
		root.get_viewport().size_changed.connect(_apply_once.bind(root))

func _apply_once(root: Control) -> void:
	if not is_instance_valid(root):
		return
	var safe := DisplayServer.get_display_safe_area()
	var screen_size := DisplayServer.window_get_size(0)
	if screen_size.x <= 0 or screen_size.y <= 0:
		return
	# On desktop the safe area equals the screen, so the insets all come out zero.
	var top_px: int = safe.position.y
	var left_px: int = safe.position.x
	var right_px: int = screen_size.x - (safe.position.x + safe.size.x)
	var bottom_px: int = screen_size.y - (safe.position.y + safe.size.y)
	if top_px == 0 and left_px == 0 and right_px == 0 and bottom_px == 0:
		return

	# Map device pixels -> viewport units using the visible-rect / window-size
	# ratio that the stretch system has settled on.
	var viewport: Vector2 = root.get_viewport().get_visible_rect().size
	var scale_x: float = viewport.x / float(screen_size.x)
	var scale_y: float = viewport.y / float(screen_size.y)
	root.offset_top = top_px * scale_y
	root.offset_bottom = -bottom_px * scale_y
	root.offset_left = left_px * scale_x
	root.offset_right = -right_px * scale_x
