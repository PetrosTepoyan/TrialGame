class_name MatchEffectApplier
extends Object

# Per-match per-kind effect dispatch. Replaces the round-based AbilityResolver:
# each match fires immediately, no emblem queue.
#
# Inputs:
#   kind        : int            PieceType.Kind
#   level       : int            1..3 (canonical "tier" from Board.match_resolved
#                                effective_level — covers squares/corners too)
#   longest_run : int            longest axis run (used by sword for stacking)
#
# Returns a Dictionary:
#   damage      : int            HP damage to enemy
#   armor       : int            armor added to player
#   heal        : int            HP healed on player (unused for now)
#   status      : StatusEffect or null   (DoT / debuff to apply on enemy)
#   pierce      : int            armor stripped (bow)
#   debug_label : String         short identifier for logging

# Staff per-level DoT mapping — same kinds the old resolver used.
const STAFF_DOT_BY_LEVEL := {
	1: StatusEffect.Kind.BURN,
	2: StatusEffect.Kind.SWARM,
	3: StatusEffect.Kind.COLD,
}

static func apply(kind: int, level: int, longest_run: int, _caster: CombatActor, _target: CombatActor) -> Dictionary:
	var result := _empty_result()
	if level < 1:
		level = 1
	if level > 3:
		level = 3
	var pt: PieceType = _load_piece_type(kind)
	if pt == null:
		return result
	match kind:
		PieceType.Kind.SWORD:
			_apply_sword(pt, level, longest_run, result)
		PieceType.Kind.SHIELD:
			_apply_shield(pt, level, result)
		PieceType.Kind.STAFF:
			_apply_staff(pt, level, result)
		PieceType.Kind.BOW:
			_apply_bow(pt, level, result)
	return result

static func _apply_sword(pt: PieceType, level: int, longest_run: int, out: Dictionary) -> void:
	# Per spec: sword does small damage per match. Bigger runs scale via the
	# level-table; we lightly bonus very long runs since match-6+ is rare.
	var base: int = _level_value(pt, level)
	var bonus: int = 0
	if longest_run >= 6:
		bonus = base / 2
	out["damage"] = int(out["damage"]) + base + bonus
	out["debug_label"] = "sword_l%d" % level

static func _apply_shield(pt: PieceType, level: int, out: Dictionary) -> void:
	# Spec change: shield always grants armor on match — the old armor-vs-stun
	# branch is gone (stun is now the L1 special attack).
	out["armor"] = int(out["armor"]) + _level_value(pt, level)
	out["debug_label"] = "shield_l%d" % level

static func _apply_staff(pt: PieceType, level: int, out: Dictionary) -> void:
	# Staff lays a DoT. Duration was rounds in the old model — keep the same
	# numeric value, just reinterpret as seconds.
	var dot_kind: int = STAFF_DOT_BY_LEVEL.get(level, StatusEffect.Kind.BURN)
	var dur_secs: float = float(_level_value(pt, level))
	var dps: int = _level_secondary(pt, level)
	out["status"] = StatusEffect.new(dot_kind, dur_secs, dps, 0)
	out["debug_label"] = "staff_l%d" % level

static func _apply_bow(pt: PieceType, level: int, out: Dictionary) -> void:
	# Bow strips armor + small HP damage.
	out["pierce"] = int(out["pierce"]) + _level_value(pt, level)
	out["damage"] = int(out["damage"]) + _level_secondary(pt, level)
	out["debug_label"] = "bow_l%d" % level

# Build the cascade-scope multiplier for a piece type. The combo bonus the .tres
# table stores is now interpreted as a "fired all-same-kind cascade" bonus —
# CombatController accumulates per-cascade matches and consults this when the
# cascade resolves.
static func cascade_bonus_pct(kind: int, level: int, count: int) -> int:
	if count < 3 or level < 1 or level > 3:
		return 0
	var pt: PieceType = _load_piece_type(kind)
	if pt == null or pt.combo_bonus_pct.size() < 3:
		return 0
	var base: int = pt.combo_bonus_pct[level - 1]
	var extra_steps: int = max(0, count - 3)
	return base + extra_steps * pt.combo_bonus_step_pct

static func _empty_result() -> Dictionary:
	return {
		"damage": 0,
		"armor": 0,
		"heal": 0,
		"status": null,
		"pierce": 0,
		"debug_label": "",
	}

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

static func load_piece_type(kind: int) -> PieceType:
	return _load_piece_type(kind)

# Resolve a PieceType resource for a kind. Tries the canonical data path so the
# applier can be called from a static context (CombatController is a Node but
# the resolver itself stays stateless). Returns null on miss — callers check.
static func _load_piece_type(kind: int) -> PieceType:
	var path: String = ""
	match kind:
		PieceType.Kind.SWORD: path = "res://data/piece_types/sword.tres"
		PieceType.Kind.SHIELD: path = "res://data/piece_types/shield.tres"
		PieceType.Kind.STAFF: path = "res://data/piece_types/staff.tres"
		PieceType.Kind.BOW: path = "res://data/piece_types/bow.tres"
	if path != "" and ResourceLoader.exists(path):
		return load(path)
	return null
