class_name CombatController
extends Node

# Round-based combat:
#   1. Player matches accumulate Emblems on an action scale (capacity 5).
#   2. When the scale fills, the round executes:
#      - emblems resolve through AbilityResolver
#      - shield 3-combo prompts the player to pick STUN or ARMOR
#      - effects apply (damage, heal, armor, status effects)
#      - existing DoTs/stuns tick on both actors
#      - enemy attacks once (skipped while stunned)
#   3. Scale resets. Any cascaded matches beyond the 5th emblem queue for next round.

signal turn_changed(is_player_turn: bool)
signal damage_dealt(target_is_player: bool, amount: int, source_kind: int)
signal heal_done(target_is_player: bool, amount: int)
signal status_applied(target_is_player: bool, effect: StatusEffect)
signal emblem_added(emblem: Emblem, scale_size: int)
signal round_executing(emblems: Array)
signal round_finished
signal shield_choice_required(combo_level: int)
signal battle_won
signal battle_lost
signal enemy_special_attack
signal enemy_stunned_skipped

enum State { PLAYER_INPUT, RESOLVING, ENEMY_TURN, ENDED }

const SCALE_CAPACITY: int = 5

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
var _pending_shield_choice: int = -1

func _ready() -> void:
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
	# Bad swap doesn't fill the scale; doesn't end the round either (player
	# explicitly needs 5 matches to act). They lose a swap attempt but no turn
	# penalty in the new model.
	pass

# --- Round execution ---

func _execute_round() -> void:
	state = State.RESOLVING
	board.set_input_locked(true)
	emit_signal("turn_changed", false)
	emit_signal("round_executing", action_scale.duplicate())
	var shield_choice: int = AbilityResolver.SHIELD_CHOICE_ARMOR
	var shield_combo_level: int = _detect_shield_combo_level()
	if shield_combo_level > 0:
		shield_choice = await _await_shield_choice(shield_combo_level)
	var result: Dictionary = AbilityResolver.resolve_round(board.piece_types, action_scale, shield_choice)
	# Apply pierce + damage + heal + armor + status effects.
	await _apply_round_result(result)
	if state == State.ENDED:
		return
	# Enemy attack (skipped if stunned). Stun is checked BEFORE ticking so the
	# duration counts as the number of rounds the enemy actually loses.
	var enemy_was_stunned: bool = enemy.is_stunned()
	if enemy_was_stunned:
		emit_signal("enemy_stunned_skipped")
	else:
		state = State.ENEMY_TURN
		emit_signal("turn_changed", false)
		await get_tree().create_timer(0.45).timeout
		if state == State.ENDED:
			return
		_do_enemy_attack()
		await get_tree().create_timer(0.45).timeout
	# Tick DoTs and decrement effect durations now that the round resolved.
	# DoTs apply their damage and stun/debuff counters advance.
	var enemy_dot: int = enemy.tick_effects()
	if enemy_dot > 0:
		emit_signal("damage_dealt", false, enemy_dot, -1)
	var player_dot: int = player.tick_effects()
	if player_dot > 0:
		emit_signal("damage_dealt", true, player_dot, -1)
	if state == State.ENDED:
		return
	# Reset scale, accept any overflow emblems collected mid-round.
	action_scale = _overflow_emblems
	_overflow_emblems = []
	_player_round_count += 1
	emit_signal("round_finished")
	_recheck_player_input()

func _detect_shield_combo_level() -> int:
	var counts := {1: 0, 2: 0, 3: 0}
	for e_v in action_scale:
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

func _apply_round_result(result: Dictionary) -> void:
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

func _do_enemy_attack() -> void:
	var dmg: int = enemy.base_damage
	if level != null and level.boss_modifier != null:
		var hp_frac: float = float(enemy.current_hp) / float(max(1, enemy.max_hp))
		if hp_frac <= level.boss_modifier.enrage_threshold:
			dmg = int(dmg * level.boss_modifier.enrage_multiplier)
		var n: int = level.boss_modifier.special_attack_every_n_turns
		if n > 0 and (_player_round_count + 1) % n == 0:
			dmg += level.boss_modifier.special_attack_damage
			emit_signal("enemy_special_attack")
	var dealt: int = player.take_damage(dmg, false)
	emit_signal("damage_dealt", true, dealt, -1)
	enemy.attacked.emit()

func _recheck_player_input() -> void:
	if state == State.ENDED:
		return
	state = State.PLAYER_INPUT
	board.set_input_locked(false)
	emit_signal("turn_changed", true)
	if board.state == Board.State.IDLE:
		board.shuffle_board_if_dead()

func _on_player_died(_a: CombatActor) -> void:
	if state == State.ENDED:
		return
	state = State.ENDED
	emit_signal("battle_lost")

func _on_enemy_died(_a: CombatActor) -> void:
	if state == State.ENDED:
		return
	state = State.ENDED
	emit_signal("battle_won")
