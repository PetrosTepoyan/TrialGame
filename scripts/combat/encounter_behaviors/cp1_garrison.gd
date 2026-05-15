extends EncounterBehavior

# CP1 — Forward Garrison.
# Five enemies share the battle on one HP bar. Each "enemy" is a fresh full
# HP pool; the player keeps their HP across the swap. The level's authored
# enemy_max_hp becomes the per-enemy HP, so the total damage budget is 5×.

var _remaining_enemies: int = 1
var _per_enemy_max_hp: int = 60

func setup(combat_ref: CombatController, level_ref: LevelResource) -> void:
	super.setup(combat_ref, level_ref)
	var count: int = 1
	if modifier != null and modifier.enemies_in_a_row > 1:
		count = modifier.enemies_in_a_row
	_remaining_enemies = count
	# Capture authored HP BEFORE start() resets things — the level resource has
	# the per-enemy budget; total HP isn't multiplied because each death refills.
	if combat != null and combat.enemy != null:
		_per_enemy_max_hp = combat.enemy.max_hp
	# Forced item weights: encourage shields + heals since this is a sustained
	# fight against a fresh enemy every time HP drops.
	_apply_forced_weights()

func _apply_forced_weights() -> void:
	if combat == null or combat.board == null:
		return
	var spawner: ItemSpawner = combat.board.get_item_spawner()
	if spawner == null:
		return
	var weights: Dictionary = {"shield": 3.0, "red_potion": 3.0}
	if modifier != null and not modifier.forced_item_weights.is_empty():
		weights = modifier.forced_item_weights
	spawner.set_forced_weights(weights)

func start() -> void:
	# Make sure HP is full at battle open even if other systems prodded it.
	if combat != null and combat.enemy != null:
		combat.enemy.current_hp = _per_enemy_max_hp
		combat.enemy.emit_signal("hp_changed", combat.enemy.current_hp, combat.enemy.max_hp)

func on_enemy_died() -> bool:
	# More enemies in the queue: refill HP, signal the swap, absorb the death.
	if _remaining_enemies <= 1:
		return false
	_remaining_enemies -= 1
	if combat != null and combat.enemy != null:
		combat.enemy.current_hp = _per_enemy_max_hp
		# Clear DoT/status carried over from the dead one.
		combat.enemy.active_effects = []
		combat.enemy.armor = 0
		combat.enemy.emit_signal("hp_changed", combat.enemy.current_hp, combat.enemy.max_hp)
		combat.enemy.emit_signal("armor_changed", combat.enemy.effective_armor())
		combat.enemy.emit_signal("status_changed", combat.enemy.active_effects)
	if combat != null:
		combat.emit_signal("enemy_replaced", _remaining_enemies)
		combat.emit_signal("encounter_telegraph", "Another guard steps forward! (%d left)" % _remaining_enemies, 1.5)
	return true
