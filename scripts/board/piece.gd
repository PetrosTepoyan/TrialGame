class_name Piece
extends Node2D

signal selected(piece: Piece)

const SIZE: float = 180.0
const SELECT_SCALE: float = 1.12
const ANIM_TIME: float = 0.18
const SPRITE_SCALE: float = 8.5  # Tiny Dungeon tiles are 16x16; ~136x136 inside the 180 tile keeps the old ~75% inset ratio.

const SPRITE_PATHS := {
	PieceType.Kind.SWORD: "res://assets/pieces/sword.png",
	PieceType.Kind.SHIELD: "res://assets/pieces/shield.png",
	PieceType.Kind.STAFF: "res://assets/pieces/staff.png",
	PieceType.Kind.BOW: "res://assets/pieces/bow.png",
}

var kind: int = 0
var color: Color = Color.WHITE
var board_pos: Vector2i = Vector2i.ZERO
var is_selected: bool = false

var _tween: Tween
var _sprite: Sprite2D = null
var _has_sprite: bool = false
var _rainbow_rotation: float = 0.0      # accumulator for the rainbow swirl tween
var _rainbow_tween: Tween = null

const RAINBOW_SLICE_COLORS: Array[Color] = [
	Color(0.95, 0.30, 0.30),
	Color(0.96, 0.62, 0.25),
	Color(0.95, 0.85, 0.30),
	Color(0.40, 0.85, 0.45),
	Color(0.35, 0.60, 0.95),
	Color(0.75, 0.40, 0.95),
]

func _ready() -> void:
	z_index = 5
	_sync_sprite()
	_sync_rainbow_spin()

func configure(p_kind: int, p_color: Color, p_board_pos: Vector2i) -> void:
	kind = p_kind
	color = p_color
	board_pos = p_board_pos
	if is_inside_tree():
		_sync_sprite()
		_sync_rainbow_spin()
	queue_redraw()

func _sync_rainbow_spin() -> void:
	# Run a perpetual slow rotation accumulator for the rainbow swirl. Only
	# rainbow pieces get the tween; everyone else clears it.
	if _rainbow_tween != null and _rainbow_tween.is_running():
		_rainbow_tween.kill()
	_rainbow_tween = null
	if kind != PieceType.Kind.RAINBOW:
		return
	_rainbow_rotation = 0.0
	_rainbow_tween = create_tween()
	_rainbow_tween.set_loops()
	_rainbow_tween.tween_method(_set_rainbow_rotation, 0.0, TAU, 4.0)

func _set_rainbow_rotation(v: float) -> void:
	_rainbow_rotation = v
	queue_redraw()

func _sync_sprite() -> void:
	if _sprite != null:
		_sprite.queue_free()
		_sprite = null
		_has_sprite = false
	var path: String = SPRITE_PATHS.get(kind, "")
	if path == "" or not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path)
	if tex == null:
		return
	_sprite = Sprite2D.new()
	_sprite.texture = tex
	_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	add_child(_sprite)
	_has_sprite = true

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
	if kind == PieceType.Kind.RAINBOW:
		_draw_rainbow_face(rect)
	else:
		# Colored inset (band that gives each kind its identifying tint behind the sprite)
		draw_rect(rect.grow(-6), color.darkened(0.35), true)
	# Border
	var border := Color(1, 0.95, 0.5, 0.95) if is_selected else Color(1, 1, 1, 0.18)
	if kind == PieceType.Kind.RAINBOW and not is_selected:
		# Faint rainbow halo border so it reads as special at a glance.
		border = Color(1.0, 1.0, 1.0, 0.75)
	draw_rect(rect.grow(-1), border, false, 3.0)
	# Programmatic icon only when we don't have a sprite swapped in.
	if not _has_sprite and kind != PieceType.Kind.RAINBOW:
		_draw_kind_icon()

