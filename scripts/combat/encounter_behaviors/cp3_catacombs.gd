extends EncounterBehavior

# CP3 — Catacombs Monster.
# The dweller below is weak to corrosion and fire — flagged DoTs hit it for a
# multiplier set by the encounter modifier. actor.tick_dot_seconds() already
# consults damage_taken_multiplier_for_dot(), so wiring the weakness fields
# on the enemy is sufficient.

func setup(combat_ref: CombatController, level_ref: LevelResource) -> void:
	super.setup(combat_ref, level_ref)
	if combat != null and combat.enemy != null and modifier != null:
		combat.enemy.weakness_dot_kinds = modifier.weak_to_dot_kinds.duplicate()
		combat.enemy.weakness_dot_multiplier = modifier.weak_to_dot_multiplier
	_apply_forced_weights()

func _apply_forced_weights() -> void:
	if combat == null or combat.board == null:
		return
	var spawner: ItemSpawner = combat.board.get_item_spawner()
	if spawner == null:
		return
	var weights: Dictionary = {"acid": 3.0, "fire_bomb": 3.0}
	if modifier != null and not modifier.forced_item_weights.is_empty():
		weights = modifier.forced_item_weights
	spawner.set_forced_weights(weights)

func start() -> void:
	if combat != null:
		combat.emit_signal("encounter_telegraph", "It recoils from fire and acid.", 2.0)
