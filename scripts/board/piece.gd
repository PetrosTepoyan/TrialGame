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
var is_input_blocked: bool = false

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

func _input(event: InputEvent) -> void:
	pass

func _draw() -> void:
	var half: float = SIZE * 0.5
	var rect := Rect2(-half, -half, SIZE, SIZE)
	# Tile background
	var bg := Color(0.16, 0.13, 0.20)
	draw_rect(rect, bg, true)
	# Colored inset
	var inset_rect := rect.grow(-6)
	draw_rect(inset_rect, color, true)
	# Border
	var border := Color(1, 1, 1, 0.18) if not is_selected else Color(1, 0.95, 0.5, 0.95)
	draw_rect(rect.grow(-1), border, false, 3.0)
	# Icon for kind
	_draw_kind_icon()

func _draw_kind_icon() -> void:
	var center := Vector2.ZERO
	var r: float = SIZE * 0.28
	var icon_color := Color(1, 1, 1, 0.92)
	match kind:
		PieceType.Kind.KING:
			# Crown: trapezoid + 3 spikes
			var w: float = SIZE * 0.42
			var h: float = SIZE * 0.18
			var top_y: float = -h * 0.5
			var bot_y: float = h * 0.5
			var pts := PackedVector2Array([
				Vector2(-w * 0.5, bot_y),
				Vector2(w * 0.5, bot_y),
				Vector2(w * 0.42, top_y),
				Vector2(w * 0.18, bot_y - 4),
				Vector2(0, top_y),
				Vector2(-w * 0.18, bot_y - 4),
				Vector2(-w * 0.42, top_y),
			])
			draw_colored_polygon(pts, icon_color)
		PieceType.Kind.SHIELD:
			# Shield: rounded pentagon-ish
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
		PieceType.Kind.SPEAR:
			# Spear: diagonal shaft + tip + tail
			var p_from := Vector2(-r, r)
			var p_to := Vector2(r, -r)
			draw_line(p_from, p_to, icon_color, 4.0, true)
			# Tip triangle
			var tip := PackedVector2Array([
				Vector2(r - 6, -r + 2),
				Vector2(r + 8, -r - 8),
				Vector2(r + 2, -r + 6),
			])
			draw_colored_polygon(tip, icon_color)
			# Crossguard
			draw_line(Vector2(-r * 0.2, -r * 0.2 - 6), Vector2(-r * 0.2 + 12, -r * 0.2 + 6), icon_color, 3.0, true)
		PieceType.Kind.ARCHER:
			# Bow: arc + arrow
			draw_arc(center, r, deg_to_rad(-70), deg_to_rad(70), 24, icon_color, 4.0, true)
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
