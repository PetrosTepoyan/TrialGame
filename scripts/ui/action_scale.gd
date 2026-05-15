class_name ActionScale
extends HBoxContainer

# 5 emblem slots that visualize an actor's accumulating action scale. Used
# both for the player (large slots, bottom of screen) and the enemy (small
# slots, above the enemy sprite).

const CAPACITY: int = 5

@export var slot_size: float = 64.0
@export var separation: int = 8

var _slots: Array = []  # Array[ActionScaleSlot]

func _ready() -> void:
	add_theme_constant_override("separation", separation)
	for i in range(CAPACITY):
		var slot := ActionScaleSlot.new()
		slot.custom_minimum_size = Vector2(slot_size, slot_size)
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
