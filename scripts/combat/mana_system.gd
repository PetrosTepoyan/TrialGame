class_name ManaSystem
extends Node

# Player mana resource. Thresholds 100/200/300 unlock special-attack tiers 1/2/3.
# Firing the special attack burns the entire bar regardless of tier.

const MAX_MANA: int = 300
const THRESHOLDS: Array[int] = [100, 200, 300]

signal mana_changed(value: int, max_mana: int)
signal charge_level_changed(level: int)

var mana: int = 0:
	set(v):
		var clamped: int = clampi(v, 0, MAX_MANA)
		var old_level: int = get_charge_level()
		mana = clamped
		mana_changed.emit(mana, MAX_MANA)
		var new_level: int = get_charge_level()
		if new_level != old_level:
			charge_level_changed.emit(new_level)

func add(amount: int) -> void:
	self.mana = self.mana + amount

func get_charge_level() -> int:
	if mana >= THRESHOLDS[2]:
		return 3
	if mana >= THRESHOLDS[1]:
		return 2
	if mana >= THRESHOLDS[0]:
		return 1
	return 0

func consume_all() -> int:
	var level: int = get_charge_level()
	self.mana = 0
	return level
