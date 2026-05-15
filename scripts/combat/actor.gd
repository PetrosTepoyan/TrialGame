class_name CombatActor
extends Node

signal hp_changed(current_hp: int, max_hp: int)
signal armor_changed(armor: int)
signal status_changed(effects: Array)
signal died(actor: CombatActor)
signal attacked
# Emitted once when current_hp drops below LOW_HP_FRACTION of max_hp. Re-emits
# only if the actor has been healed back above the threshold and re-crossed it.
signal low_hp(actor: CombatActor)

const LOW_HP_FRACTION: float = 0.25

@export var is_player: bool = true
@export var display_name: String = "Hero"
@export var max_hp: int = 100
@export var base_damage: int = 6
@export var inherent_armor: int = 0

var current_hp: int = 0
var armor: int = 0                  # temporary armor stacking on top of inherent_armor
var active_effects: Array = []      # Array[StatusEffect]
var _was_low_hp: bool = false       # latch so low_hp fires once per crossing

# CP3 hook: when set, DoT damage of these kinds is multiplied. Defaults to a
# no-op so callers that don't care don't have to touch it.
var weakness_dot_kinds: Array[int] = []
var weakness_dot_multiplier: float = 1.0

func _ready() -> void:
	current_hp = max_hp
	armor = 0
	active_effects = []
	_was_low_hp = false

func setup(p_max_hp: int, p_base_damage: int, p_inherent_armor: int = 0) -> void:
	max_hp = p_max_hp
	base_damage = p_base_damage
	inherent_armor = p_inherent_armor
	current_hp = max_hp
	armor = 0
	active_effects = []
	_was_low_hp = false
	weakness_dot_kinds = []
	weakness_dot_multiplier = 1.0
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
	_check_low_hp()
	if current_hp <= 0:
		emit_signal("died", self)
	return dmg

func effective_armor() -> int:
	var defense: int = inherent_armor + armor
	# Defense debuff lowers inherent armor by its magnitude while active.
	for fx_v in active_effects:
		var fx: StatusEffect = fx_v
		if fx.kind == StatusEffect.Kind.DEFENSE_DEBUFF and fx.is_active():
			defense = max(0, defense - fx.magnitude)
			break
	return max(0, defense)

func heal(amount: int) -> int:
	var healed: int = min(max_hp - current_hp, amount)
	current_hp += healed
	emit_signal("hp_changed", current_hp, max_hp)
	_check_low_hp()
	return healed

func _check_low_hp() -> void:
	# Latched edge-trigger: low_hp emits once when we cross from healthy to low.
	# Healing back above the threshold rearms it.
	if max_hp <= 0:
		return
	var frac: float = float(current_hp) / float(max_hp)
	var is_low: bool = current_hp > 0 and frac < LOW_HP_FRACTION
	if is_low and not _was_low_hp:
		_was_low_hp = true
		emit_signal("low_hp", self)
	elif not is_low and _was_low_hp:
		_was_low_hp = false

func add_armor(amount: int) -> void:
	armor += amount
	emit_signal("armor_changed", armor + inherent_armor)

func strip_armor(amount: int) -> int:
	var stripped: int = min(armor, amount)
	armor -= stripped
	emit_signal("armor_changed", armor + inherent_armor)
	return stripped

# Refresh-or-add a status. Same-kind statuses merge: longer duration wins, and
# we keep the strongest dps/magnitude of the two.
func apply_status(status: StatusEffect) -> void:
	for existing_v in active_effects:
		var existing: StatusEffect = existing_v
		if existing.kind == status.kind:
			existing.seconds_remaining = max(existing.seconds_remaining, status.seconds_remaining)
			existing.dps = max(existing.dps, status.dps)
			existing.magnitude = max(existing.magnitude, status.magnitude)
			emit_signal("status_changed", active_effects)
			return
	active_effects.append(status)
	emit_signal("status_changed", active_effects)

# Back-compat alias — older callers used apply_effect.
func apply_effect(fx: StatusEffect) -> void:
	apply_status(fx)

# CP3 weakness check: any DoT of a flagged kind hits harder.
func damage_taken_multiplier_for_dot(kind: int) -> float:
	if kind in weakness_dot_kinds:
		return weakness_dot_multiplier
	return 1.0

# Tick all timed effects forward by `delta` seconds. Applies DoT damage,
# decrements seconds_remaining, drops expired statuses. Returns total DoT
# damage taken this tick (for UI / floating text).
func tick_dot_seconds(delta: float) -> int:
	if active_effects.is_empty() or delta <= 0.0:
		return 0
	var dot_dmg_total: int = 0
	# First pass: apply DoT damage. We apply each DoT separately so the weakness
	# multiplier can be per-kind.
	for fx_v in active_effects:
		var fx: StatusEffect = fx_v
		if not fx.is_active():
			continue
		if StatusEffect.is_dot(fx.kind) and fx.dps > 0:
			var slice: float = min(delta, fx.seconds_remaining)
			var raw: float = float(fx.dps) * slice * damage_taken_multiplier_for_dot(fx.kind)
			var dmg: int = int(round(raw))
			if dmg > 0:
				take_damage(dmg, true)  # DoT bypasses armor
				dot_dmg_total += dmg
				if current_hp <= 0:
					break
	# Second pass: decrement durations and prune expired.
	var still_alive: Array = []
	for fx_v in active_effects:
		var fx: StatusEffect = fx_v
		fx.seconds_remaining = max(0.0, fx.seconds_remaining - delta)
		if fx.seconds_remaining > 0.0:
			still_alive.append(fx)
	active_effects = still_alive
	emit_signal("status_changed", active_effects)
	return dot_dmg_total

func is_stunned() -> bool:
	for fx_v in active_effects:
		var fx: StatusEffect = fx_v
		if fx.kind == StatusEffect.Kind.STUN and fx.is_active():
			return true
	return false

func is_alive() -> bool:
	return current_hp > 0
