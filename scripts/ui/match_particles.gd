class_name MatchParticles
extends Node2D

# Spawns a short sparkle burst at a board cell. Cheap CPUParticles2D so it
# runs comfortably on mobile.

const LIFETIME: float = 0.45
const COUNT: int = 16

static func spawn(at_world: Vector2, color: Color, parent: Node) -> void:
	var p := CPUParticles2D.new()
	parent.add_child(p)
	p.position = at_world
	p.amount = COUNT
	p.lifetime = LIFETIME
	p.one_shot = true
	p.explosiveness = 0.95
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 6.0
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.gravity = Vector2(0, 220)
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 180.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = color.lightened(0.2)
	# Self-clean
	var t := p.create_tween()
	t.tween_interval(LIFETIME + 0.2)
	t.tween_callback(p.queue_free)
	p.emitting = true

# Fired during round execution to make a kind-coloured "all eyes on the
# action scale" pulse around the hero.
static func spawn_round_burst(at_world: Vector2, color: Color, parent: Node) -> void:
	var p := CPUParticles2D.new()
	parent.add_child(p)
	p.position = at_world
	p.amount = 40
	p.lifetime = 0.7
	p.one_shot = true
	p.explosiveness = 0.9
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 32.0
	p.spread = 180.0
	p.initial_velocity_min = 140.0
	p.initial_velocity_max = 320.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	p.color = color
	var t := p.create_tween()
	t.tween_interval(0.9)
	t.tween_callback(p.queue_free)
	p.emitting = true
