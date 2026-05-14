extends Control

@onready var _board: Board = $BoardArea/Board
@onready var _input_handler: BoardInputHandler = $BoardArea/InputHandler
@onready var _player_hp: HpBar = $TopBar/PlayerHp
@onready var _enemy_hp: HpBar = $TopBar/EnemyHp
@onready var _player_status: StatusStrip = $TopBar/PlayerStatus
@onready var _enemy_status: StatusStrip = $TopBar/EnemyStatus
@onready var _player_actor: CombatActor = $Actors/PlayerActor
@onready var _enemy_actor: CombatActor = $Actors/EnemyActor
@onready var _player_battle_actor: BattleActor = $BattleScene/PlayerBattle
@onready var _enemy_battle_actor: BattleActor = $BattleScene/EnemyBattle
@onready var _combat: CombatController = $Combat
@onready var _bg: ColorRect = $Background
@onready var _level_label: Label = $TopBar/LevelLabel
@onready var _turn_label: Label = $TopBar/TurnLabel
@onready var _pause_button: Button = $TopBar/PauseButton
@onready var _floating_text_root: Node2D = $FloatingTextRoot
@onready var _action_scale: ActionScale = $ActionScaleBar/ActionScale
@onready var _shield_popup: PanelContainer = $ShieldChoicePopup
@onready var _shield_armor_btn: Button = $ShieldChoicePopup/VBox/Buttons/ArmorBtn
@onready var _shield_stun_btn: Button = $ShieldChoicePopup/VBox/Buttons/StunBtn
@onready var _shield_subtitle: Label = $ShieldChoicePopup/VBox/Subtitle

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
	_combat.status_applied.connect(_on_status_applied)
	_combat.emblem_added.connect(_on_emblem_added)
	_combat.round_executing.connect(_on_round_executing)
	_combat.round_finished.connect(_on_round_finished)
	_combat.shield_choice_required.connect(_on_shield_choice_required)
	_combat.battle_won.connect(_on_battle_won)
	_combat.battle_lost.connect(_on_battle_lost)
	_combat.enemy_special_attack.connect(_on_enemy_special_attack)
	_combat.enemy_stunned_skipped.connect(_on_enemy_stunned)
	_pause_button.pressed.connect(_on_pause)
	_shield_armor_btn.pressed.connect(_on_shield_armor_chosen)
	_shield_stun_btn.pressed.connect(_on_shield_stun_chosen)
	_shield_popup.visible = false
	# Defer one frame so Control anchors have produced final sizes before HP bars sync.
	await get_tree().process_frame
	_player_hp.bind(_player_actor)
	_enemy_hp.bind(_enemy_actor)
	_player_status.bind(_player_actor)
	_enemy_status.bind(_enemy_actor)
	_layout_board()

func _layout_board() -> void:
	var board_size: Vector2 = _board.board_total_size()
	var area_size: Vector2 = $BoardArea.size
	_board.position = Vector2((area_size.x - board_size.x) * 0.5, (area_size.y - board_size.y) * 0.5)

func _on_turn_changed(is_player_turn: bool) -> void:
	if is_player_turn:
		_turn_label.text = "Your turn — collect 5 emblems"
		_player_battle_actor.modulate = Color(1, 1, 1, 1)
		_enemy_battle_actor.modulate = Color(0.7, 0.7, 0.8, 1)
	else:
		_turn_label.text = "%s acts" % _combat.level.enemy_name
		_player_battle_actor.modulate = Color(0.7, 0.7, 0.8, 1)
		_enemy_battle_actor.modulate = Color(1, 1, 1, 1)

func _on_emblem_added(emblem: Emblem, scale_size: int) -> void:
	_action_scale.fill_slot(scale_size - 1, emblem)

func _on_round_executing(_emblems: Array) -> void:
	_action_scale.play_execute_animation()
	_turn_label.text = "Resolving..."

func _on_round_finished() -> void:
	_action_scale.clear_all()
	# Repopulate any overflow emblems that carried into the new round.
	for i in range(_combat.action_scale.size()):
		_action_scale.fill_slot(i, _combat.action_scale[i])

func _on_damage_dealt(target_is_player: bool, amount: int, _source_kind: int) -> void:
	var attacker_battle: BattleActor = _enemy_battle_actor if target_is_player else _player_battle_actor
	var target_battle: BattleActor = _player_battle_actor if target_is_player else _enemy_battle_actor
	attacker_battle.attack()
	await get_tree().create_timer(0.10).timeout
	target_battle.hurt()
	_spawn_float_text(target_battle.global_position + Vector2(0, -80), "-%d" % amount, Color(1, 0.4, 0.4))

func _on_heal_done(_target_is_player: bool, amount: int) -> void:
	_spawn_float_text(_player_battle_actor.global_position + Vector2(0, -80), "+%d" % amount, Color(0.5, 1, 0.5))

func _on_status_applied(target_is_player: bool, fx: StatusEffect) -> void:
	var anchor: BattleActor = _player_battle_actor if target_is_player else _enemy_battle_actor
	var label := "%s %d" % [StatusEffect.kind_to_string(fx.kind), fx.rounds_remaining]
	var color := Color(1.0, 0.78, 0.30)
	match fx.kind:
		StatusEffect.Kind.BURN: color = Color(1.0, 0.50, 0.20)
		StatusEffect.Kind.SWARM: color = Color(0.55, 0.85, 0.40)
		StatusEffect.Kind.COLD: color = Color(0.55, 0.80, 1.00)
		StatusEffect.Kind.BLEED: color = Color(0.95, 0.30, 0.40)
		StatusEffect.Kind.STUN: color = Color(1.00, 0.92, 0.40)
		StatusEffect.Kind.DEFENSE_DEBUFF: color = Color(0.85, 0.55, 1.00)
	_spawn_float_text(anchor.global_position + Vector2(0, -130), label, color)

func _on_shield_choice_required(combo_level: int) -> void:
	_shield_subtitle.text = "Combo Level %d — pick a path" % combo_level
	_shield_popup.visible = true

func _on_shield_armor_chosen() -> void:
	_shield_popup.visible = false
	_combat.provide_shield_choice(AbilityResolver.SHIELD_CHOICE_ARMOR)

func _on_shield_stun_chosen() -> void:
	_shield_popup.visible = false
	_combat.provide_shield_choice(AbilityResolver.SHIELD_CHOICE_STUN)

func _on_battle_won() -> void:
	await get_tree().create_timer(0.6).timeout
	_enemy_battle_actor.die()
	await get_tree().create_timer(0.7).timeout
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

func _on_enemy_special_attack() -> void:
	_spawn_float_text(_enemy_battle_actor.global_position + Vector2(0, -120), "SPECIAL!", Color(1, 0.7, 0.2))

func _on_enemy_stunned() -> void:
	_spawn_float_text(_enemy_battle_actor.global_position + Vector2(0, -120), "STUNNED!", Color(1, 0.92, 0.30))

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
