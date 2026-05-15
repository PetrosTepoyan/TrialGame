extends EncounterBehavior

# CP4 — Naval Pier with cannons.
# Periodic telegraphed cannon shot, armor-bypassing. Any player spec during
# the telegraph cancels the shot — encourages spending mana defensively.

var _cannon_timer: float = 0.0
var _cannon_period: float = 8.0
var _cannon_telegraph: float = 2.0
var _cannon_damage: int = 18
var _telegraph_remaining: float = 0.0
var _cannon_charging: bool = false

func setup(combat_ref: CombatController, level_ref: LevelResource) -> void:
	super.setup(combat_ref, level_ref)
	if modifier != null:
		if modifier.cannon_period > 0.0:
			_cannon_period = modifier.cannon_period
		if modifier.cannon_telegraph_time > 0.0:
			_cannon_telegraph = modifier.cannon_telegraph_time
		if modifier.cannon_damage > 0:
			_cannon_damage = modifier.cannon_damage
	_cannon_timer = _cannon_period

func on_tick(delta: float) -> void:
	if combat == null or combat.state == CombatController.State.ENDED:
		return
	if _cannon_charging:
		_telegraph_remaining -= delta
		if _telegraph_remaining <= 0.0:
			_cannon_charging = false
			_fire_cannon()
		return
	_cannon_timer -= delta
	if _cannon_timer <= 0.0:
		_begin_cannon_telegraph()
		_cannon_timer = _cannon_period

func _begin_cannon_telegraph() -> void:
	_cannon_charging = true
	_telegraph_remaining = _cannon_telegraph
	if combat != null:
		combat.emit_signal("encounter_telegraph", "Cannon priming...", _cannon_telegraph)

func _fire_cannon() -> void:
	if combat == null or combat.player == null:
		return
	# Armor-bypass: pass bypass_armor=true so plate doesn't matter.
	var dealt: int = combat.player.take_damage(_cannon_damage, true, 0)
	if dealt > 0:
		combat.emit_signal("damage_dealt", true, dealt, -1)

func on_spec_attack_fired(_level_val: int) -> void:
	# Any spec during the telegraph cancels the cannon.
	if _cannon_charging:
		_cannon_charging = false
		_telegraph_remaining = 0.0
		if combat != null:
			combat.emit_signal("encounter_telegraph", "Cannon dispersed!", 1.2)
