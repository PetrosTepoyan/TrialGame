class_name CombatController
extends Node

# Real-time action-scale combat:
#   - Player matches accumulate emblems on the hero's action scale (capacity 5).
#     When it fills, the round resolves via AbilityResolver against the enemy.
#   - The enemy fills its own action scale independently at 1 emblem / second.
#     Emblems are drawn from a simulated 5x5 board so combos are naturally
#     rarer than what the hero gets from the 9x9. When the enemy scale fills it
#     applies its abilities to the hero and resets.
#   - Enemy resolves wait for the player's round to finish if one is in flight,
#     so effects never interleave mid-resolve.

signal turn_changed(is_player_turn: bool)
signal damage_dealt(target_is_player: bool, amount: int, source_kind: int)
signal heal_done(target_is_player: bool, amount: int)
signal status_applied(target_is_player: bool, effect: StatusEffect)
signal emblem_added(emblem: Emblem, scale_size: int)
signal round_executing(emblems: Array)
signal round_finished
signal enemy_emblem_added(emblem: Emblem, scale_size: int)
signal enemy_round_executing(emblems: Array)
signal enemy_round_finished
signal shield_choice_required(combo_level: int)
signal battle_won
signal battle_lost
signal enemy_stunned_skipped

enum State { PLAYER_INPUT, RESOLVING, ENDED }

const SCALE_CAPACITY: int = 5
const ENEMY_TICK_SECONDS: float = 1.0
const ENEMY_SIM_BOARD_SIZE: int = 5

@export var board_path: NodePath
@export var player_actor_path: NodePath
@export var enemy_actor_path: NodePath
@export var level: LevelResource

@onready var board: Board = get_node(board_path)
@onready var player: CombatActor = get_node(player_actor_path)
@onready var enemy: CombatActor = get_node(enemy_actor_path)

var state: int = State.PLAYER_INPUT
var action_scale: Array = []            # Array[Emblem]
var _overflow_emblems: Array = []       # Emblems collected while a round is mid-execution
var _player_round_count: int = 0
var _enemy_round_count: int = 0
var _pending_shield_choice: int = -1
var _player_round_in_flight: bool = false
var _enemy_round_in_flight: bool = false

var enemy_action_scale: Array = []      # Array[Emblem]
var _enemy_tick_timer: Timer = null
var _enemy_rng := RandomNumberGenerator.new()

func _ready() -> void:
	_enemy_rng.randomize()
	if level == null:
		level = GameState.get_current_level()
	_apply_level_stats()
	board.match_resolved.connect(_on_match_resolved)
	board.cascade_finished.connect(_on_cascade_finished)
	board.invalid_swap.connect(_on_invalid_swap)
	player.died.connect(_on_player_died)
	enemy.died.connect(_on_enemy_died)
	state = State.PLAYER_INPUT
	emit_signal("turn_changed", true)
	_enemy_tick_timer = Timer.new()
	_enemy_tick_timer.wait_time = ENEMY_TICK_SECONDS
	_enemy_tick_timer.one_shot = false
	_enemy_tick_timer.autostart = false
	add_child(_enemy_tick_timer)
	_enemy_tick_timer.timeout.connect(_on_enemy_tick)
	_enemy_tick_timer.start()

func _apply_level_stats() -> void:
	player.is_player = true
	player.display_name = "Hero"
	player.setup(GameState.player_max_hp, 6, 0)
	enemy.is_player = false
	enemy.display_name = level.enemy_name
	var enemy_armor: int = 0
	if level.boss_modifier != null:
		enemy_armor = level.boss_modifier.armor
	enemy.setup(level.enemy_max_hp, level.enemy_damage, enemy_armor)

func _on_match_resolved(kind: int, _count: int, longest_run: int) -> void:
	# Each match yields one Emblem. Sword damage / etc. is now decided at round
	# execution time, not per-match.
	if state == State.ENDED:
		return
	var lvl: int = PieceType.level_from_match(longest_run)
	var e := Emblem.new(kind, lvl)
	if action_scale.size() >= SCALE_CAPACITY:
		_overflow_emblems.append(e)
	else:
		action_scale.append(e)
		emit_signal("emblem_added", e, action_scale.size())

func _on_cascade_finished(_total: int, _depth: int) -> void:
	if state == State.ENDED:
		return
	if action_scale.size() >= SCALE_CAPACITY:
		_execute_round()
	else:
		# Cascade resolved without filling the scale — back to player input.
		_recheck_player_input()

func _on_invalid_swap() -> void:
	pass

# --- Player round execution ---

