class_name SpecialAttackButton
extends Button

# Circular button driven by the player's current charge level. Color cycles
# grey → blue → gold → crimson. Emits Button.pressed when clicked at level >= 1.
# The button stays clickable at level 0 but does nothing — battle.gd handles
# the gating.

const _C_DISABLED := Color(0.30, 0.28, 0.32, 1.0)
const _C_L1 := Color(0.40, 0.62, 0.95, 1.0)
const _C_L2 := Color(0.95, 0.78, 0.30, 1.0)
const _C_L3 := Color(0.85, 0.15, 0.30, 1.0)

var _level: int = 0
var _glow_t: float = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(180, 180)
	flat = true
	focus_mode = Control.FOCUS_NONE
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	if _level > 0:
		_glow_t = fmod(_glow_t + delta, TAU)
		queue_redraw()

func set_charge_level(level: int) -> void:
	_level = clampi(level, 0, 3)
	queue_redraw()

func get_charge_level() -> int:
	return _level

func _draw() -> void:
	var radius: float = min(size.x, size.y) * 0.5 - 6.0
	var center: Vector2 = size * 0.5
	var fill: Color = _color_for_level()
	# Disabled / empty state: dim circle with no glow.
	if _level == 0:
		draw_circle(center, radius, _C_DISABLED)
		draw_arc(center, radius, 0.0, TAU, 48, Color(0.5, 0.45, 0.40, 0.6), 3.0, true)
		return
	# Active state: filled circle, bright rim, soft breathing glow ring.
	draw_circle(center, radius, fill.darkened(0.25))
	draw_circle(center, radius - 6.0, fill)
	# Inner highlight crescent for depth.
	draw_arc(center + Vector2(-radius * 0.15, -radius * 0.2), radius * 0.55, 0.0, TAU, 32, fill.lightened(0.4), 4.0, true)
	# Bright rim.
	draw_arc(center, radius, 0.0, TAU, 64, fill.lightened(0.3), 4.0, true)
	# Pulsing outer glow proportional to charge level (L3 most aggressive).
	var breathe: float = 0.5 + 0.5 * sin(_glow_t * (2.0 + _level))
	var glow := fill
	glow.a = 0.35 * breathe
	draw_arc(center, radius + 6.0 + 2.0 * _level, 0.0, TAU, 64, glow, 3.0 + _level, true)
	# Tier pips along the bottom.
	var pip_color := Color(1.0, 0.95, 0.65, 1.0)
	for i in range(_level):
		var p := Vector2(center.x - 18.0 + i * 18.0, center.y + radius * 0.55)
		draw_circle(p, 5.0, pip_color)

func _color_for_level() -> Color:
	match _level:
		1: return _C_L1
		2: return _C_L2
		3: return _C_L3
	return _C_DISABLED
