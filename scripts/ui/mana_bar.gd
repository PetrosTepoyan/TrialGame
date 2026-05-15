class_name ManaBar
extends Control

# Three-segment vertical mana bar. Each segment is 100 mana. Segments fill from
# bottom-to-top; once a segment is full it glows. The bar is purely visual —
# battle.gd drives `set_mana(value, max)` from the ManaSystem signal.

const SEGMENT_COUNT: int = 3
const SEGMENT_MAX: int = 100
const _C_INK := Color(0.07, 0.05, 0.09)
const _C_FRAME := Color(0.95, 0.78, 0.30, 0.95)
const _C_FRAME_DIM := Color(0.55, 0.40, 0.18, 0.55)
const _C_EMPTY := Color(0.13, 0.10, 0.16, 0.92)

# Fill colors per segment (L1/L2/L3) — match the spec button progression.
const _C_L1 := Color(0.40, 0.62, 0.95, 1.0)   # blue
const _C_L2 := Color(0.95, 0.78, 0.30, 1.0)   # gold
const _C_L3 := Color(0.85, 0.15, 0.30, 1.0)   # crimson

var _mana: int = 0
var _max_mana: int = 300
var _glow_t: float = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(80, 360)
	set_process(true)

func _process(delta: float) -> void:
	# Slow oscillator drives the per-segment glow ring.
	_glow_t = fmod(_glow_t + delta, TAU)
	queue_redraw()

func set_mana(value: int, max_mana: int) -> void:
	_mana = clampi(value, 0, max_mana)
	_max_mana = max_mana
	queue_redraw()

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var seg_h: float = (h - (SEGMENT_COUNT - 1) * 6.0) / float(SEGMENT_COUNT)
	# Segments drawn bottom-up: index 0 at the bottom.
	for i in range(SEGMENT_COUNT):
		var y: float = h - (i + 1) * seg_h - i * 6.0
		var rect := Rect2(2.0, y, w - 4.0, seg_h)
		# Empty cell with dim rim.
		_fill_rect(rect, _C_EMPTY)
		# Fill portion: clamp mana into this segment's range.
		var seg_lo: int = i * SEGMENT_MAX
		var seg_hi: int = (i + 1) * SEGMENT_MAX
		var fill_amt: float = clamp(float(_mana - seg_lo) / float(SEGMENT_MAX), 0.0, 1.0)
		if fill_amt > 0.0:
			var fill_h: float = rect.size.y * fill_amt
			var fill_rect := Rect2(rect.position.x, rect.position.y + (rect.size.y - fill_h), rect.size.x, fill_h)
			_fill_rect(fill_rect, _color_for_segment(i))
		# Frame rim — gold when this segment is fully filled (threshold-ready).
		var is_full: bool = _mana >= seg_hi
		var rim: Color = _C_FRAME if is_full else _C_FRAME_DIM
		_outline_rect(rect, rim, 2.0)
		# Glow ring when full — slow breathe.
		if is_full:
			var breathe: float = 0.5 + 0.5 * sin(_glow_t * 2.0)
			var glow := _color_for_segment(i)
			glow.a = 0.35 * breathe
			_outline_rect(rect.grow(2), glow, 3.0)

func _color_for_segment(idx: int) -> Color:
	match idx:
		0: return _C_L1
		1: return _C_L2
		2: return _C_L3
	return Color.WHITE

func _fill_rect(r: Rect2, c: Color) -> void:
	draw_rect(r, c, true)

func _outline_rect(r: Rect2, c: Color, w: float) -> void:
	draw_rect(r, c, false, w)
