class_name SwapTrail
extends Node2D

# Brief subtle trail rendered while two pieces are swapping. Spawned from
# Board._do_swap before the tween starts; auto-frees once the trail fades.
#
# Usage:
#   SwapTrail.spawn(from_world_a, to_world_a, color_a, from_world_b, to_world_b, color_b, parent)

const DURATION: float = 0.20
const SEGMENTS: int = 6
const WIDTH: float = 6.0

static func spawn(a_from: Vector2, a_to: Vector2, a_color: Color, b_from: Vector2, b_to: Vector2, b_color: Color, parent: Node) -> void:
	if not is_instance_valid(parent):
		return
	var node := SwapTrail.new()
	node._a_from = a_from
	node._a_to = a_to
	node._a_color = a_color
	node._b_from = b_from
	node._b_to = b_to
	node._b_color = b_color
	parent.add_child(node)
	node._run()

# --- Instance ---------------------------------------------------------------

var _a_from: Vector2 = Vector2.ZERO
var _a_to: Vector2 = Vector2.ZERO
var _a_color: Color = Color.WHITE
var _b_from: Vector2 = Vector2.ZERO
var _b_to: Vector2 = Vector2.ZERO
var _b_color: Color = Color.WHITE
var _alpha: float = 0.9

func _ready() -> void:
	z_index = 4  # Just below pieces so they read on top.

func _run() -> void:
	var t := create_tween()
	t.tween_method(_set_alpha, 0.85, 0.0, DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_callback(queue_free)

func _set_alpha(v: float) -> void:
	_alpha = v
	queue_redraw()

func _draw() -> void:
	if _alpha <= 0.001:
		return
	_draw_streak(_a_from, _a_to, _a_color)
	_draw_streak(_b_from, _b_to, _b_color)

func _draw_streak(from_pos: Vector2, to_pos: Vector2, color: Color) -> void:
	# Tapered dotted streak from->to, so the moving piece appears to leave a
	# light glow. Drawn as a sequence of fading circles.
	for i in range(SEGMENTS):
		var t: float = float(i) / float(SEGMENTS - 1)
		var p: Vector2 = from_pos.lerp(to_pos, t)
		var radius: float = WIDTH * (1.0 - t * 0.5)
		var a: float = _alpha * (1.0 - t * 0.6)
		var c := Color(color.r, color.g, color.b, a)
		draw_circle(p, radius, c)