func _execute_round() -> void:
	_player_round_in_flight = true
	state = State.RESOLVING
	board.set_input_locked(true)
	emit_signal("turn_changed", false)
	emit_signal("round_executing", action_scale.duplicate())
	AudioBus.play_round_execute()
	_spawn_round_execute_burst()
	var shield_choice: int = AbilityResolver.SHIELD_CHOICE_ARMOR
	var shield_combo_level: int = _detect_shield_combo_level(action_scale)
	if shield_combo_level > 0:
		shield_choice = await _await_shield_choice(shield_combo_level)
	var result: Dictionary = AbilityResolver.resolve_round(board.piece_types, action_scale, shield_choice)
	await _apply_player_round_result(result)
	if state == State.ENDED:
		_player_round_in_flight = false
		return
	# Tick DoTs/stun counters once per resolved player round.
	var enemy_dot: int = enemy.tick_effects()
	if enemy_dot > 0:
		emit_signal("damage_dealt", false, enemy_dot, -1)
	var player_dot: int = player.tick_effects()
	if player_dot > 0:
		emit_signal("damage_dealt", true, player_dot, -1)
	if state == State.ENDED:
		_player_round_in_flight = false
		return
	# Reset scale, accept any overflow emblems collected mid-round.
	action_scale = _overflow_emblems
	_overflow_emblems = []
	_player_round_count += 1
	emit_signal("round_finished")
	_player_round_in_flight = false
	_recheck_player_input()

func _spawn_round_execute_burst() -> void:
	# Drop a RoundExecuteBurst into the scene at a sensible screen-space center
	# so the VFX reads even though CombatController is a logic-only Node. The
	# battle scene parents Combat directly — we attach the burst there.
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var viewport_size: Vector2 = Vector2(1080, 1920)
	var tree := get_tree()
	if tree != null and tree.root != null:
		viewport_size = tree.root.get_visible_rect().size
	# Center the burst horizontally; vertically it sits near the action scale
	# strip — battle.tscn places PlayerActionScale around y=444. That keeps the
	# ring expanding from the scale itself.
	var center: Vector2 = Vector2(viewport_size.x * 0.5, 480.0)
	var colors: Array = []
	for e_v in action_scale:
		var e: Emblem = e_v
		colors.append(_kind_to_color(e.piece_kind))
	RoundExecuteBurst.spawn(center, viewport_size, colors, parent_node)

func _kind_to_color(kind: int) -> Color:
	if board != null and board.piece_types.size() > kind and kind >= 0:
		return board.piece_types[kind].color
	match kind:
		PieceType.Kind.SWORD: return Color(0.95, 0.78, 0.30)
		PieceType.Kind.SHIELD: return Color(0.40, 0.62, 0.95)
		PieceType.Kind.STAFF: return Color(0.66, 0.36, 0.85)
		PieceType.Kind.BOW: return Color(0.40, 0.82, 0.50)
	return Color.WHITE

func _detect_shield_combo_level(emblems: Array) -> int:
	var counts := {1: 0, 2: 0, 3: 0}
	for e_v in emblems:
		var e: Emblem = e_v
		if e.piece_kind == PieceType.Kind.SHIELD and counts.has(e.level):
			counts[e.level] += 1
	for lvl in [3, 2, 1]:
		if counts[lvl] >= 3:
			return lvl
	return 0

func _await_shield_choice(combo_level: int) -> int:
	_pending_shield_choice = -1
	emit_signal("shield_choice_required", combo_level)
	while _pending_shield_choice < 0:
		await get_tree().process_frame
		if state == State.ENDED:
			return AbilityResolver.SHIELD_CHOICE_ARMOR
	return _pending_shield_choice

func provide_shield_choice(choice: int) -> void:
	_pending_shield_choice = choice

func _apply_player_round_result(result: Dictionary) -> void:
	# Player as caster; enemy as target.
	var damage: int = int(result.get("damage", 0))
	var bypass: int = int(result.get("bypass", 0))
	var pierce: int = int(result.get("pierce", 0))
	var heal: int = int(result.get("heal", 0))
	var armor: int = int(result.get("armor", 0))
	if armor > 0:
		player.add_armor(armor)
	if heal > 0:
		var healed: int = player.heal(heal)
		emit_signal("heal_done", true, healed)
	if pierce > 0 or damage > 0:
		var dealt: int = enemy.take_damage(damage, bypass > 0, pierce)
		if dealt > 0:
			AudioBus.play_hit()
			emit_signal("damage_dealt", false, dealt, -1)
	for fx_v in result.get("enemy_effects", []):
		var fx: StatusEffect = fx_v
		enemy.apply_effect(fx)
		emit_signal("status_applied", false, fx)
	for fx_v in result.get("player_effects", []):
		var fx: StatusEffect = fx_v
		player.apply_effect(fx)
		emit_signal("status_applied", true, fx)
	await get_tree().create_timer(0.25).timeout

func _recheck_player_input() -> void:
	if state == State.ENDED:
		return
	state = State.PLAYER_INPUT
	board.set_input_locked(false)
	emit_signal("turn_changed", true)
	if board.state == Board.State.IDLE:
		board.shuffle_board_if_dead()

# --- Enemy independent action-scale loop ---

func _on_enemy_tick() -> void:
	if state == State.ENDED:
		return
	# Stunned enemy doesn't accumulate emblems; the stun still ticks down each
	# player round, so it self-clears.
	if enemy.is_stunned():
		return
	# Don't accumulate further while an enemy resolve is already in flight.
	if _enemy_round_in_flight:
		return
	if enemy_action_scale.size() >= SCALE_CAPACITY:
		return
	var e: Emblem = _generate_enemy_emblem()
	enemy_action_scale.append(e)
	emit_signal("enemy_emblem_added", e, enemy_action_scale.size())
	if enemy_action_scale.size() >= SCALE_CAPACITY:
		_execute_enemy_round()

