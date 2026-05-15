class_name ActionScaleSlot
extends Control

const SPRITE_PATHS := {
	0: "res://assets/pieces/sword.png",
	1: "res://assets/pieces/shield.png",
	2: "res://assets/pieces/staff.png",
	3: "res://assets/pieces/bow.png",
}

# Gold-and-dusk medallion palette mirrored from three_towers.tres so the slot
# reads the same as the rest of the UI.
const _C_INK := Color(0.07, 0.05, 0.09)
const _C_DUSK_INSET := Color(0.13, 0.10, 0.16, 0.92)
const _C_GOLD_RIM := Color(0.95, 0.78, 0.30, 0.95)
const _C_GOLD_RIM_DIM := Color(0.55, 0.40, 0.18, 0.55)

var _emblem: Emblem = null
var _flash_alpha: float = 0.0
var _pulse_alpha: float = 0.0
var _sprite: TextureRect = null
var _pulse_tween: Tween = null

func _ready() -> void:
	_sprite = TextureRect.new()
	_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sprite.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sprite.offset_left = 2.0
	_sprite.offset_top = 2.0
	_sprite.offset_right = -2.0
	_sprite.offset_bottom = -8.0
	_sprite.visible = false
	_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sprite)

func set_emblem(e: Emblem) -> void:
	_emblem = e
	if _sprite != null:
		if e == null:
			_sprite.texture = null
			_sprite.visible = false
		else:
			var path: String = SPRITE_PATHS.get(e.piece_kind, "")
			if path != "" and ResourceLoader.exists(path):
				_sprite.texture = load(path)
				_sprite.visible = true
			else:
				_sprite.visible = false
	queue_redraw()
	if e != null:
		_pop_in()
		_start_pulse()
	else:
		_stop_pulse()

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

func _start_pulse() -> void:
	# Slot rim breathes while it holds an emblem — subtle but enough to read
	# the bar at a glance.
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_alpha = 0.0
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_method(_set_pulse, 0.0, 1.0, 0.55).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_method(_set_pulse, 1.0, 0.0, 0.55).set_trans(Tween.TRANS_SINE)

func _stop_pulse() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_alpha = 0.0
	queue_redraw()

func _set_pulse(v: float) -> void:
	_pulse_alpha = v
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var radius: float = min(size.x, size.y) * 0.22
	# Inset dusk fill (medallion body).
	_draw_rounded_rect(rect, radius, _C_DUSK_INSET)
	# Gold rim — brighter when filled, dimmer when empty.
	var rim: Color = _C_GOLD_RIM if _emblem != null else _C_GOLD_RIM_DIM
	_draw_rounded_rect_outline(rect, radius, rim, 2.0)
	if _emblem == null:
		# Empty: faint center dot.
		var c := size * 0.5
		draw_circle(c, 4.0, Color(0.4, 0.36, 0.28, 0.5))
		return
	var col := _emblem_color(_emblem.piece_kind)
	# Inset tint band behind the emblem sprite/icon.
	var tint_rect := rect.grow(-4)
	_draw_rounded_rect(tint_rect, radius - 3, col.darkened(0.35))
	# Mini icon (programmatic fallback when no sprite is loaded)
	if _sprite == null or not _sprite.visible:
		_draw_mini_icon(_emblem.piece_kind)
	# Level pip(s) along the bottom edge — placed below the sprite area so they
	# remain visible at any sprite size.
	var level := _emblem.level
	var dot_color := Color(1.0, 0.92, 0.50, 1)
	for i in range(level):
		var p := Vector2(size.x - 6 - i * 6, size.y - 3)
		draw_circle(p, 2.2, dot_color)
	# Pulse — extra rim band that breathes while the slot is filled.
	if _pulse_alpha > 0.0:
		var glow_color := Color(_C_GOLD_RIM.r, _C_GOLD_RIM.g, _C_GOLD_RIM.b, 0.55 * _pulse_alpha)
		_draw_rounded_rect_outline(rect.grow(1), radius + 1, glow_color, 2.0)
	if _flash_alpha > 0.0:
		_draw_rounded_rect(rect, radius, Color(1, 1, 1, _flash_alpha * 0.5))

func _draw_rounded_rect(r: Rect2, radius: float, c: Color) -> void:
	# Center band (height-strip) avoids leaving the curved corners white.
	var inset_h: float = clamp(radius, 0.0, r.size.y * 0.5)
	var inset_w: float = clamp(radius, 0.0, r.size.x * 0.5)
	if r.size.x > inset_w * 2:
		draw_rect(Rect2(r.position + Vector2(inset_w, 0), Vector2(r.size.x - inset_w * 2, r.size.y)), c, true)
	if r.size.y > inset_h * 2:
		draw_rect(Rect2(r.position + Vector2(0, inset_h), Vector2(r.size.x, r.size.y - inset_h * 2)), c, true)
	var rr: float = min(inset_w, inset_h)
	draw_circle(r.position + Vector2(inset_w, inset_h), rr, c)
	draw_circle(r.position + Vector2(r.size.x - inset_w, inset_h), rr, c)
	draw_circle(r.position + Vector2(inset_w, r.size.y - inset_h), rr, c)
	draw_circle(r.position + Vector2(r.size.x - inset_w, r.size.y - inset_h), rr, c)

func _draw_rounded_rect_outline(r: Rect2, radius: float, c: Color, w: float) -> void:
	# Approximate a rounded-rect outline with four edges + four corner arcs.
	var inset_w: float = clamp(radius, 0.0, r.size.x * 0.5)
	var inset_h: float = clamp(radius, 0.0, r.size.y * 0.5)
	var rr: float = min(inset_w, inset_h)
	# Edges
	draw_line(r.position + Vector2(inset_w, 0), r.position + Vector2(r.size.x - inset_w, 0), c, w, true)
	draw_line(r.position + Vector2(inset_w, r.size.y), r.position + Vector2(r.size.x - inset_w, r.size.y), c, w, true)
	draw_line(r.position + Vector2(0, inset_h), r.position + Vector2(0, r.size.y - inset_h), c, w, true)
	draw_line(r.position + Vector2(r.size.x, inset_h), r.position + Vector2(r.size.x, r.size.y - inset_h), c, w, true)
	# Corner arcs
	draw_arc(r.position + Vector2(inset_w, inset_h), rr, deg_to_rad(180), deg_to_rad(270), 8, c, w, true)
	draw_arc(r.position + Vector2(r.size.x - inset_w, inset_h), rr, deg_to_rad(270), deg_to_rad(360), 8, c, w, true)
	draw_arc(r.position + Vector2(r.size.x - inset_w, r.size.y - inset_h), rr, deg_to_rad(0), deg_to_rad(90), 8, c, w, true)
	draw_arc(r.position + Vector2(inset_w, r.size.y - inset_h), rr, deg_to_rad(90), deg_to_rad(180), 8, c, w, true)

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
