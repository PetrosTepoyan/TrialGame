class_name ActionScaleSlot
extends Control

var _emblem: Emblem = null
var _flash_alpha: float = 0.0

func set_emblem(e: Emblem) -> void:
	_emblem = e
	queue_redraw()
	if e != null:
		_pop_in()

func _pop_in() -> void:
	scale = Vector2(0.4, 0.4)
	pivot_offset = size * 0.5
	var t := create_tween()
	t.tween_property(self, "scale", Vector2(1.15, 1.15), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "scale", Vector2(1.0, 1.0), 0.08)

func flash() -> void:
	_flash_alpha = 1.0
	queue_redraw()
	var t := create_tween()
	t.tween_method(_set_flash, 1.0, 0.0, 0.45)

func _set_flash(v: float) -> void:
	_flash_alpha = v
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	# Slot frame
	draw_rect(rect, Color(0.10, 0.08, 0.12, 0.85), true)
	draw_rect(rect.grow(-2), Color(0.85, 0.72, 0.30, 0.45), false, 2.0)
	if _emblem == null:
		# Empty: subtle dashed center marker
		var c := size * 0.5
		draw_circle(c, 4.0, Color(0.4, 0.36, 0.28, 0.5))
		return
	var col := _emblem_color(_emblem.piece_kind)
	# Inset color block
	draw_rect(rect.grow(-6), col, true)
	# Mini icon (simplified version of the piece icon)
	_draw_mini_icon(_emblem.piece_kind)
	# Level pip(s) in corner
	var level := _emblem.level
	var dot_color := Color(1.0, 0.92, 0.50, 1)
	for i in range(level):
		var p := Vector2(size.x - 8 - i * 7, size.y - 8)
		draw_circle(p, 3.0, dot_color)
	if _flash_alpha > 0.0:
		draw_rect(rect, Color(1, 1, 1, _flash_alpha * 0.5), true)

func _emblem_color(kind: int) -> Color:
	match kind:
		PieceType.Kind.SWORD: return Color(0.95, 0.78, 0.30)
		PieceType.Kind.SHIELD: return Color(0.40, 0.62, 0.95)
		PieceType.Kind.STAFF: return Color(0.66, 0.36, 0.85)
		PieceType.Kind.BOW: return Color(0.40, 0.82, 0.50)
	return Color.WHITE

func _draw_mini_icon(kind: int) -> void:
	var c := size * 0.5
	var r: float = size.x * 0.22
	var ic := Color(1, 1, 1, 0.9)
	match kind:
		PieceType.Kind.SWORD:
			draw_line(c + Vector2(0, -r), c + Vector2(0, r * 0.7), ic, 3.0, true)
			draw_line(c + Vector2(-r * 0.5, r * 0.3), c + Vector2(r * 0.5, r * 0.3), ic, 3.0, true)
		PieceType.Kind.SHIELD:
			var w: float = r * 1.4
			var h: float = r * 1.6
			var pts := PackedVector2Array([
				c + Vector2(-w * 0.5, -h * 0.4),
				c + Vector2(w * 0.5, -h * 0.4),
				c + Vector2(w * 0.5, h * 0.0),
				c + Vector2(0, h * 0.5),
				c + Vector2(-w * 0.5, h * 0.0),
			])
			draw_colored_polygon(pts, ic)
		PieceType.Kind.STAFF:
			draw_line(c + Vector2(0, r * 0.8), c + Vector2(0, -r * 0.5), ic, 3.0, true)
			draw_circle(c + Vector2(0, -r * 0.7), 5.0, ic)
		PieceType.Kind.BOW:
			draw_arc(c, r, deg_to_rad(-70), deg_to_rad(70), 16, ic, 3.0, true)
			draw_line(c + Vector2(-r * 0.4, 0), c + Vector2(r * 0.4, 0), ic, 2.0, true)
