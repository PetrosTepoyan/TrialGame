class_name MatchParticles
extends Node2D

# Programmatic, type-aware match VFX. Each kind gets a distinct procedural burst:
#   SWORD  -> bright sparks (radial high-velocity points)
#   SHIELD -> glints/rings (slow scaling ring + light dust)
#   STAFF  -> magical motes (slow drifting orbs with curl)
#   BOW    -> feathers/arrows (directional shards)
#
# All emitters are CPUParticles2D (iOS GL Compatibility friendly). Mobile-safe
# caps: ~30 particles per burst worst case. Match length scales the burst.
#
# Public API (kept stable for callers):
#   MatchParticles.spawn(at, color, parent, kind = -1, count = 3)
#   MatchParticles.spawn_round_burst(at, color, parent)

const BASE_COUNT_MIN: int = 12
const BASE_COUNT_MAX: int = 30
const TEX_CACHE_GROUP: StringName = &"_match_particle_tex_cache"

# Per-kind cached procedural textures. Built once and reused — cheaper than
# rebuilding an ImageTexture each spawn.
static var _tex_spark: ImageTexture = null
static var _tex_glint: ImageTexture = null
static var _tex_mote: ImageTexture = null
static var _tex_feather: ImageTexture = null
static var _tex_dot: ImageTexture = null

static func spawn(at_world: Vector2, color: Color, parent: Node, kind: int = -1, count: int = 3) -> void:
	# Older callers used spawn(at, color, parent) — keep that working with no
	# kind information by falling back to a generic spark burst.
	if not is_instance_valid(parent):
		return
	var amount: int = _scale_count(count)
	match kind:
		PieceType.Kind.SWORD:
			_spawn_sword(at_world, color, parent, amount)
		PieceType.Kind.SHIELD:
			_spawn_shield(at_world, color, parent, amount)
		PieceType.Kind.STAFF:
			_spawn_staff(at_world, color, parent, amount)
		PieceType.Kind.BOW:
			_spawn_bow(at_world, color, parent, amount)
		_:
			_spawn_generic(at_world, color, parent, amount)

static func spawn_round_burst(at_world: Vector2, color: Color, parent: Node) -> void:
	# Kept for backwards compatibility — RoundExecuteBurst is the richer version
	# used by combat_controller.
	if not is_instance_valid(parent):
		return
	var p := CPUParticles2D.new()
	parent.add_child(p)
	p.position = at_world
	p.amount = 30
	p.lifetime = 0.7
	p.one_shot = true
	p.explosiveness = 0.9
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 28.0
	p.spread = 180.0
	p.initial_velocity_min = 140.0
	p.initial_velocity_max = 320.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	p.color = color
	p.texture = _get_dot_texture()
	var t := p.create_tween()
	t.tween_interval(0.9)
	t.tween_callback(p.queue_free)
	p.emitting = true

# --- Per-kind bursts ---------------------------------------------------------

static func _spawn_sword(at: Vector2, color: Color, parent: Node, amount: int) -> void:
	# Sharp radial sparks plus a tight metallic flash.
	var p := CPUParticles2D.new()
	parent.add_child(p)
	p.position = at
	p.amount = amount
	p.lifetime = 0.42
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 4.0
	p.spread = 180.0
	p.gravity = Vector2(0, 360)
	p.initial_velocity_min = 180.0
	p.initial_velocity_max = 360.0
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.6
	p.color = color.lightened(0.4)
	p.color_ramp = _make_ramp(color.lightened(0.5), color.darkened(0.2))
	p.texture = _get_spark_texture()
	_self_clean(p, p.lifetime + 0.2)
	p.emitting = true
	# Tiny center flash
	_spawn_flash(at, color.lightened(0.55), parent, 22.0, 0.18)

static func _spawn_shield(at: Vector2, color: Color, parent: Node, amount: int) -> void:
	# Expanding ring + a few slow glints. Reads as "guard up".
	var p := CPUParticles2D.new()
	parent.add_child(p)
	p.position = at
	p.amount = amount
	p.lifetime = 0.65
	p.one_shot = true
	p.explosiveness = 0.85
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 8.0
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 50.0
	p.initial_velocity_max = 110.0
	p.scale_amount_min = 1.2
	p.scale_amount_max = 2.4
	p.color = color.lightened(0.2)
	p.color_ramp = _make_ramp(color.lightened(0.35), color.darkened(0.1))
	p.texture = _get_glint_texture()
	_self_clean(p, p.lifetime + 0.2)
	p.emitting = true
	# Expanding ring as a Node2D drawn line
	_spawn_ring(at, color.lightened(0.25), parent, 24.0, 64.0, 0.45)

