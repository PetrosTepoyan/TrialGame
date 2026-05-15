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
@onready var _bg_image: TextureRect = $BackgroundImage
@onready var _level_label: Label = $TopBar/LevelLabel
@onready var _turn_label: Label = $TopBar/TurnLabel
@onready var _pause_button: Button = $TopBar/PauseButton
@onready var _exit_button: Button = $TopBar/ExitButton
@onready var _floating_text_root: Node2D = $FloatingTextRoot
@onready var _action_scale: ActionScale = $ActionScaleBar/PlayerActionScale
@onready var _enemy_action_scale: ActionScale = $ActionScaleBar/EnemyActionScale
@onready var _shield_popup: PanelContainer = $ShieldChoicePopup
@onready var _shield_armor_btn: Button = $ShieldChoicePopup/VBox/Buttons/ArmorBtn
@onready var _shield_stun_btn: Button = $ShieldChoicePopup/VBox/Buttons/StunBtn
@onready var _shield_subtitle: Label = $ShieldChoicePopup/VBox/Subtitle
@onready var _tutorial: TutorialOverlay = $TutorialOverlay
@onready var _settings_panel: SettingsPanel = $SettingsPanel

# Track turns and starting HP so we can grant 1-3 stars on victory.
var _rounds_taken: int = 0

const FLOAT_FONT_SIZE_SMALL: int = 32
const FLOAT_FONT_SIZE_BIG: int = 56

var _shake_base: Vector2 = Vector2.ZERO

func _ready() -> void:
	SafeArea.apply(self)
	var level: LevelResource = GameState.get_current_level()
	_bg.color = level.background_color
	if level.background_path != "" and ResourceLoader.exists(level.background_path):
		_bg_image.texture = load(level.background_path)
		_bg_image.visible = true
	else:
		_bg_image.visible = false
	_level_label.text = level.level_name
	_player_hp.actor_name = "Hero"
	_enemy_hp.actor_name = level.enemy_name
	_player_hp.flip_fill_direction = false
	_enemy_hp.flip_fill_direction = true
	# If the level specifies a custom enemy sprite (boss / king), apply it.
	if level.enemy_sprite_path != "":
		_enemy_battle_actor.override_sprite(level.enemy_sprite_path)
	# Music: stream the battle track.
	AudioBus.play_music(AudioBus.load_music("res://assets/audio/music/battle.mp3"))
	_combat.turn_changed.connect(_on_turn_changed)
	_combat.damage_dealt.connect(_on_damage_dealt)
	_combat.heal_done.connect(_on_heal_done)
	_combat.status_applied.connect(_on_status_applied)
	_combat.emblem_added.connect(_on_emblem_added)
	_combat.round_executing.connect(_on_round_executing)
	_combat.round_finished.connect(_on_round_finished)
	_combat.enemy_emblem_added.connect(_on_enemy_emblem_added)
	_combat.enemy_round_executing.connect(_on_enemy_round_executing)
	_combat.enemy_round_finished.connect(_on_enemy_round_finished)
	_combat.shield_choice_required.connect(_on_shield_choice_required)
	_combat.battle_won.connect(_on_battle_won)
	_combat.battle_lost.connect(_on_battle_lost)
	_combat.enemy_stunned_skipped.connect(_on_enemy_stunned)
	_combat.round_finished.connect(_on_round_finished_count)
	_pause_button.pressed.connect(_on_pause)
	_exit_button.pressed.connect(_on_exit_pressed)
	_shield_armor_btn.pressed.connect(_on_shield_armor_chosen)
	_shield_stun_btn.pressed.connect(_on_shield_stun_chosen)
	_shield_popup.visible = false
	_tutorial.show_once()
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
	# Both actors stay active in real-time combat — the label just flips when
	# the hero's scale is being resolved so the player knows input is paused.
	if is_player_turn:
		_turn_label.text = "Collect 5 emblems"
	else:
		_turn_label.text = "Resolving..."

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

func _on_enemy_emblem_added(emblem: Emblem, scale_size: int) -> void:
	_enemy_action_scale.fill_slot(scale_size - 1, emblem)

