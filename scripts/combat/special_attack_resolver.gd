class_name SpecialAttackResolver
extends RefCounted

# Static dispatcher for the player's tiered special attacks. The actual hit /
# animation timing is owned by battle.gd — this just packages the data.
#
# Returns dict shape:
#   damage          : int
#   status          : StatusEffect or null
#   animation_id    : String   (battle.gd switches on this)
#   bypass_armor    : bool
#   stun_seconds    : float    (informational; only L1 uses it currently)
#   level           : int      (echoed back for convenience)

static func resolve(spec: SpecialAttack, _caster: CombatActor, _target: CombatActor) -> Dictionary:
	if spec == null:
		return _empty()
	var status: StatusEffect = spec.status_on_hit
	# L1 shield bash: ensure a STUN status with stun_seconds even if the .tres
	# author forgot to attach one. The button color is the canonical source for
	# tier anyway — we synthesize the status here.
	if status == null and spec.level == 1 and spec.stun_seconds > 0.0:
		status = StatusEffect.new(StatusEffect.Kind.STUN, spec.stun_seconds, 0, 0)
	# L3 shadow strike: spec says "damage + bleed" but the .tres ships with a
	# null status to keep the resource generic. Synthesize the bleed inline so
	# the resolver is the single source of truth.
	if status == null and spec.level == 3:
		status = StatusEffect.new(StatusEffect.Kind.BLEED, 8.0, 2, 0)
	return {
		"damage": spec.base_damage,
		"status": status,
		"animation_id": spec.animation_id,
		"bypass_armor": spec.bypass_armor,
		"stun_seconds": spec.stun_seconds,
		"level": spec.level,
	}

static func _empty() -> Dictionary:
	return {
		"damage": 0,
		"status": null,
		"animation_id": "",
		"bypass_armor": false,
		"stun_seconds": 0.0,
		"level": 0,
	}
