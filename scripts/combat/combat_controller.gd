class_name CombatController
extends Node

signal turn_changed(is_player_turn: bool)
signal damage_dealt(target_is_player: bool, amount: int, kind: int)
signal heal_done(target_is_player: bool, amount: int)
signal rally_changed(rally_meter: int)
signal battle_won
signal battle_lost
signal enemy_special

enum State { PLAYER_INPUT, RESOLVING, ENEMY_TURN, ENDED }

@export var board_path: NodePath
@export var player_actor_path: NodePath
@export var enemy_actor_path: NodePath
@export var level: LevelResource

@onready var board: Board = get_node(board_path)
@onready var player: CombatActor = get_node(player_actor_path)
@onready var enemy: CombatActor = get_node(enemy_actor_path)

var state: int = State.PLAYER_INPUT
var rally_meter: int = 0
const RALLY_MAX: int = 100
var _extra_turn: bool = false
var _accumulated: Dictionary = {"damage": 0, "bypass": 0, "heal": 0, "armor": 0, "kind": -1}
var _player_turn_count: int = 0
var _pending_clear_kind: int = -1

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

func _on_match_resolved(kind: int, count: int, longest_run: int) -> void:
	var effect: Dictionary = AbilityResolver.resolve_match(board.piece_types, kind, count, longest_run)
	_accumulated["kind"] = kind
	if int(effect.get("damage", 0)) > 0:
		_accumulated["damage"] = int(_accumulated["damage"]) + int(effect["damage"])
		if bool(effect.get("bypass_armor", false)):
			_accumulated["bypass"] = int(_accumulated["bypass"]) + int(effect["damage"])
	if int(effect.get("heal", 0)) > 0:
		_accumulated["heal"] = int(_accumulated["heal"]) + int(effect["heal"])
	if int(effect.get("armor", 0)) > 0:
		_accumulated["armor"] = int(_accumulated["armor"]) + int(effect["armor"])
	if int(effect.get("rally", 0)) > 0:
		rally_meter = min(RALLY_MAX, rally_meter + int(effect["rally"]))
		emit_signal("rally_changed", rally_meter)
	if bool(effect.get("extra_turn", false)):
		_extra_turn = true
	if int(effect.get("clear_kind", -1)) >= 0:
		# Defer clear_kind until current cascade fully resolves to avoid mid-cascade interference.
		_pending_clear_kind = int(effect["clear_kind"])

func _on_cascade_finished(total_matches: int, _depth: int) -> void:
	# Apply accumulated effects to actors.
	if int(_accumulated["damage"]) > 0:
		var armor_bypass: int = int(_accumulated["bypass"])
		var regular: int = int(_accumulated["damage"]) - armor_bypass
		if regular > 0:
			var dealt: int = enemy.take_damage(regular, false)
			emit_signal("damage_dealt", false, dealt, int(_accumulated["kind"]))
		if armor_bypass > 0:
			var dealt2: int = enemy.take_damage(armor_bypass, true)
			emit_signal("damage_dealt", false, dealt2, PieceType.Kind.ARCHER)
	if int(_accumulated["heal"]) > 0:
		var healed: int = player.heal(int(_accumulated["heal"]))
		emit_signal("heal_done", true, healed)
	if int(_accumulated["armor"]) > 0:
		player.add_armor(int(_accumulated["armor"]))
	_accumulated = {"damage": 0, "bypass": 0, "heal": 0, "armor": 0, "kind": -1}
	if state == State.ENDED:
		return
	# Match-5 follow-up: clear all of that kind, then re-resolve.
	if _pending_clear_kind >= 0:
		var to_clear: int = _pending_clear_kind
		_pending_clear_kind = -1
		await board.clear_kind(to_clear)
		board.resolve_externally()
		return  # Wait for next cascade_finished
	# Decide next turn
	if total_matches == 0:
		# No matches at all in this cascade — treat as if the player wasted their move
		_advance_to_enemy_turn()
		return
	if _extra_turn:
		_extra_turn = false
		state = State.PLAYER_INPUT
		emit_signal("turn_changed", true)
		_check_no_moves()
		return
	_advance_to_enemy_turn()

func _on_invalid_swap() -> void:
	# Swap reverted (no match) — enemy still gets a turn.
	_advance_to_enemy_turn()

func _advance_to_enemy_turn() -> void:
	if state == State.ENDED:
		return
	state = State.ENEMY_TURN
	board.set_input_locked(true)
	emit_signal("turn_changed", false)
	_player_turn_count += 1
	# Brief delay so the player sees the transition.
	await get_tree().create_timer(0.5).timeout
	if state == State.ENDED:
		return
	_do_enemy_attack()

func _do_enemy_attack() -> void:
	var dmg: int = enemy.base_damage
	# Boss enrage check.
	if level != null and level.boss_modifier != null:
		var hp_frac: float = float(enemy.current_hp) / float(max(1, enemy.max_hp))
		if hp_frac <= level.boss_modifier.enrage_threshold:
			dmg = int(dmg * level.boss_modifier.enrage_multiplier)
		# Periodic special attack.
		var n: int = level.boss_modifier.special_attack_every_n_turns
		if n > 0 and _player_turn_count % n == 0:
			dmg += level.boss_modifier.special_attack_damage
			emit_signal("enemy_special")
	var dealt: int = player.take_damage(dmg, false)
	emit_signal("damage_dealt", true, dealt, -1)
	enemy.attacked.emit()
	# Pause then return to player.
	await get_tree().create_timer(0.6).timeout
	if state == State.ENDED:
		return
	state = State.PLAYER_INPUT
	board.set_input_locked(false)
	emit_signal("turn_changed", true)
	_check_no_moves()

func _check_no_moves() -> void:
	# Trigger shuffle if dead board.
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

# Player can spend rally meter for a special move (e.g. clear a random row).
func spend_rally() -> bool:
	if rally_meter < RALLY_MAX:
		return false
	rally_meter = 0
	emit_signal("rally_changed", rally_meter)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var row: int = rng.randi() % Board.ROWS
	board.clear_row(row)
	board.resolve_externally()
	return true
