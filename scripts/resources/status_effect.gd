class_name StatusEffect
extends Resource

enum Kind {
	BURN,            # staff L1 — DoT
	SWARM,           # staff L2 — DoT
	COLD,            # staff L3 — DoT
	BLEED,           # bow combo L3 — DoT
	STUN,            # shield 3-emblem (player choice) — skip enemy turn
	DEFENSE_DEBUFF,  # staff combo L3 — reduces target armor
	ACID_BURN,
	IGNITE,
	ATTACK_BUFF,
	ARMOR_DEBUFF_ITEM,
	RANGED_SHIELD,
}

# rounds_remaining is deprecated as of Phase B (auto-attack model has no rounds).
# Field is kept for save-compat / Inspector continuity; do not read it in new code.
@export var rounds_remaining: int = 0
@export var seconds_remaining: float = 0.0
@export var kind: int = Kind.BURN
@export var dps: int = 0           # damage per tick (DoT effects)
@export var magnitude: int = 0     # generic field (armor reduction etc.)

# Constructor: seconds first now. Older callers passing rounds get migrated by
# CombatController/MatchEffectApplier — anything new should pass seconds directly.
func _init(p_kind: int = 0, p_seconds: float = 0.0, p_dps: int = 0, p_magnitude: int = 0) -> void:
	kind = p_kind
	seconds_remaining = p_seconds
	dps = p_dps
	magnitude = p_magnitude

func is_active() -> bool:
	return seconds_remaining > 0.0

static func kind_to_string(k: int) -> String:
	match k:
		Kind.BURN: return "Burn"
		Kind.SWARM: return "Swarm"
		Kind.COLD: return "Cold"
		Kind.BLEED: return "Bleed"
		Kind.STUN: return "Stun"
		Kind.DEFENSE_DEBUFF: return "Defense Debuff"
		Kind.ACID_BURN: return "Acid Burn"
		Kind.IGNITE: return "Ignite"
		Kind.ATTACK_BUFF: return "Attack Buff"
		Kind.ARMOR_DEBUFF_ITEM: return "Armor Debuff"
		Kind.RANGED_SHIELD: return "Ranged Shield"
	return "Unknown"

static func is_dot(k: int) -> bool:
	return (k == Kind.BURN
		or k == Kind.SWARM
		or k == Kind.COLD
		or k == Kind.BLEED
		or k == Kind.ACID_BURN
		or k == Kind.IGNITE)