func _draw_rainbow_face(rect: Rect2) -> void:
	# Pie-slice radial gradient using a fan of triangles; rotates via _rainbow_rotation.
	var center: Vector2 = Vector2.ZERO
	var radius: float = (SIZE * 0.5) - 6.0
	var slices: int = RAINBOW_SLICE_COLORS.size()
	var step: float = TAU / float(slices)
	for i in range(slices):
		var a0: float = _rainbow_rotation + step * i
		var a1: float = a0 + step
		# Subdivide each slice into a few triangles for a smoother arc edge.
		var sub: int = 4
		for s in range(sub):
			var b0: float = lerp(a0, a1, float(s) / sub)
			var b1: float = lerp(a0, a1, float(s + 1) / sub)
			var poly := PackedVector2Array([
				center,
				center + Vector2(cos(b0), sin(b0)) * radius,
				center + Vector2(cos(b1), sin(b1)) * radius,
			])
			draw_colored_polygon(poly, RAINBOW_SLICE_COLORS[i])
	# Centre highlight so it pops against the dark backdrop.
	draw_circle(center, radius * 0.32, Color(1.0, 1.0, 1.0, 0.55))
	draw_circle(center, radius * 0.18, Color(1.0, 1.0, 1.0, 0.85))

func _draw_kind_icon() -> void:
	var r: float = SIZE * 0.28
	var icon_color := Color(1, 1, 1, 0.92)
	match kind:
		PieceType.Kind.SWORD:
			var blade_color := Color(0.96, 0.96, 1.00, 1)
			var hilt_color := Color(0.55, 0.40, 0.20, 1)
			var pommel := Color(0.95, 0.78, 0.30, 1)
			draw_line(Vector2(0, -r * 1.05), Vector2(0, r * 0.35), blade_color, 6.0, true)
			var tip := PackedVector2Array([
				Vector2(-5, -r * 1.0),
				Vector2(0, -r * 1.25),
				Vector2(5, -r * 1.0),
			])
			draw_colored_polygon(tip, blade_color)
			draw_line(Vector2(-r * 0.55, r * 0.35), Vector2(r * 0.55, r * 0.35), pommel, 6.0, true)
			draw_line(Vector2(0, r * 0.40), Vector2(0, r * 0.80), hilt_color, 6.0, true)
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
			draw_rect(Rect2(-w * 0.06, -h * 0.30, w * 0.12, h * 0.55), Color(0, 0, 0, 0.35), true)
			draw_rect(Rect2(-w * 0.24, -h * 0.10, w * 0.48, h * 0.12), Color(0, 0, 0, 0.35), true)
		PieceType.Kind.STAFF:
			var shaft_color := Color(0.60, 0.42, 0.25, 1)
			var orb_color := Color(0.85, 0.55, 1.00, 1)
			draw_line(Vector2(0, r * 1.0), Vector2(0, -r * 0.55), shaft_color, 5.0, true)
			draw_line(Vector2(0, r * 0.45), Vector2(0, r * 0.85), shaft_color.darkened(0.3), 6.0, true)
			draw_circle(Vector2(0, -r * 0.75), 11.0, orb_color)
			draw_circle(Vector2(0, -r * 0.75), 7.0, orb_color.lightened(0.4))
			draw_circle(Vector2(-3, -r * 0.78), 3.0, Color.WHITE)
		PieceType.Kind.BOW:
			draw_arc(Vector2.ZERO, r, deg_to_rad(-70), deg_to_rad(70), 24, icon_color, 4.0, true)
			draw_line(Vector2(r * 0.34, -r * 0.94), Vector2(r * 0.34, r * 0.94), icon_color, 2.0, true)
			draw_line(Vector2(-r * 0.6, 0), Vector2(r * 0.4, 0), icon_color, 2.5, true)
			var ah := PackedVector2Array([
				Vector2(r * 0.4, -4),
				Vector2(r * 0.65, 0),
				Vector2(r * 0.4, 4),
			])
			draw_colored_polygon(ah, icon_color)
