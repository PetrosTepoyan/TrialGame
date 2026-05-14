class_name AbilityResolver
extends Object

# Per-piece-kind interpretation of accumulated emblems for one round.
#
# Inputs:
#   piece_types : Array[PieceType] indexed by Kind (provides level tables)
#   emblems     : Array[Emblem]    accumulated during this round (size <= 5)
#   shield_choice : int           SHIELD_CHOICE_ARMOR or SHIELD_CHOICE_STUN
#                                  (used only when shield has a 3+ same-level combo)
#
# Output: Dictionary
#   "damage" : int                                  raw HP damage to enemy
#   "bypass" : int                                  portion of damage that bypasses armor
#   "pierce" : int                                  armor stripped before damage
#   "heal"   : int                                  HP returned to player
#   "armor"  : int                                  armor stacked on player
#   "enemy_effects"  : Array[StatusEffect]          DoTs / debuffs / stuns inflicted on enemy
#   "player_effects" : Array[StatusEffect]          buffs added to player (currently none)

const SHIELD_CHOICE_ARMOR := 0
const SHIELD_CHOICE_STUN := 1

# Staff per-level DoTs: which StatusEffect.Kind each level applies.
const STAFF_DOT_BY_LEVEL := {
	1: StatusEffect.Kind.BURN,
	2: StatusEffect.Kind.SWARM,
	3: StatusEffect.Kind.COLD,
}

# Stun and bleed durations (rounds).
const STUN_ROUNDS := 2
const BLEED_ROUNDS := 3
const BLEED_DPS := 2
const DEFENSE_DEBUFF_ROUNDS := 3
const DEFENSE_DEBUFF_MAGNITUDE := 3

static func resolve_round(piece_types: Array, emblems: Array, shield_choice: int = SHIELD_CHOICE_ARMOR) -> Dictionary:
	var result := _empty_result()
	if emblems.is_empty():
		return result
	var by_kind: Dictionary = {}
	for e_v in emblems:
		var e: Emblem = e_v
		if not by_kind.has(e.piece_kind):
			by_kind[e.piece_kind] = []
		(by_kind[e.piece_kind] as Array).append(e)
	for kind in by_kind.keys():
		var group: Array = by_kind[kind]
		_resolve_kind(piece_types, kind, group, shield_choice, result)
	return result

static func _empty_result() -> Dictionary:
	return {
		"damage": 0,
		"bypass": 0,
		"pierce": 0,
		"heal": 0,
		"armor": 0,
		"enemy_effects": [],
		"player_effects": [],
	}

# Per-kind dispatch.
static func _resolve_kind(piece_types: Array, kind: int, group: Array, shield_choice: int, out: Dictionary) -> void:
	var pt: PieceType = piece_types[kind]
	# Bucket emblems by level to detect 3+ same-level combos.
	var level_counts := {1: 0, 2: 0, 3: 0}
	for e_v in group:
		var e: Emblem = e_v
		if level_counts.has(e.level):
			level_counts[e.level] += 1
	# Find the highest-level combo present (only one combo triggers per kind to
	# keep effects readable — if you have 3 L1 AND 3 L2, the higher-level wins).
	var combo_level: int = 0
	var combo_count: int = 0
	for lvl in [3, 2, 1]:
		if level_counts[lvl] >= 3:
			combo_level = lvl
			combo_count = level_counts[lvl]
			break
	# Per-kind effect.
	match kind:
		PieceType.Kind.SWORD:
			_resolve_sword(pt, group, combo_level, combo_count, out)
		PieceType.Kind.SHIELD:
			_resolve_shield(pt, group, combo_level, combo_count, shield_choice, out)
		PieceType.Kind.STAFF:
			_resolve_staff(pt, group, combo_level, combo_count, out)
		PieceType.Kind.BOW:
			_resolve_bow(pt, group, combo_level, combo_count, out)

# --- Sword: stacks straight damage; 3-same-level combo grants a % bonus. ---
static func _resolve_sword(pt: PieceType, group: Array, combo_level: int, combo_count: int, out: Dictionary) -> void:
	var base: int = 0
	for e_v in group:
		var e: Emblem = e_v
		base += _level_value(pt, e.level)
	var bonus_pct: int = _combo_bonus_pct(pt, combo_level, combo_count)
	var total: int = base + int(base * bonus_pct / 100.0)
	out["damage"] = int(out["damage"]) + total

