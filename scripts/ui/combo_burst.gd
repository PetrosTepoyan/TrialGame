class_name ComboBurst
extends Node2D

# Full-screen flash + ring shockwave when a combo (3+ same kind/level emblems
# in the action scale) fires. Color tints the flash and the ring.
#
# Usage:
#   ComboBurst.spawn(viewport_size, color, parent)
#   ComboBurst.spawn_at(center, viewport_size, color, parent)

const FLASH_DURATION: float = 0.42
const RING_DURATION: float = 0.55
const RING_MAX_RADIUS: float = 720.0

static func spawn(viewport_size: Vector2, color: Color, parent: Node) -> void:
	if not is_instance_valid(parent):
		return
	spawn_at(viewport_size * 0.5, viewport_size, color, parent)

static func spawn_at(center: Vector2, viewport_size: Vector2, color: Color, parent: Node) -> void:
	if not is_instance_valid(parent):
		return
	var node := ComboBurst.new()
	node.position = center
	node._color = color
	node._viewport_size = viewport_size
	parent.add_child(node)
	node._run()

# --- Instance ---------------------------------------------------------------

var _color: Color = Color.WHITE
var _viewport_size: Vector2 = Vector2(1080, 1920)
var _flash_alpha: float = 0.0
var _ring_r: float = 0.0
var _ring_alpha: float = 0.0

func _ready() -> void:
	z_index = 200

func _run() -> void:
	# Flash: quick bloom that fades out.
	var t_flash := create_tween()
	t_flash.set_parallel(true)
	t_flash.tween_method(_set_flash, 0.55, 0.0, FLASH_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Ring shockwave: grows outward from center.
	var t_ring := create_tween()
	t_ring.set_parallel(true)
	t_ring.tween_method(_set_ring_r, 40.0, RING_MAX_RADIUS, RING_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t_ring.tween_method(_set_ring_alpha, 0.85, 0.0, RING_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Cleanup once both finish.
	var t_done := create_tween()
	t_done.tween_interval(max(FLASH_DURATION, RING_DURATION) + 0.05)
	t_done.tween_callback(queue_free)
	# Inner sparkle burst (small CPUParticles2D) tinted to the combo color.
	_spawn_inner_sparkle()

func _spawn_inner_sparkle() -> void:
	var p := CPUParticles2D.new()
	add_child(p)
	p.position = Vector2.ZERO
	p.amount = 30
	p.lifetime = 0.55
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 12.0
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 280.0
	p.initial_velocity_max = 560.0
	p.scale_amount_min = 1.4
	p.scale_amount_max = 3.0
	p.color = _color.lightened(0.35)
	var g := Gradient.new()
	g.add_point(0.0, _color.lightened(0.45))
	g.add_point(1.0, Color(_color.r, _color.g, _color.b, 0.0))
	p.color_ramp = g
	p.emitting = true
	var t := p.create_tween()
	t.tween_interval(p.lifetime + 0.1)
	t.tween_callback(p.queue_free)

func _set_flash(v: float) -> void:
	_flash_alpha = v
	queue_redraw()

func _set_ring_r(v: float) -> void:
	_ring_r = v
	queue_redraw()

func _set_ring_alpha(v: float) -> void:
	_ring_alpha = v
	queue_redraw()

func _draw() -> void:
	# Full-screen flash rectangle (positioned relative to self at center, so we
	# draw a rect that covers the entire viewport regardless of camera).
	if _flash_alpha > 0.001:
		var w: float = _viewport_size.x * 1.5
		var h: float = _viewport_size.y * 1.5
		var r := Rect2(-w * 0.5, -h * 0.5, w, h)
		draw_rect(r, Color(_color.r, _color.g, _color.b, _flash_alpha), true)
	# Ring shockwave: thick stroked arc.
	if _ring_alpha > 0.001 and _ring_r > 0.5:
		var ring_c := Color(_color.r, _color.g, _color.b, _ring_alpha)
		var inner_c := Color(1, 1, 1, _ring_alpha * 0.85)
		draw_arc(Vector2.ZERO, _ring_r, 0.0, TAU, 48, ring_c, 8.0, true)
		draw_arc(Vector2.ZERO, _ring_r - 5.0, 0.0, TAU, 48, inner_c, 2.5, true)
