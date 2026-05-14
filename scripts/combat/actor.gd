class_name CombatActor
extends Node

signal hp_changed(current_hp: int, max_hp: int)
signal armor_changed(armor: int)
signal status_changed(effects: Array)
signal died(actor: CombatActor)
signal attacked

@export var is_player: bool = true
@export var display_name: String = "Hero"
@export var max_hp: int = 100
@export var base_damage: int = 6
@export var inherent_armor: int = 0

var current_hp: int = 0
var armor: int = 0                  # temporary armor stacking on top of inherent_armor
var active_effects: Array = []      # Array[StatusEffect]

func _ready() -> void:
	current_hp = max_hp
	armor = 0
	active_effects = []

func setup(p_max_hp: int, p_base_damage: int, p_inherent_armor: int = 0) -> void:
	max_hp = p_max_hp
	base_damage = p_base_damage
	inherent_armor = p_inherent_armor
	current_hp = max_hp
	armor = 0
	active_effects = []
	emit_signal("hp_changed", current_hp, max_hp)
	emit_signal("armor_changed", armor + inherent_armor)
	emit_signal("status_changed", active_effects)

func take_damage(raw: int, bypass_armor: bool = false, pierce: int = 0) -> int:
	# Optional `pierce` strips armor before mitigation (used by Bow's pierce).
	if pierce > 0 and armor > 0:
		var to_strip: int = min(armor, pierce)
		armor -= to_strip
		emit_signal("armor_changed", armor + inherent_armor)
	var blocked: int = 0
	var dmg: int = raw
	if not bypass_armor:
		var defense: int = effective_armor()
		blocked = min(defense, dmg)
		dmg -= blocked
		if armor > 0:
			var consumed: int = min(armor, blocked)
			armor -= consumed
			emit_signal("armor_changed", armor + inherent_armor)
	current_hp = max(0, current_hp - dmg)
	emit_signal("hp_changed", current_hp, max_hp)
	if current_hp <= 0:
		emit_signal("died", self)
	return dmg

func effective_armor() -> int:
	var defense: int = inherent_armor + armor
	# Defense debuff lowers inherent armor by its magnitude while active.
	for fx_v in active_effects:
		var fx: StatusEffect = fx_v
		if fx.kind == StatusEffect.Kind.DEFENSE_DEBUFF:
			defense = max(0, defense - fx.magnitude)
			break
	return max(0, defense)

func heal(amount: int) -> int:
	var healed: int = min(max_hp - current_hp, amount)
	current_hp += healed
	emit_signal("hp_changed", current_hp, max_hp)
	return healed

func add_armor(amount: int) -> void:
	armor += amount
	emit_signal("armor_changed", armor + inherent_armor)

func strip_armor(amount: int) -> int:
	var stripped: int = min(armor, amount)
	armor -= stripped
	emit_signal("armor_changed", armor + inherent_armor)
	return stripped

func apply_effect(fx: StatusEffect) -> void:
	# If an effect of this kind already exists, refresh its duration to the
	# longer of the two and keep the stronger dps/magnitude.
	for existing_v in active_effects:
		var existing: StatusEffect = existing_v
		if existing.kind == fx.kind:
			existing.rounds_remaining = max(existing.rounds_remaining, fx.rounds_remaining)
			existing.dps = max(existing.dps, fx.dps)
			existing.magnitude = max(existing.magnitude, fx.magnitude)
			emit_signal("status_changed", active_effects)
			return
	active_effects.append(fx)
	emit_signal("status_changed", active_effects)

# Tick all DoTs once and decrement durations. Returns total DoT damage taken.
# Stun and defense-debuff also decrement here but don't directly do damage.
func tick_effects() -> int:
	if active_effects.is_empty():
		return 0
	var dot_dmg: int = 0
	for fx_v in active_effects:
		var fx: StatusEffect = fx_v
		if StatusEffect.is_dot(fx.kind):
			dot_dmg += fx.dps
	if dot_dmg > 0:
		take_damage(dot_dmg, true)  # DoT bypasses armor
	# Decrement durations after damage applied.
	var still_alive: Array = []
	for fx_v in active_effects:
		var fx: StatusEffect = fx_v
		fx.rounds_remaining -= 1
		if fx.rounds_remaining > 0:
			still_alive.append(fx)
	active_effects = still_alive
	emit_signal("status_changed", active_effects)
	return dot_dmg

func is_stunned() -> bool:
	for fx_v in active_effects:
		var fx: StatusEffect = fx_v
		if fx.kind == StatusEffect.Kind.STUN and fx.rounds_remaining > 0:
			return true
	return false

func is_alive() -> bool:
	return current_hp > 0