# --- Shield: stacks armor by default; 3+ same-level allows stun-or-armor choice. ---
static func _resolve_shield(pt: PieceType, group: Array, combo_level: int, combo_count: int, shield_choice: int, out: Dictionary) -> void:
	var base_armor: int = 0
	for e_v in group:
		var e: Emblem = e_v
		base_armor += _level_value(pt, e.level)
	var bonus_pct: int = _combo_bonus_pct(pt, combo_level, combo_count)
	if combo_level > 0 and shield_choice == SHIELD_CHOICE_STUN:
		# Trade the armor stack for a stun. Total stun rounds scale with combo bonus.
		var stun_rounds: int = STUN_ROUNDS
		if bonus_pct > 0:
			# Each 50% bonus adds 1 round (roughly).
			stun_rounds += int(bonus_pct / 50)
		(out["enemy_effects"] as Array).append(StatusEffect.new(StatusEffect.Kind.STUN, stun_rounds, 0, 0))
	else:
		var total_armor: int = base_armor + int(base_armor * bonus_pct / 100.0)
		out["armor"] = int(out["armor"]) + total_armor

# --- Staff: each emblem applies a DoT by level; 3+ same-level combo adds direct damage. ---
static func _resolve_staff(pt: PieceType, group: Array, combo_level: int, combo_count: int, out: Dictionary) -> void:
	# Per-emblem DoTs accumulate (apply_effect dedupes by kind, picking the strongest).
	for e_v in group:
		var e: Emblem = e_v
		var dot_kind: int = STAFF_DOT_BY_LEVEL.get(e.level, StatusEffect.Kind.BURN)
		var rounds: int = _level_value(pt, e.level)      # level_values doubles as duration here
		var dps: int = _level_secondary(pt, e.level)     # level_secondary is dps
		(out["enemy_effects"] as Array).append(StatusEffect.new(dot_kind, rounds, dps, 0))
	# 3-same-level combo: direct fireball damage + bonus effect.
	if combo_level > 0:
		var fireball: int = _level_value(pt, combo_level) * combo_count
		var bonus_pct: int = _combo_bonus_pct(pt, combo_level, combo_count)
		fireball = fireball + int(fireball * bonus_pct / 100.0)
		out["damage"] = int(out["damage"]) + fireball
		if combo_level == 3:
			(out["enemy_effects"] as Array).append(StatusEffect.new(StatusEffect.Kind.DEFENSE_DEBUFF, DEFENSE_DEBUFF_ROUNDS, 0, DEFENSE_DEBUFF_MAGNITUDE))

# --- Bow: armor pierce + HP damage; 3 L3-emblems combo adds bleed. ---
static func _resolve_bow(pt: PieceType, group: Array, combo_level: int, combo_count: int, out: Dictionary) -> void:
	var pierce_total: int = 0
	var hp_total: int = 0
	for e_v in group:
		var e: Emblem = e_v
		pierce_total += _level_value(pt, e.level)
		hp_total += _level_secondary(pt, e.level)
	var bonus_pct: int = _combo_bonus_pct(pt, combo_level, combo_count)
	if bonus_pct > 0:
		pierce_total += int(pierce_total * bonus_pct / 100.0)
		hp_total += int(hp_total * bonus_pct / 100.0)
	out["pierce"] = int(out["pierce"]) + pierce_total
	out["damage"] = int(out["damage"]) + hp_total
	# 3 L3 emblems: also apply bleed.
	if combo_level == 3:
		(out["enemy_effects"] as Array).append(StatusEffect.new(StatusEffect.Kind.BLEED, BLEED_ROUNDS, BLEED_DPS, 0))

# --- Helpers ---
static func _level_value(pt: PieceType, level: int) -> int:
	if level < 1 or level > 3:
		return 0
	if pt.level_values.size() < 3:
		return 0
	return pt.level_values[level - 1]

static func _level_secondary(pt: PieceType, level: int) -> int:
	if level < 1 or level > 3:
		return 0
	if pt.level_secondary.size() < 3:
		return 0
	return pt.level_secondary[level - 1]

static func _combo_bonus_pct(pt: PieceType, combo_level: int, combo_count: int) -> int:
	if combo_level == 0 or combo_count < 3:
		return 0
	if pt.combo_bonus_pct.size() < 3:
		return 0
	var base: int = pt.combo_bonus_pct[combo_level - 1]
	var extra_steps: int = max(0, combo_count - 3)
	return base + extra_steps * pt.combo_bonus_step_pct