func _on_enemy_round_executing(_emblems: Array) -> void:
	_enemy_action_scale.play_execute_animation()

func _on_enemy_round_finished() -> void:
	_enemy_action_scale.clear_all()

func _on_damage_dealt(target_is_player: bool, amount: int, _source_kind: int) -> void:
	var attacker_battle: BattleActor = _enemy_battle_actor if target_is_player else _player_battle_actor
	var target_battle: BattleActor = _player_battle_actor if target_is_player else _enemy_battle_actor
	attacker_battle.attack()
	await get_tree().create_timer(0.10).timeout
	target_battle.hurt()
	_spawn_float_text(target_battle.global_position + Vector2(0, -90), "-%d" % amount, Color(1, 0.4, 0.4), amount)
	_screen_shake(min(0.6, amount * 0.04), 0.30)

func _on_heal_done(_target_is_player: bool, amount: int) -> void:
	_spawn_float_text(_player_battle_actor.global_position + Vector2(0, -80), "+%d" % amount, Color(0.5, 1, 0.5), amount)

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
	_spawn_float_text(anchor.global_position + Vector2(0, -130), label, color, 0)

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
		var stars: int = _award_stars()
		GameState.mark_level_completed(GameState.castle_index, GameState.chapter_index, GameState.level_index)
		GameState.mark_level_stars(GameState.castle_index, GameState.chapter_index, GameState.level_index, stars)
		SceneRouter.goto_chapter_map()

func _on_battle_lost() -> void:
	await get_tree().create_timer(0.6).timeout
	_player_battle_actor.die()
	await get_tree().create_timer(0.7).timeout
	SceneRouter.goto_game_over()

func _on_enemy_stunned() -> void:
	_spawn_float_text(_enemy_battle_actor.global_position + Vector2(0, -120), "STUNNED!", Color(1, 0.92, 0.30), 99)

func _on_pause() -> void:
	_settings_panel.visible = not _settings_panel.visible

func _on_exit_pressed() -> void:
	SceneRouter.goto_chapter_map()

func _on_round_finished_count() -> void:
	_rounds_taken += 1

func _award_stars() -> int:
	# 3 stars if HP > 70% and <= 5 rounds; 2 stars if HP > 35% or <= 8 rounds; else 1 star.
	var hp_pct: float = float(_player_actor.current_hp) / float(max(1, _player_actor.max_hp))
	if hp_pct > 0.70 and _rounds_taken <= 5:
		return 3
	if hp_pct > 0.35 or _rounds_taken <= 8:
		return 2
	return 1

func _spawn_float_text(at: Vector2, text: String, color: Color, magnitude: int) -> void:
	# Big hits get larger, more dramatic text; small hits / status notices stay subtle.
	var font_size: int = FLOAT_FONT_SIZE_BIG if magnitude >= 25 else FLOAT_FONT_SIZE_SMALL
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 5)
	lbl.position = at
	lbl.pivot_offset = Vector2(40, 20)
	lbl.scale = Vector2(0.2, 0.2)
	_floating_text_root.add_child(lbl)
	# Punch-in scale, then float up + fade.
	var pop := create_tween()
	pop.tween_property(lbl, "scale", Vector2(1.15, 1.15), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.08)
	var drift := create_tween()
	drift.set_parallel(true)
	drift.tween_property(lbl, "position", at + Vector2(0, -90), 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	drift.tween_property(lbl, "modulate:a", 0.0, 0.9)
	drift.chain().tween_callback(lbl.queue_free)

func _screen_shake(intensity: float, duration: float) -> void:
	# Shake the Battle root by jittering its position briefly.
	if _shake_base == Vector2.ZERO:
		_shake_base = position
	var t := create_tween()
	var steps: int = int(duration / 0.04)
	for i in range(steps):
		var f: float = 1.0 - float(i) / float(steps)
		t.tween_property(self, "position", _shake_base + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * intensity * 12 * f, 0.04)
	t.tween_property(self, "position", _shake_base, 0.05)
