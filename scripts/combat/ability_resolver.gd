class_name AbilityResolver
extends Object

# Resolves a single match group's effect.
# Returns a Dictionary { "damage": int, "bypass_armor": bool, "heal": int, "armor": int, "rally": int, "clear_kind": int, "extra_turn": bool }
#
# Damage scaling:
#   - Match-3 = base_value * count_factor
#   - Match-4 = base_value * 2 * count_factor + extra_turn
#   - Match-5+ = base_value * 3 * count_factor + clear all of that kind

const ARMOR_BLOCK_PER_SHIELD: int = 2

static func resolve_match(piece_types: Array, kind: int, cells_count: int, longest_run: int) -> Dictionary:
	var pt: PieceType = piece_types[kind]
	var result := {
		"damage": 0,
		"bypass_armor": false,
		"heal": 0,
		"armor": 0,
		"rally": 0,
		"clear_kind": -1,
		"extra_turn": false,
	}
	# Power-up detonations: synthetic match emitted by Board with
	# cells_count == affected_cell_count. Damage scales linearly with reach.
	if PieceType.is_powerup(kind):
		result["damage"] = pt.base_value * cells_count
		# Crossed-Swords pierces armor like an arrow rain.
		if kind == PieceType.Kind.CROSSED_SWORDS:
			result["bypass_armor"] = true
		return result
	# Regular army-piece matches.
	var multiplier: float = 1.0
	if longest_run >= 5:
		multiplier = pt.match5_multiplier
	elif longest_run >= 4:
		multiplier = pt.match4_multiplier
	# Bonus: each additional cell beyond 3 in the cluster adds a flat +1.
	var extra: int = max(0, cells_count - 3)
	var base_total: int = int(pt.base_value * multiplier) + extra
	result["extra_turn"] = longest_run >= 4
	match kind:
		PieceType.Kind.SPEAR:
			result["damage"] = base_total
		PieceType.Kind.ARCHER:
			result["damage"] = base_total
			result["bypass_armor"] = true
		PieceType.Kind.SHIELD:
			result["heal"] = base_total
			result["armor"] = ARMOR_BLOCK_PER_SHIELD * cells_count
		PieceType.Kind.KING:
			result["damage"] = base_total
			result["rally"] = cells_count * 10
	return result
