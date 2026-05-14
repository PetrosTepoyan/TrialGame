class_name PieceType
extends Resource

enum Kind { KING, SHIELD, SPEAR, ARCHER, BOMB, CROSSED_SWORDS }

# The first 4 kinds are the spawnable "army" pieces. The last 2 are power-up
# tiles that are *only* placed by matching 4+ / 5+ of the same army piece —
# never spawned from refill.
const SPAWNABLE_KIND_COUNT: int = 4

@export var kind: int = Kind.SPEAR
@export var display_name: String = "Spear"
@export var color: Color = Color.WHITE
# Base damage / heal amount per piece in a length-3 match.
@export var base_value: int = 4
# Match-of-4 multiplier and match-of-5 multiplier.
@export var match4_multiplier: float = 2.0
@export var match5_multiplier: float = 3.0
# Optional SVG sprite path; if empty the piece is drawn programmatically.
@export var sprite_path: String = ""

static func kind_to_string(k: int) -> String:
	match k:
		Kind.KING: return "King"
		Kind.SHIELD: return "Shield"
		Kind.SPEAR: return "Spear"
		Kind.ARCHER: return "Archer"
		Kind.BOMB: return "Bomb"
		Kind.CROSSED_SWORDS: return "Crossed Swords"
	return "Unknown"

static func is_powerup(k: int) -> bool:
	return k == Kind.BOMB or k == Kind.CROSSED_SWORDS

