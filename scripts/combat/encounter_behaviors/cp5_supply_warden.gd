extends EncounterBehavior

# CP5 — Supply Tower Warden (chapter 1 tower boss).
# Three layered mechanics share one encounter:
#   1. Powder-keg pressure gauge. Ticks up every KEG_TICK_PERIOD; reaching
#      KEG_MAX_COUNT triggers a catastrophic blast on the player and resets.
#      Player can reduce pressure by 1 each time a fire_bomb item breaks on
#      the board (forced spawn weights bias the item pool heavily that way).
#   2. Resupply windup. Every modifier.resupply_interval_seconds the warden
#      begins a telegraphed heal-channel; on completion he restores
#      resupply_heal_fraction of max HP. The window can be cancelled if the
#      player either fires an L2+ spec OR deals >= interrupt_damage_threshold
#      damage during the windup.
#   3. Damage-window sampling. _damage_in_window accumulates outgoing damage
#      between resupply windups so the threshold check has a rolling figure.
#
# We deliberately keep the kegs off the board: Board.gd is locked this phase,
# so we model the pressure as an internal counter driven by item events and a
# tick timer. Telegraph banners surface the state through CombatController's
# encounter_telegraph signal.

const KEG_TICK_PERIOD: float = 4.0
const KEG_MAX_COUNT: int = 5
const KEG_BLAST_DAMAGE: int = 30

var _keg_pressure: int = 0
var _keg_tick_timer: float = 0.0

# Resupply state machine.
var _resupply_interval: float = 20.0
var _resupply_window_timer: float = 0.0
var _resupply_telegraph_total: float = 5.0
var _resupply_telegraph_remaining: float = 0.0
var _resupply_heal_fraction: float = 0.10
var _resupply_charging: bool = false
var _interrupt_threshold: int = 200
var _damage_in_window: int = 0

func setup(combat_ref: CombatController, level_ref: LevelResource) -> void:
	super.setup(combat_ref, level_ref)
	if modifier != null:
		if modifier.resupply_interval_seconds > 0.0:
			_resupply_interval = modifier.resupply_interval_seconds
		if modifier.resupply_telegraph_seconds > 0.0:
			_resupply_telegraph_total = modifier.resupply_telegraph_seconds
		if modifier.resupply_heal_fraction > 0.0:
			_resupply_heal_fraction = modifier.resupply_heal_fraction
		if modifier.interrupt_damage_threshold > 0:
			_interrupt_threshold = modifier.interrupt_damage_threshold
	_resupply_window_timer = _resupply_interval
	_keg_tick_timer = KEG_TICK_PERIOD
	_apply_forced_weights()

func _apply_forced_weights() -> void:
	if combat == null or combat.board == null:
		return
	var spawner: ItemSpawner = combat.board.get_item_spawner()
	if spawner == null:
		return
	# Boost fire_bomb dramatically (the keg-defuser), keep red_potion in the mix
	# so the player has a way to soak through resupply-misses.
	var weights: Dictionary = {"fire_bomb": 8.0, "red_potion": 0.5}
	if modifier != null and not modifier.forced_item_weights.is_empty():
		weights = modifier.forced_item_weights
	spawner.set_forced_weights(weights)

func start() -> void:
	if combat != null:
		combat.emit_signal("encounter_telegraph", "Powder kegs lit — break fire bombs to defuse!", 2.5)

func on_tick(delta: float) -> void:
	if combat == null or combat.state == CombatController.State.ENDED:
		return
	_tick_kegs(delta)
	_tick_resupply(delta)

func _tick_kegs(delta: float) -> void:
	_keg_tick_timer -= delta
	if _keg_tick_timer > 0.0:
		return
	_keg_tick_timer = KEG_TICK_PERIOD
	_keg_pressure = min(KEG_MAX_COUNT, _keg_pressure + 1)
	if _keg_pressure >= KEG_MAX_COUNT:
		_detonate_kegs()
	elif _keg_pressure == KEG_MAX_COUNT - 1:
		# Warn at 4/5 so the player can scramble for a fire_bomb match.
		combat.emit_signal("encounter_telegraph", "Kegs at %d/%d!" % [_keg_pressure, KEG_MAX_COUNT], 1.5)
	else:
		combat.emit_signal("encounter_telegraph", "Kegs %d/%d" % [_keg_pressure, KEG_MAX_COUNT], 1.0)

