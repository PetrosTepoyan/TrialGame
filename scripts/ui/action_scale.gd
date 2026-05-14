class_name ActionScale
extends HBoxContainer

# 5 emblem slots that visualize the CombatController's accumulating action scale.
# When `slot_filled(i, emblem)` is called the corresponding cell pops in with
# the emblem's color/icon and a small level badge.

const CAPACITY: int = 5
const SLOT_SIZE: float = 64.0

var _slots: Array = []  # Array[ActionScaleSlot]

func _ready() -> void:
	add_theme_constant_override("separation", 8)
	for i in range(CAPACITY):
		var slot := ActionScaleSlot.new()
		slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		add_child(slot)
		_slots.append(slot)

func fill_slot(index: int, emblem: Emblem) -> void:
	if index < 0 or index >= CAPACITY:
		return
	(_slots[index] as ActionScaleSlot).set_emblem(emblem)

func clear_all() -> void:
	for s_v in _slots:
		var s: ActionScaleSlot = s_v
		s.set_emblem(null)

# Visualize the round-execution "fire all emblems" beat — slots flash, then clear.
func play_execute_animation() -> void:
	for s_v in _slots:
		var s: ActionScaleSlot = s_v
		s.flash()
