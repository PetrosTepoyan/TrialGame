extends Control

@onready var _board: Board = $BoardArea/Board
@onready var _input_handler: BoardInputHandler = $BoardArea/InputHandler
@onready var _player_hp: HpBar = $TopBar/PlayerHp
@onready var _enemy_hp: HpBar = $TopBar/EnemyHp
@onready var _player_actor: CombatActor = $Actors/PlayerActor
@onready var _enemy_actor: CombatActor = $Actors/EnemyActor
@onready var _player_battle_actor: BattleActor = $BattleScene/PlayerBattle
@onready var _enemy_battle_actor: BattleActor = $BattleScene/EnemyBattle
@onready var _combat: CombatController = $Combat
@onready var _bg: ColorRect = $Background
@onready var _level_label: Label = $TopBar/LevelLabel
@onready var _turn_label: Label = $TopBar/TurnLabel
@onready var _rally_label: Label = $BottomBar/RallyLabel
@onready var _rally_button: Button = $BottomBar/RallyButton
@onready var _pause_button: Button = $TopBar/PauseButton
@onready var _floating_text_root: Node2D = $FloatingTextRoot

const FLOAT_FONT_SIZE: int = 36

func _ready() -> void:
	var level: LevelResource = GameState.get_current_level()
	_bg.color = level.background_color
	_level_label.text = level.level_name
	_player_hp.actor_name = "Hero"
	_enemy_hp.actor_name = level.enemy_name
	_player_hp.flip_fill_direction = false
	_enemy_hp.flip_fill_direction = true
	_combat.turn_changed.connect(_on_turn_changed)
	_combat.damage_dealt.connect(_on_damage_dealt)
	_combat.heal_done.connect(_on_heal_done)
	_combat.rally_changed.connect(_on_rally_changed)
	_combat.battle_won.connect(_on_battle_won)
	_combat.battle_lost.connect(_on_battle_lost)
	_combat.enemy_special.connect(_on_enemy_special)
	_rally_button.pressed.connect(_on_rally_pressed)
	_pause_button.pressed.connect(_on_pause)
	_rally_button.disabled = true
	# Wait one frame so Control anchors have produced final sizes before
	# we sync the HP bar fills.
	await get_tree().process_frame
	_player_hp.bind(_player_actor)
	_enemy_hp.bind(_enemy_actor)
	_layout_board()

func _layout_board() -> void:
	# Center board horizontally, anchor bottom with margin for safe area.
	var board_size: Vector2 = _board.board_total_size()
	var area_size: Vector2 = $BoardArea.size
	_board.position = Vector2((area_size.x - board_size.x) * 0.5, (area_size.y - board_size.y) * 0.5)

func _on_turn_changed(is_player_turn: bool) -> void:
	_turn_label.text = "Your turn" if is_player_turn else "%s acts" % _combat.level.enemy_name
	if is_player_turn:
		_player_battle_actor.modulate = Color(1, 1, 1, 1)
		_enemy_battle_actor.modulate = Color(0.7, 0.7, 0.8, 1)
	else:
		_player_battle_actor.modulate = Color(0.7, 0.7, 0.8, 1)
		_enemy_battle_actor.modulate = Color(1, 1, 1, 1)

func _on_damage_dealt(target_is_player: bool, amount: int, kind: int) -> void:
	var attacker_battle: BattleActor = _enemy_battle_actor if target_is_player else _player_battle_actor
	var target_battle: BattleActor = _player_battle_actor if target_is_player else _enemy_battle_actor
	attacker_battle.attack()
	await get_tree().create_timer(0.10).timeout
	target_battle.hurt()
	_spawn_float_text(target_battle.global_position + Vector2(0, -80), "-%d" % amount, Color(1, 0.4, 0.4))

func _on_heal_done(_target_is_player: bool, amount: int) -> void:
	_spawn_float_text(_player_battle_actor.global_position + Vector2(0, -80), "+%d" % amount, Color(0.5, 1, 0.5))

func _on_rally_changed(value: int) -> void:
	_rally_label.text = "Rally %d / %d" % [value, CombatController.RALLY_MAX]
	_rally_button.disabled = value < CombatController.RALLY_MAX

func _on_rally_pressed() -> void:
	_combat.spend_rally()

func _on_battle_won() -> void:
	await get_tree().create_timer(0.6).timeout
	_enemy_battle_actor.die()
	await get_tree().create_timer(0.7).timeout
	# Record completion.
	if GameState.is_current_level_king():
		GameState.advance_to_next_castle()
		SceneRouter.goto_victory()
	else:
		GameState.mark_level_completed(GameState.castle_index, GameState.chapter_index, GameState.level_index)
		SceneRouter.goto_chapter_map()

func _on_battle_lost() -> void:
	await get_tree().create_timer(0.6).timeout
	_player_battle_actor.die()
	await get_tree().create_timer(0.7).timeout
	SceneRouter.goto_game_over()

func _on_enemy_special() -> void:
	_spawn_float_text(_enemy_battle_actor.global_position + Vector2(0, -110), "SPECIAL!", Color(1, 0.7, 0.2))

func _on_pause() -> void:
	SceneRouter.goto_chapter_map()

func _spawn_float_text(at: Vector2, text: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", FLOAT_FONT_SIZE)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.position = at
	_floating_text_root.add_child(lbl)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(lbl, "position", at + Vector2(0, -60), 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.8)
	tween.chain().tween_callback(lbl.queue_free)
