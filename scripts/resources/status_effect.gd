class_name StatusEffect
extends Resource

enum Kind {
	BURN,            # staff L1 — DoT
	SWARM,           # staff L2 — DoT
	COLD,            # staff L3 — DoT
	BLEED,           # bow combo L3 — DoT
	STUN,            # shield 3-emblem (player choice) — skip enemy turn
	DEFENSE_DEBUFF,  # staff combo L3 — reduces target armor
}

@export var kind: int = Kind.BURN
@export var rounds_remaining: int = 0
@export var dps: int = 0           # damage per round tick (DoT effects)
@export var magnitude: int = 0     # generic field (armor reduction etc.)

func _init(p_kind: int = 0, p_rounds: int = 0, p_dps: int = 0, p_magnitude: int = 0) -> void:
	kind = p_kind
	rounds_remaining = p_rounds
	dps = p_dps
	magnitude = p_magnitude

static func kind_to_string(k: int) -> String:
	match k:
		Kind.BURN: return "Burn"
		Kind.SWARM: return "Swarm"
		Kind.COLD: return "Cold"
		Kind.BLEED: return "Bleed"
		Kind.STUN: return "Stun"
		Kind.DEFENSE_DEBUFF: return "Defense Debuff"
	return "Unknown"

static func is_dot(k: int) -> bool:
	return k == Kind.BURN or k == Kind.SWARM or k == Kind.COLD or k == Kind.BLEED
