class_name PieceType
extends Resource

# Four "army" piece kinds that fill the 9x9 board. Each kind has up to 3 levels;
# the level is determined by the run length of the player's match:
#   match-3 -> Level 1
#   match-4 -> Level 2
#   match-5+ -> Level 3
# A match emits an Emblem(kind, level) onto the action scale. When the scale is
# full (5 emblems) the round resolves and emblems apply their effects.
enum Kind { SWORD, SHIELD, STAFF, BOW }

const KIND_COUNT: int = 4
const SPAWNABLE_KIND_COUNT: int = 4  # all kinds are spawnable; no power-up tiles

@export var kind: int = Kind.SWORD
@export var display_name: String = "Sword"
@export var color: Color = Color.WHITE
@export var sprite_path: String = ""

# Per-level effect values, indexed [1..3]. Each kind interprets these slightly
# differently — see AbilityResolver for the per-kind logic.
#
# Sword:          level_values = [10, 12, 15]          (raw damage)
# Shield:         level_armor  = [1, 3, 5]             (armor per emblem)
# Staff:          level_burn_rounds = [3, 5, 7]        (DoT duration in rounds)
#                 level_burn_dps    = [5, 5, 5]        (DoT damage per round tick)
# Bow:            level_pierce = [2, 3, 5]             (armor stripped)
#                 level_hp     = [1, 2, 3]             (HP damage)
@export var level_values: Array[int] = [0, 0, 0]
@export var level_secondary: Array[int] = [0, 0, 0]

# Bonus % applied when 3+ emblems of the same level land in the scale this round.
@export var combo_bonus_pct: Array[int] = [60, 75, 100]
# Each additional same-level emblem beyond 3 adds this percentage on top.
@export var combo_bonus_step_pct: int = 20

static func kind_to_string(k: int) -> String:
	match k:
		Kind.SWORD: return "Sword"
		Kind.SHIELD: return "Shield"
		Kind.STAFF: return "Staff"
		Kind.BOW: return "Bow"
	return "Unknown"

static func level_from_match(longest_run: int) -> int:
	if longest_run >= 5:
		return 3
	if longest_run >= 4:
		return 2
	return 1
