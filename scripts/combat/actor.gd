class_name CombatActor
extends Node

signal hp_changed(current_hp: int, max_hp: int)
signal armor_changed(armor: int)
signal died(actor: CombatActor)
signal attacked

@export var is_player: bool = true
@export var display_name: String = "Hero"
@export var max_hp: int = 100
@export var base_damage: int = 6
@export var inherent_armor: int = 0

var current_hp: int = 0
var armor: int = 0  # temporary armor stacking on top of inherent_armor

func _ready() -> void:
	current_hp = max_hp
	armor = 0

func setup(p_max_hp: int, p_base_damage: int, p_inherent_armor: int = 0) -> void:
	max_hp = p_max_hp
	base_damage = p_base_damage
	inherent_armor = p_inherent_armor
	current_hp = max_hp
	armor = 0
	emit_signal("hp_changed", current_hp, max_hp)
	emit_signal("armor_changed", armor + inherent_armor)

func take_damage(raw: int, bypass_armor: bool = false) -> int:
	var blocked: int = 0
	var dmg: int = raw
	if not bypass_armor:
		var total_armor: int = inherent_armor + armor
		blocked = min(total_armor, dmg)
		dmg -= blocked
		# Temporary armor decays per hit.
		if armor > 0:
			armor = max(0, armor - blocked)
			emit_signal("armor_changed", armor + inherent_armor)
	current_hp = max(0, current_hp - dmg)
	emit_signal("hp_changed", current_hp, max_hp)
	if current_hp <= 0:
		emit_signal("died", self)
	return dmg

func heal(amount: int) -> int:
	var healed: int = min(max_hp - current_hp, amount)
	current_hp += healed
	emit_signal("hp_changed", current_hp, max_hp)
	return healed

func add_armor(amount: int) -> void:
	armor += amount
	emit_signal("armor_changed", armor + inherent_armor)

func is_alive() -> bool:
	return current_hp > 0