static func _spawn_staff(at: Vector2, color: Color, parent: Node, amount: int) -> void:
	# Magical motes — slow, rising, slight horizontal swirl via angle randomization.
	var p := CPUParticles2D.new()
	parent.add_child(p)
	p.position = at
	p.amount = amount
	p.lifetime = 0.95
	p.one_shot = true
	p.explosiveness = 0.6
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 12.0
	p.direction = Vector2(0, -1)
	p.spread = 60.0
	p.gravity = Vector2(0, -40)
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 140.0
	p.tangential_accel_min = -80.0
	p.tangential_accel_max = 80.0
	p.scale_amount_min = 1.2
	p.scale_amount_max = 2.6
	p.scale_amount_curve = _make_pulse_curve()
	p.color = color.lightened(0.2)
	p.color_ramp = _make_ramp(color.lightened(0.4), Color(color.r, color.g, color.b, 0.0))
	p.texture = _get_mote_texture()
	_self_clean(p, p.lifetime + 0.3)
	p.emitting = true

static func _spawn_bow(at: Vector2, color: Color, parent: Node, amount: int) -> void:
	# Feathered shards — directional sideways trail, lightly falling.
	var p := CPUParticles2D.new()
	parent.add_child(p)
	p.position = at
	p.amount = amount
	p.lifetime = 0.6
	p.one_shot = true
	p.explosiveness = 0.95
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 6.0
	p.direction = Vector2(1, 0)
	p.spread = 80.0
	p.gravity = Vector2(0, 180)
	p.initial_velocity_min = 150.0
	p.initial_velocity_max = 280.0
	p.angular_velocity_min = -200.0
	p.angular_velocity_max = 200.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color = color.lightened(0.15)
	p.color_ramp = _make_ramp(color.lightened(0.3), color.darkened(0.15))
	p.texture = _get_feather_texture()
	_self_clean(p, p.lifetime + 0.2)
	p.emitting = true
	# Mirror burst going the other way so the feathers fan out both sides.
	var p2 := CPUParticles2D.new()
	parent.add_child(p2)
	p2.position = at
	p2.amount = max(6, amount / 2)
	p2.lifetime = 0.6
	p2.one_shot = true
	p2.explosiveness = 0.95
	p2.local_coords = false
	p2.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p2.emission_sphere_radius = 6.0
	p2.direction = Vector2(-1, 0)
	p2.spread = 80.0
	p2.gravity = Vector2(0, 180)
	p2.initial_velocity_min = 150.0
	p2.initial_velocity_max = 280.0
	p2.angular_velocity_min = -200.0
	p2.angular_velocity_max = 200.0
	p2.scale_amount_min = 1.0
	p2.scale_amount_max = 2.0
	p2.color = color.lightened(0.15)
	p2.color_ramp = _make_ramp(color.lightened(0.3), color.darkened(0.15))
	p2.texture = _get_feather_texture()
	_self_clean(p2, p2.lifetime + 0.2)
	p2.emitting = true

static func _spawn_generic(at: Vector2, color: Color, parent: Node, amount: int) -> void:
	# Used when no kind info is available (legacy callers).
	var p := CPUParticles2D.new()
	parent.add_child(p)
	p.position = at
	p.amount = amount
	p.lifetime = 0.45
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
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.2
	p.color = color.lightened(0.2)
	p.texture = _get_dot_texture()
	_self_clean(p, p.lifetime + 0.2)
	p.emitting = true

# --- Helpers -----------------------------------------------------------------

static func _scale_count(match_count: int) -> int:
	# 3-match -> ~12, 4-match -> ~20, 5+-match -> 30 (the cap).
	var c: int = BASE_COUNT_MIN
	if match_count >= 5:
		c = BASE_COUNT_MAX
	elif match_count >= 4:
		c = 22
	else:
		c = BASE_COUNT_MIN
	return clampi(c, 4, BASE_COUNT_MAX)

static func _self_clean(p: CPUParticles2D, after: float) -> void:
	var t := p.create_tween()
	t.tween_interval(after)
	t.tween_callback(p.queue_free)

static func _make_ramp(start_c: Color, end_c: Color) -> Gradient:
	var g := Gradient.new()
	g.add_point(0.0, start_c)
	g.add_point(1.0, end_c)
	return g

static func _make_pulse_curve() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.2))
	c.add_point(Vector2(0.4, 1.0))
	c.add_point(Vector2(1.0, 0.0))
	return c

static func _spawn_flash(at: Vector2, color: Color, parent: Node, radius: float, duration: float) -> void:
	var node := _ParticleFlashNode.new()
	node.position = at
	node.flash_color = color
	node.flash_radius = radius
	node.flash_duration = duration
	parent.add_child(node)
	node.run()

static func _spawn_ring(at: Vector2, color: Color, parent: Node, r_start: float, r_end: float, duration: float) -> void:
	var node := _ParticleRingNode.new()
	node.position = at
	node.ring_color = color
	node.r_start = r_start
	node.r_end = r_end
	node.ring_duration = duration
	parent.add_child(node)
	node.run()

# --- Procedural texture builders --------------------------------------------

static func _get_spark_texture() -> ImageTexture:
	if _tex_spark != null:
		return _tex_spark
	_tex_spark = _build_radial_texture(16, 1.0, 0.55)
	return _tex_spark

