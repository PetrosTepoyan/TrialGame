class_name ActionScale
extends HBoxContainer

# 5 emblem slots that visualize an accumulating action scale (hero or enemy).
# When `fill_slot(i, emblem)` is called the corresponding cell pops in with the
# emblem's color/icon and a small level badge.

const CAPACITY: int = 5

@export var slot_size: float = 56.0
@export var slot_separation: int = 6

var _slots: Array = []  # Array[ActionScaleSlot]
var _glow_tween: Tween = null

func _ready() -> void:
	add_theme_constant_override("separation", slot_separation)
	for i in range(CAPACITY):
		var slot := ActionScaleSlot.new()
		slot.custom_minimum_size = Vector2(slot_size, slot_size)
		add_child(slot)
		_slots.append(slot)

func fill_slot(index: int, emblem: Emblem) -> void:
	if index < 0 or index >= CAPACITY:
		return
	(_slots[index] as ActionScaleSlot).set_emblem(emblem)
	_refresh_full_glow()

func clear_all() -> void:
	for s_v in _slots:
		var s: ActionScaleSlot = s_v
		s.set_emblem(null)
	_refresh_full_glow()

# Visualize the round-execution "fire all emblems" beat — slots flash, then clear.
func play_execute_animation() -> void:
	for s_v in _slots:
		var s: ActionScaleSlot = s_v
		s.flash()

func _refresh_full_glow() -> void:
	# When the strip is at full capacity the parent HBoxContainer's modulate
	# pulses to a soft gold — telegraphing "ready to fire" without a 2D shader.
	var full: bool = true
	for s_v in _slots:
		var s: ActionScaleSlot = s_v
		if s._emblem == null:
			full = false
			break
	if _glow_tween != null and _glow_tween.is_valid():
		_glow_tween.kill()
		_glow_tween = null
	if full:
		_glow_tween = create_tween().set_loops()
		_glow_tween.tween_property(self, "modulate", Color(1.15, 1.05, 0.85, 1), 0.5).set_trans(Tween.TRANS_SINE)
		_glow_tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1), 0.5).set_trans(Tween.TRANS_SINE)
	else:
		modulate = Color(1, 1, 1, 1)