func _execute_enemy_round() -> void:
	_enemy_round_in_flight = true
	# Wait for any in-flight player round to finish so effects don't interleave.
	while _player_round_in_flight and state != State.ENDED:
		await get_tree().process_frame
	if state == State.ENDED:
		_enemy_round_in_flight = false
		return
	if enemy.is_stunned():
		emit_signal("enemy_stunned_skipped")
		enemy_action_scale.clear()
		emit_signal("enemy_round_finished")
		_enemy_round_in_flight = false
		return
	emit_signal("enemy_round_executing", enemy_action_scale.duplicate())
	AudioBus.play_round_execute()
	# Enemy never gets the player's stun-or-armor choice; default to armor.
	var result: Dictionary = AbilityResolver.resolve_round(board.piece_types, enemy_action_scale, AbilityResolver.SHIELD_CHOICE_ARMOR)
	await _apply_enemy_round_result(result)
	if state == State.ENDED:
		_enemy_round_in_flight = false
		return
	_enemy_round_count += 1
	enemy_action_scale.clear()
	emit_signal("enemy_round_finished")
	_enemy_round_in_flight = false

func _apply_enemy_round_result(result: Dictionary) -> void:
	# Mirror of _apply_player_round_result with caster=enemy, target=player.
	var damage: int = int(result.get("damage", 0))
	var bypass: int = int(result.get("bypass", 0))
	var pierce: int = int(result.get("pierce", 0))
	var heal: int = int(result.get("heal", 0))
	var armor: int = int(result.get("armor", 0))
	# Boss enrage: at low HP the enemy hits harder. Preserved from the old model.
	if level != null and level.boss_modifier != null:
		var hp_frac: float = float(enemy.current_hp) / float(max(1, enemy.max_hp))
		if hp_frac <= level.boss_modifier.enrage_threshold:
			damage = int(damage * level.boss_modifier.enrage_multiplier)
	if armor > 0:
		enemy.add_armor(armor)
	if heal > 0:
		var healed: int = enemy.heal(heal)
		emit_signal("heal_done", false, healed)
	if pierce > 0 or damage > 0:
		var dealt: int = player.take_damage(damage, bypass > 0, pierce)
		if dealt > 0:
			AudioBus.play_hit()
			emit_signal("damage_dealt", true, dealt, -1)
		enemy.attacked.emit()
	# Resolver's "enemy_effects" are effects on the target — when the enemy is
	# the caster, those apply to the player. Likewise "player_effects" land on
	# the enemy.
	for fx_v in result.get("enemy_effects", []):
		var fx: StatusEffect = fx_v
		player.apply_effect(fx)
		emit_signal("status_applied", true, fx)
	for fx_v in result.get("player_effects", []):
		var fx: StatusEffect = fx_v
		enemy.apply_effect(fx)
		emit_signal("status_applied", false, fx)
	await get_tree().create_timer(0.25).timeout

# Build a random 5x5 board, find any matches, and emit one as the enemy's emblem.
# The smaller board makes 4+/5+ runs naturally rare, which throttles enemy combo
# strength compared to the hero's 9x9.
func _generate_enemy_emblem() -> Emblem:
	for attempt in range(6):
		var grid: Array = _make_random_sim_grid()
		var matches: Array = MatchDetector.find_matches(grid, 3)
		if matches.is_empty():
			continue
		var picked: Dictionary = matches[_enemy_rng.randi() % matches.size()]
		var k: int = int(picked["kind"])
		var longest: int = MatchDetector.longest_axis_run_in(picked["cells"], grid)
		var lvl: int = PieceType.level_from_match(longest)
		return Emblem.new(k, lvl)
	# Fallback: occasional dry tick — emit a low-level random emblem so the
	# enemy still progresses.
	var fallback_kind: int = _enemy_rng.randi() % PieceType.SPAWNABLE_KIND_COUNT
	return Emblem.new(fallback_kind, 1)

func _make_random_sim_grid() -> Array:
	var grid: Array = []
	for y in range(ENEMY_SIM_BOARD_SIZE):
		var row: Array = []
		for x in range(ENEMY_SIM_BOARD_SIZE):
			row.append(_enemy_rng.randi() % PieceType.SPAWNABLE_KIND_COUNT)
		grid.append(row)
	return grid

func _on_player_died(_a: CombatActor) -> void:
	if state == State.ENDED:
		return
	state = State.ENDED
	if _enemy_tick_timer != null:
		_enemy_tick_timer.stop()
	emit_signal("battle_lost")

func _on_enemy_died(_a: CombatActor) -> void:
	if state == State.ENDED:
		return
	state = State.ENDED
	if _enemy_tick_timer != null:
		_enemy_tick_timer.stop()
	emit_signal("battle_won")