static func _get_glint_texture() -> ImageTexture:
	if _tex_glint != null:
		return _tex_glint
	_tex_glint = _build_glint_texture(20)
	return _tex_glint

static func _get_mote_texture() -> ImageTexture:
	if _tex_mote != null:
		return _tex_mote
	_tex_mote = _build_radial_texture(20, 0.85, 0.30)
	return _tex_mote

static func _get_feather_texture() -> ImageTexture:
	if _tex_feather != null:
		return _tex_feather
	_tex_feather = _build_feather_texture(20)
	return _tex_feather

static func _get_dot_texture() -> ImageTexture:
	if _tex_dot != null:
		return _tex_dot
	_tex_dot = _build_radial_texture(12, 0.95, 0.4)
	return _tex_dot

static func _build_radial_texture(size: int, alpha_center: float, alpha_edge: float) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c: Vector2 = Vector2(size, size) * 0.5
	var r_max: float = float(size) * 0.5
	for y in range(size):
		for x in range(size):
			var d: float = (Vector2(x + 0.5, y + 0.5) - c).length() / r_max
			d = clamp(d, 0.0, 1.0)
			var a: float = lerp(alpha_center, 0.0, pow(d, 1.8))
			a = clamp(a + (alpha_edge - alpha_center) * d * 0.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)

static func _build_glint_texture(size: int) -> ImageTexture:
	# Four-pointed star: two perpendicular soft lines.
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c: float = float(size) * 0.5
	for y in range(size):
		for x in range(size):
			var dx: float = absf(float(x) + 0.5 - c)
			var dy: float = absf(float(y) + 0.5 - c)
			var horiz: float = 1.0 - clamp(dy / (float(size) * 0.45), 0.0, 1.0)
			var vert: float = 1.0 - clamp(dx / (float(size) * 0.45), 0.0, 1.0)
			horiz *= 1.0 - clamp(dx / (float(size) * 0.5), 0.0, 1.0)
			vert *= 1.0 - clamp(dy / (float(size) * 0.5), 0.0, 1.0)
			var a: float = clamp(maxf(horiz, vert), 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)

static func _build_feather_texture(size: int) -> ImageTexture:
	# Slim ellipse for feather/shard.
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var cx: float = float(size) * 0.5
	var cy: float = float(size) * 0.5
	var rx: float = float(size) * 0.48
	var ry: float = float(size) * 0.18
	for y in range(size):
		for x in range(size):
			var nx: float = (float(x) + 0.5 - cx) / rx
			var ny: float = (float(y) + 0.5 - cy) / ry
			var d: float = nx * nx + ny * ny
			d = clamp(d, 0.0, 1.0)
			var a: float = clamp(1.0 - d, 0.0, 1.0)
			a = pow(a, 0.6)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)

# --- Inner helper nodes ------------------------------------------------------

class _ParticleFlashNode extends Node2D:
	var flash_color: Color = Color.WHITE
	var flash_radius: float = 24.0
	var flash_duration: float = 0.2
	var _alpha: float = 1.0
	var _scale_v: float = 0.4

	func run() -> void:
		z_index = 50
		var t := create_tween()
		t.set_parallel(true)
		t.tween_method(_set_scale_v, 0.4, 1.4, flash_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_method(_set_alpha_v, 1.0, 0.0, flash_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		var t_done := create_tween()
		t_done.tween_interval(flash_duration + 0.02)
		t_done.tween_callback(queue_free)

	func _set_scale_v(v: float) -> void:
		_scale_v = v
		queue_redraw()

	func _set_alpha_v(v: float) -> void:
		_alpha = v
		queue_redraw()

	func _draw() -> void:
		var c := Color(flash_color.r, flash_color.g, flash_color.b, _alpha)
		draw_circle(Vector2.ZERO, flash_radius * _scale_v, c)
		var c2 := Color(1, 1, 1, _alpha * 0.7)
		draw_circle(Vector2.ZERO, flash_radius * 0.55 * _scale_v, c2)

class _ParticleRingNode extends Node2D:
	var ring_color: Color = Color.WHITE
	var r_start: float = 24.0
	var r_end: float = 64.0
	var ring_duration: float = 0.4
	var _r: float = 0.0
	var _alpha: float = 1.0

	func run() -> void:
		z_index = 50
		_r = r_start
		var t := create_tween()
		t.set_parallel(true)
		t.tween_method(_set_r_v, r_start, r_end, ring_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_method(_set_alpha_v, 0.9, 0.0, ring_duration).set_trans(Tween.TRANS_LINEAR)
		var t_done := create_tween()
		t_done.tween_interval(ring_duration + 0.02)
		t_done.tween_callback(queue_free)

	func _set_r_v(v: float) -> void:
		_r = v
		queue_redraw()

	func _set_alpha_v(v: float) -> void:
		_alpha = v
		queue_redraw()

	func _draw() -> void:
		var c := Color(ring_color.r, ring_color.g, ring_color.b, _alpha)
		draw_arc(Vector2.ZERO, _r, 0.0, TAU, 32, c, 3.0, true)