func _detonate_kegs() -> void:
	# Both kegs blow. Pressure resets so the loop continues if the player survives.
	_keg_pressure = 0
	if combat == null or combat.player == null:
		return
	combat.emit_signal("encounter_telegraph", "KEGS DETONATE!", 1.5)
	var dealt: int = combat.player.take_damage(KEG_BLAST_DAMAGE, true, 0)
	if dealt > 0:
		combat.emit_signal("damage_dealt", true, dealt, -1)

func _tick_resupply(delta: float) -> void:
	if _resupply_charging:
		_resupply_telegraph_remaining -= delta
		# If we crossed the interrupt-damage threshold during the windup, fail it.
		if _damage_in_window >= _interrupt_threshold:
			_fail_resupply("Resupply broken!")
			return
		if _resupply_telegraph_remaining <= 0.0:
			_complete_resupply()
		return
	_resupply_window_timer -= delta
	if _resupply_window_timer <= 0.0:
		_begin_resupply()

func _begin_resupply() -> void:
	_resupply_charging = true
	_resupply_telegraph_remaining = _resupply_telegraph_total
	# Reset the windup damage tally so the threshold check covers only this
	# telegraph window (spec: "damage in the prior 20s window" — we measure
	# during the telegraph itself for clearer player feedback).
	_damage_in_window = 0
	if combat != null:
		combat.emit_signal("encounter_telegraph", "Warden resupplying...", _resupply_telegraph_total)

func _fail_resupply(reason: String) -> void:
	_resupply_charging = false
	_resupply_telegraph_remaining = 0.0
	_resupply_window_timer = _resupply_interval
	_damage_in_window = 0
	if combat != null:
		combat.emit_signal("encounter_telegraph", reason, 1.5)

func _complete_resupply() -> void:
	_resupply_charging = false
	_resupply_telegraph_remaining = 0.0
	_resupply_window_timer = _resupply_interval
	_damage_in_window = 0
	if combat == null or combat.enemy == null:
		return
	var heal: int = int(round(float(combat.enemy.max_hp) * _resupply_heal_fraction))
	if heal <= 0:
		return
	# CombatActor.heal is HP-only; clamp + emit happens inside it.
	var healed: int = combat.enemy.heal(heal)
	if healed > 0:
		combat.emit_signal("heal_done", false, healed)
		combat.emit_signal("encounter_telegraph", "Warden recovers %d HP" % healed, 1.5)

func on_player_attacked(_damage: int) -> void:
	pass

func on_spec_attack_fired(level_val: int) -> void:
	# L2+ specs interrupt the resupply outright — the spinning strike "shatters
	# the supply line" per the design doc. L1 (stun) doesn't break the channel.
	if _resupply_charging and level_val >= 2:
		_fail_resupply("Resupply shattered!")

func on_item_broken(item: BoardItem, _location: Vector2i) -> void:
	if item == null:
		return
	# Fire bomb is repurposed in this encounter: in addition to its normal DoT
	# on the enemy (handled by ItemEffects), each broken fire_bomb chips one
	# point off keg pressure — the player's defuse channel.
	if item.id == "fire_bomb":
		if _keg_pressure > 0:
			_keg_pressure -= 1
			if combat != null:
				combat.emit_signal("encounter_telegraph", "Keg defused (%d/%d)" % [_keg_pressure, KEG_MAX_COUNT], 1.0)

# CombatController calls this whenever the enemy takes damage (we forward it
# through register_encounter_behavior). Used to sample the interrupt window.
func on_enemy_damaged(amount: int) -> void:
	if _resupply_charging and amount > 0:
		_damage_in_window += amount
