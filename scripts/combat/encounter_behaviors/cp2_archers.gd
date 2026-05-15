extends EncounterBehavior

# CP2 — Wall Archers.
# Periodic ranged volleys hit the player; a RANGED_SHIELD status (1 charge)
# blocks one volley outright. Shields broken on the board grant a charge.

var _volley_timer: float = 0.0
var _volley_period: float = 6.0
var _volley_damage: int = 10
var _telegraph_remaining: float = 0.0
const TELEGRAPH_SECONDS: float = 1.5

func setup(combat_ref: CombatController, level_ref: LevelResource) -> void:
	super.setup(combat_ref, level_ref)
	if modifier != null:
		if modifier.ranged_volley_period > 0.0:
			_volley_period = modifier.ranged_volley_period
		if modifier.ranged_volley_damage > 0:
			_volley_damage = modifier.ranged_volley_damage
	_volley_timer = _volley_period
	_apply_forced_weights()

func _apply_forced_weights() -> void:
	if combat == null or combat.board == null:
		return
	var spawner: ItemSpawner = combat.board.get_item_spawner()
	if spawner == null:
		return
	var weights: Dictionary = {"shield": 4.0}
	if modifier != null and not modifier.forced_item_weights.is_empty():
		weights = modifier.forced_item_weights
	spawner.set_forced_weights(weights)

func on_tick(delta: float) -> void:
	if combat == null or combat.state == CombatController.State.ENDED:
		return
	if _telegraph_remaining > 0.0:
		_telegraph_remaining -= delta
		if _telegraph_remaining <= 0.0:
			_fire_volley()
		return
	_volley_timer -= delta
	if _volley_timer <= 0.0:
		_telegraph_remaining = TELEGRAPH_SECONDS
		_volley_timer = _volley_period
		combat.emit_signal("encounter_telegraph", "Volley incoming!", TELEGRAPH_SECONDS)

func _fire_volley() -> void:
	if combat == null or combat.player == null:
		return
	# If player has a RANGED_SHIELD charge, consume it and block.
	if _consume_ranged_shield():
		combat.emit_signal("encounter_telegraph", "Shield holds!", 1.0)
		return
	var dealt: int = combat.player.take_damage(_volley_damage, false, 0)
	if dealt > 0:
		combat.emit_signal("damage_dealt", true, dealt, -1)

func _consume_ranged_shield() -> bool:
	if combat == null or combat.player == null:
		return false
	for fx_v in combat.player.active_effects:
		var fx: StatusEffect = fx_v
		if fx.kind == StatusEffect.Kind.RANGED_SHIELD and fx.is_active():
			fx.magnitude = max(0, fx.magnitude - 1)
			if fx.magnitude <= 0:
				fx.seconds_remaining = 0.0
			combat.player.emit_signal("status_changed", combat.player.active_effects)
			return true
	return false

func on_item_broken(item: BoardItem, _location: Vector2i) -> void:
	if item == null or combat == null or combat.player == null:
		return
	# Reuse the existing shield item: in this encounter, a broken shield ALSO
	# grants a single-charge ranged-shield status (in addition to its normal
	# armor restore handled by ItemEffects).
	if item.id == "shield":
		var rs := StatusEffect.new(StatusEffect.Kind.RANGED_SHIELD, 999.0, 0, 1)
		combat.player.apply_status(rs)
		combat.emit_signal("status_applied", true, rs)
