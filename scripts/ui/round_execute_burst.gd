class_name RoundExecuteBurst
extends Node2D

# Dramatic ring/star burst that fires when the action scale fills and a round
# resolves. Drawn from the centre of the action scale. Each emblem in the
# scale pulses outward as a colored "embed" point.
#
# Usage:
#   RoundExecuteBurst.spawn(center_world, viewport_size, emblem_colors, parent)
#   where emblem_colors is Array[Color], one per active emblem.

const DURATION: float = 0.70
const STAR_DURATION: float = 0.40

static func spawn(center: Vector2, viewport_size: Vector2, emblem_colors: Array, parent: Node) -> void:
	if not is_instance_valid(parent):
		return
	var node := RoundExecuteBurst.new()
	node.position = center
	node._viewport_size = viewport_size
	node._emblem_colors = emblem_colors.duplicate()
	parent.add_child(node)
	node._run()

# --- Instance ---------------------------------------------------------------

var _viewport_size: Vector2 = Vector2(1080, 1920)
var _emblem_colors: Array = []
var _star_progress: float = 0.0
var _ring_r: float = 0.0
var _ring_alpha: float = 0.0
var _inner_alpha: float = 1.0

func _ready() -> void:
	z_index = 150

func _run() -> void:
	# Big ring shockwave.
	var t_ring := create_tween()
	t_ring.set_parallel(true)
	t_ring.tween_method(_set_ring_r, 24.0, 460.0, DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t_ring.tween_method(_set_ring_alpha, 0.95, 0.0, DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Star-burst pulse for each emblem flying outward.
	var t_star := create_tween()
	t_star.tween_method(_set_star_progress, 0.0, 1.0, STAR_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Inner flash.
	var t_inner := create_tween()
	t_inner.tween_method(_set_inner_alpha, 1.0, 0.0, STAR_DURATION * 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Particle burst at the center using the dominant emblem color.
	_spawn_burst_particles()
	# Cleanup.
	var t_done := create_tween()
	t_done.tween_interval(DURATION + 0.1)
	t_done.tween_callback(queue_free)

func _spawn_burst_particles() -> void:
	var p := CPUParticles2D.new()
	add_child(p)
	p.position = Vector2.ZERO
	p.amount = 30
	p.lifetime = 0.7
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 20.0
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 220.0
	p.initial_velocity_max = 500.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	var col: Color = _dominant_color()
	p.color = col.lightened(0.25)
	var g := Gradient.new()
	g.add_point(0.0, col.lightened(0.45))
	g.add_point(1.0, Color(col.r, col.g, col.b, 0.0))
	p.color_ramp = g
	p.emitting = true
	var t := p.create_tween()
	t.tween_interval(p.lifetime + 0.1)
	t.tween_callback(p.queue_free)

func _dominant_color() -> Color:
	if _emblem_colors.is_empty():
		return Color(1.0, 0.85, 0.4)
	var r: float = 0.0
	var g: float = 0.0
	var b: float = 0.0
	for c_v in _emblem_colors:
		var c: Color = c_v
		r += c.r
		g += c.g
		b += c.b
	var n: float = float(_emblem_colors.size())
	return Color(r / n, g / n, b / n)

func _set_ring_r(v: float) -> void:
	_ring_r = v
	queue_redraw()

func _set_ring_alpha(v: float) -> void:
	_ring_alpha = v
	queue_redraw()

func _set_star_progress(v: float) -> void:
	_star_progress = v
	queue_redraw()

func _set_inner_alpha(v: float) -> void:
	_inner_alpha = v
	queue_redraw()

func _draw() -> void:
	# Inner flash: a soft white-tinted disc that quickly fades.
	if _inner_alpha > 0.001:
		var col := _dominant_color()
		draw_circle(Vector2.ZERO, 70.0, Color(col.r, col.g, col.b, _inner_alpha * 0.55))
		draw_circle(Vector2.ZERO, 40.0, Color(1, 1, 1, _inner_alpha * 0.7))
	# Emblem points: each emblem flies outward along an evenly-distributed angle
	# and leaves a tapered trail.
	if _star_progress > 0.001 and not _emblem_colors.is_empty():
		var n: int = _emblem_colors.size()
		var max_dist: float = 220.0
		for i in range(n):
			var angle: float = TAU * (float(i) / float(n)) - PI * 0.5
			var dist: float = max_dist * _star_progress
			var dir := Vector2(cos(angle), sin(angle))
			var head: Vector2 = dir * dist
			var tail: Vector2 = dir * (dist * 0.55)
			var col: Color = _emblem_colors[i]
			# Trail body
			var trail_c := Color(col.r, col.g, col.b, (1.0 - _star_progress) * 0.85)
			draw_line(tail, head, trail_c, 8.0, true)
			# Head dot
			var head_c := Color(col.r, col.g, col.b, 1.0 - _star_progress * 0.6)
			draw_circle(head, 9.0 * (1.0 - _star_progress * 0.4), head_c)
			# Soft glow
			var glow_c := Color(col.lightened(0.4).r, col.lightened(0.4).g, col.lightened(0.4).b, (1.0 - _star_progress) * 0.5)
			draw_circle(head, 14.0 * (1.0 - _star_progress * 0.4), glow_c)
	# Outer shockwave ring.
	if _ring_alpha > 0.001 and _ring_r > 0.5:
		var col2 := _dominant_color()
		var ring_c := Color(col2.r, col2.g, col2.b, _ring_alpha)
		var inner_c := Color(1, 1, 1, _ring_alpha * 0.8)
		draw_arc(Vector2.ZERO, _ring_r, 0.0, TAU, 48, ring_c, 6.0, true)
		draw_arc(Vector2.ZERO, _ring_r - 4.0, 0.0, TAU, 48, inner_c, 2.0, true)
