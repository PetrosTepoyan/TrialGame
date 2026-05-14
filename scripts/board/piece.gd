class_name Piece
extends Node2D

signal selected(piece: Piece)

const SIZE: float = 96.0
const SELECT_SCALE: float = 1.12
const ANIM_TIME: float = 0.18

var kind: int = 0
var color: Color = Color.WHITE
var board_pos: Vector2i = Vector2i.ZERO
var is_selected: bool = false

var _tween: Tween

func _ready() -> void:
	z_index = 5

func configure(p_kind: int, p_color: Color, p_board_pos: Vector2i) -> void:
	kind = p_kind
	color = p_color
	board_pos = p_board_pos
	queue_redraw()

func set_selected(value: bool) -> void:
	is_selected = value
	_kill_tween()
	_tween = create_tween()
	var s := SELECT_SCALE if value else 1.0
	_tween.tween_property(self, "scale", Vector2(s, s), 0.08)
	queue_redraw()

func tween_to(target: Vector2, duration: float = ANIM_TIME) -> Tween:
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(self, "position", target, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return _tween

func tween_remove() -> Tween:
	_kill_tween()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "scale", Vector2(0.05, 0.05), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_tween.tween_property(self, "modulate:a", 0.0, 0.18)
	return _tween

func _kill_tween() -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()

func _draw() -> void:
	var half: float = SIZE * 0.5
	var rect := Rect2(-half, -half, SIZE, SIZE)
	# Tile background
	draw_rect(rect, Color(0.16, 0.13, 0.20), true)
	# Colored inset
	draw_rect(rect.grow(-6), color, true)
	# Border
	var border := Color(1, 0.95, 0.5, 0.95) if is_selected else Color(1, 1, 1, 0.18)
	draw_rect(rect.grow(-1), border, false, 3.0)
	# Icon for kind
	_draw_kind_icon()

func _draw_kind_icon() -> void:
	var r: float = SIZE * 0.28
	var icon_color := Color(1, 1, 1, 0.92)
	match kind:
		PieceType.Kind.SWORD:
			# Vertical sword: blade pointing up, hilt at bottom.
			var blade_color := Color(0.96, 0.96, 1.00, 1)
			var hilt_color := Color(0.55, 0.40, 0.20, 1)
			var pommel := Color(0.95, 0.78, 0.30, 1)
			# Blade
			draw_line(Vector2(0, -r * 1.05), Vector2(0, r * 0.35), blade_color, 6.0, true)
			# Blade tip triangle
			var tip := PackedVector2Array([
				Vector2(-5, -r * 1.0),
				Vector2(0, -r * 1.25),
				Vector2(5, -r * 1.0),
			])
			draw_colored_polygon(tip, blade_color)
			# Crossguard
			draw_line(Vector2(-r * 0.55, r * 0.35), Vector2(r * 0.55, r * 0.35), pommel, 6.0, true)
			# Grip
			draw_line(Vector2(0, r * 0.40), Vector2(0, r * 0.80), hilt_color, 6.0, true)
			# Pommel
			draw_circle(Vector2(0, r * 0.85), 5.0, pommel)
		PieceType.Kind.SHIELD:
			var w: float = SIZE * 0.34
			var h: float = SIZE * 0.40
			var pts := PackedVector2Array([
				Vector2(-w * 0.5, -h * 0.45),
				Vector2(w * 0.5, -h * 0.45),
				Vector2(w * 0.5, h * 0.05),
				Vector2(0, h * 0.5),
				Vector2(-w * 0.5, h * 0.05),
			])
			draw_colored_polygon(pts, icon_color)
			# Cross
			draw_rect(Rect2(-w * 0.06, -h * 0.30, w * 0.12, h * 0.55), Color(0, 0, 0, 0.35), true)
			draw_rect(Rect2(-w * 0.24, -h * 0.10, w * 0.48, h * 0.12), Color(0, 0, 0, 0.35), true)
		PieceType.Kind.STAFF:
			# Magic staff: vertical shaft + orb at top
			var shaft_color := Color(0.60, 0.42, 0.25, 1)
			var orb_color := Color(0.85, 0.55, 1.00, 1)
			# Shaft
			draw_line(Vector2(0, r * 1.0), Vector2(0, -r * 0.55), shaft_color, 5.0, true)
			# Wrapped grip
			draw_line(Vector2(0, r * 0.45), Vector2(0, r * 0.85), shaft_color.darkened(0.3), 6.0, true)
			# Orb at top
			draw_circle(Vector2(0, -r * 0.75), 11.0, orb_color)
			draw_circle(Vector2(0, -r * 0.75), 7.0, orb_color.lightened(0.4))
			draw_circle(Vector2(-3, -r * 0.78), 3.0, Color.WHITE)
			# Sparkles
			draw_circle(Vector2(r * 0.55, -r * 0.45), 2.5, Color(1, 1, 1, 0.8))
			draw_circle(Vector2(-r * 0.50, -r * 0.30), 2.0, Color(1, 1, 1, 0.6))
			draw_circle(Vector2(r * 0.30, -r * 0.95), 2.0, Color(1, 1, 1, 0.6))
		PieceType.Kind.BOW:
			# Bow: arc + arrow
			draw_arc(Vector2.ZERO, r, deg_to_rad(-70), deg_to_rad(70), 24, icon_color, 4.0, true)
			# String
			draw_line(Vector2(r * 0.34, -r * 0.94), Vector2(r * 0.34, r * 0.94), icon_color, 2.0, true)
			# Arrow
			draw_line(Vector2(-r * 0.6, 0), Vector2(r * 0.4, 0), icon_color, 2.5, true)
			# Arrowhead
			var ah := PackedVector2Array([
				Vector2(r * 0.4, -4),
				Vector2(r * 0.65, 0),
				Vector2(r * 0.4, 4),
			])
			draw_colored_polygon(ah, icon_color)
			# Fletching
			draw_line(Vector2(-r * 0.6, 0), Vector2(-r * 0.75, -4), icon_color, 1.5, true)
			draw_line(Vector2(-r * 0.6, 0), Vector2(-r * 0.75, 4), icon_color, 1.5, true)
