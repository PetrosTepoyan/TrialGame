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
@onready var _mana_bar: ManaBar = $ManaPanel/ManaBar
@onready var _spec_button: SpecialAttackButton = $ManaPanel/SpecialAttackButton
@onready var _battle_scene: Node2D = $BattleScene
@onready var _board_area: Control = $BoardArea
@onready var _tutorial: TutorialOverlay = $TutorialOverlay
@onready var _settings_panel: SettingsPanel = $SettingsPanel

# Track elapsed battle time so we can award stars (Phase E balance).
var _battle_seconds: float = 0.0

const FLOAT_FONT_SIZE_SMALL: int = 32
const FLOAT_FONT_SIZE_BIG: int = 56

# --- Screen-shake (trauma model). Trauma decays each frame; per-frame offset
#     uses FastNoiseLite for smooth, organic motion. trauma^2 mapping makes
#     small shakes feel subtle while big shakes punch hard.
const SHAKE_DECAY: float = 0.92          # multiplier applied per frame at 60fps
const SHAKE_MAX_OFFSET_PX: float = 26.0  # max screen offset at trauma=1.0
const SHAKE_MAX_ROT_DEG: float = 1.5     # max rotation at trauma=1.0
const SHAKE_NOISE_SPEED: float = 60.0    # how fast the noise lookup advances
const SHAKE_BG_PARALLAX: float = 0.35    # background drifts less than foreground

var _shake_base: Vector2 = Vector2.ZERO
var _shake_trauma: float = 0.0
var _shake_noise: FastNoiseLite
var _shake_time: float = 0.0
var _bg_image_base: Vector2 = Vector2.ZERO

# --- Hit-stop. We use unscaled timers (TIMER_PROCESS_IDLE) so the timeout
#     fires in real time even though Engine.time_scale is reduced.
var _hitstop_pending: int = 0

# --- Battle scene punch — quick scale pulse on the BattleScene Node2D.
var _battle_scene_punch_tween: Tween

# --- Loss vignette overlay (created on demand).
var _loss_vignette: ColorRect

# --- Player base position for spec-attack teleport animations.
var _player_base_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	SafeArea.apply(self)
	var level: LevelResource = GameState.get_current_level()
	_bg.color = level.background_color
	# Bleed the level's background colour into the safe-area bands above the
	# notch / below the home indicator. SafeArea.apply() insets the root Control,
	# so without this the OS-reserved strips show the boot-splash colour and
	# leave visible seams.
	RenderingServer.set_default_clear_color(level.background_color)
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
	# Shake noise — smoother + cheaper than randf-per-frame.
	_shake_noise = FastNoiseLite.new()
	_shake_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_shake_noise.frequency = 0.04
	_shake_noise.seed = int(Time.get_ticks_msec())
	_combat.damage_dealt.connect(_on_damage_dealt)
	_combat.heal_done.connect(_on_heal_done)
	_combat.status_applied.connect(_on_status_applied)
	_combat.battle_won.connect(_on_battle_won)
	_combat.battle_lost.connect(_on_battle_lost)
	_combat.enemy_stunned_skipped.connect(_on_enemy_stunned)
	_combat.mana_changed.connect(_on_mana_changed)
	_combat.spec_attack_fired.connect(_on_spec_attack_fired)
	_combat.auto_attack_fired.connect(_on_auto_attack_fired)
	_combat.item_broken.connect(_on_item_broken)
	# Phase G/H: surface encounter-behavior telegraph banners as floating labels
	# above the enemy. enemy_replaced fires when CP1 garrison swaps in the next
	# guard; we use it to refresh the HP bar binding so the new full HP shows.
	_combat.encounter_telegraph.connect(_on_encounter_telegraph)
	_combat.enemy_replaced.connect(_on_enemy_replaced)
	_install_encounter_behavior(level)
	# Almost-dead: when the player drops below 25% HP, pulse the HP bar red.
	_player_actor.low_hp.connect(_on_player_low_hp)
	_pause_button.pressed.connect(_on_pause)
	_exit_button.pressed.connect(_on_exit_pressed)
	_spec_button.pressed.connect(_on_spec_button_pressed)
	_tutorial.show_once()
	# Mana bar driven by ManaSystem charge level.
	if _combat.mana_system != null:
		_combat.mana_system.charge_level_changed.connect(_on_charge_level_changed)
		_mana_bar.set_mana(_combat.mana_system.mana, ManaSystem.MAX_MANA)
		_spec_button.set_charge_level(_combat.mana_system.get_charge_level())
	# Defer one frame so Control anchors have produced final sizes before HP bars sync.
	await get_tree().process_frame
	_player_hp.bind(_player_actor)
	_enemy_hp.bind(_enemy_actor)
	_player_status.bind(_player_actor)
	_enemy_status.bind(_enemy_actor)
	_layout_board()
	_shake_base = position
	_bg_image_base = _bg_image.position
	_player_base_pos = _player_battle_actor.position

func _exit_tree() -> void:
	# Defensive: never leave the engine paused if we exit mid hit-stop.
	Engine.time_scale = 1.0

func _process(delta: float) -> void:
	_battle_seconds += delta
	# Trauma-model shake — runs every frame, near-zero cost when trauma is 0.
	if _shake_trauma > 0.0001:
		_shake_time += delta * SHAKE_NOISE_SPEED
		# Square the trauma to bias toward small motion until big hits.
		var amount: float = _shake_trauma * _shake_trauma
		var nx: float = _shake_noise.get_noise_2d(_shake_time, 0.0)
		var ny: float = _shake_noise.get_noise_2d(0.0, _shake_time)
		var nrot: float = _shake_noise.get_noise_2d(_shake_time, _shake_time)
		var offset: Vector2 = Vector2(nx, ny) * amount * SHAKE_MAX_OFFSET_PX
		position = _shake_base + offset
		rotation_degrees = nrot * amount * SHAKE_MAX_ROT_DEG
		# Background parallax — drifts in the opposite direction, less amplitude.
		if _bg_image.visible:
			_bg_image.position = _bg_image_base - offset * SHAKE_BG_PARALLAX
		# Decay — at 60fps this is roughly trauma *= 0.92 per frame.
		_shake_trauma = max(0.0, _shake_trauma * pow(SHAKE_DECAY, delta * 60.0))
		if _shake_trauma <= 0.0001:
			_shake_trauma = 0.0
			position = _shake_base
			rotation_degrees = 0.0
			if _bg_image.visible:
				_bg_image.position = _bg_image_base

func _layout_board() -> void:
	var board_size: Vector2 = _board.board_total_size()
	var area_size: Vector2 = $BoardArea.size
	_board.position = Vector2((area_size.x - board_size.x) * 0.5, (area_size.y - board_size.y) * 0.5)

# --- Mana / spec-attack handlers ----------------------------------------

func _on_mana_changed(value: int, max_mana: int) -> void:
	_mana_bar.set_mana(value, max_mana)

func _on_charge_level_changed(level: int) -> void:
	_spec_button.set_charge_level(level)
	if level > 0:
		# Light haptic at each new tier unlocked.
		Haptics.light_tap()

func _on_spec_button_pressed() -> void:
	AudioBus.play_ui_click()
	if _combat.mana_system == null:
		return
	var lvl: int = _combat.mana_system.get_charge_level()
	if lvl <= 0:
		return
	_combat.fire_special(lvl)

# Plays the per-level VFX/animation. The hit itself was already applied by
# CombatController.fire_special — we're decorative here.
func _on_spec_attack_fired(level: int) -> void:
	# Pause player auto-attacks while the animation plays so the auto-hit
	# doesn't overlap the spec hit.
	if _combat.player_auto != null:
		_combat.player_auto.pause_for_anim()
	_spawn_spec_burst(level)
	await _play_spec_animation(level)
	if _combat.player_auto != null:
		_combat.player_auto.resume_after_anim()

func _spawn_spec_burst(level: int) -> void:
	# Use ComboBurst (repurposed from Phase A) for the screen flash.
	var color: Color = _spec_color_for_level(level)
	var vp_size: Vector2 = get_viewport_rect().size
	ComboBurst.spawn(vp_size, color, self)
	# RoundExecuteBurst (also repurposed) for a star burst at the player.
	var center: Vector2 = _player_battle_actor.global_position + Vector2(0, -60)
	RoundExecuteBurst.spawn(center, vp_size, [color, color, color], self)

func _spec_color_for_level(level: int) -> Color:
	match level:
		1: return Color(0.40, 0.62, 0.95, 1.0)
		2: return Color(0.95, 0.78, 0.30, 1.0)
		3: return Color(0.85, 0.15, 0.30, 1.0)
	return Color.WHITE

func _play_spec_animation(level: int) -> void:
	match level:
		1:
			# Shield bash: lunge + shield flash on enemy.
			_player_battle_actor.attack()
			await get_tree().create_timer(0.10).timeout
			_enemy_battle_actor.hurt()
			await get_tree().create_timer(0.45).timeout
		2:
			# Spinning strike: player rotates 360 while lunging.
			var spin := create_tween()
			spin.tween_property(_player_battle_actor, "rotation_degrees", 360.0, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
			spin.tween_callback(func(): _player_battle_actor.rotation_degrees = 0.0)
			_player_battle_actor.attack()
			await get_tree().create_timer(0.15).timeout
			_enemy_battle_actor.hurt()
			await get_tree().create_timer(0.50).timeout
		3:
			# Shadow strike: fade out, teleport behind enemy, hit, fade back.
			var fade_out := create_tween()
			fade_out.tween_property(_player_battle_actor, "modulate:a", 0.0, 0.18)
			await fade_out.finished
			# Teleport behind enemy.
			var enemy_pos: Vector2 = _enemy_battle_actor.position
			_player_battle_actor.position = enemy_pos + Vector2(80.0, 0.0)
			var fade_in := create_tween()
			fade_in.tween_property(_player_battle_actor, "modulate:a", 1.0, 0.12)
			await fade_in.finished
			_enemy_battle_actor.hurt()
			await get_tree().create_timer(0.30).timeout
			# Fade out again, teleport home, fade back.
			var fade_out2 := create_tween()
			fade_out2.tween_property(_player_battle_actor, "modulate:a", 0.0, 0.14)
			await fade_out2.finished
			_player_battle_actor.position = _player_base_pos
			var fade_in2 := create_tween()
			fade_in2.tween_property(_player_battle_actor, "modulate:a", 1.0, 0.14)
			await fade_in2.finished

# --- Auto-attack feedback -----------------------------------------------

func _on_auto_attack_fired(is_player: bool, _damage: int) -> void:
	# Lightweight attack animation on the attacker. The damage_dealt signal is
	# what actually paints the hit number / shake — keep this purely cosmetic
	# so the auto-attack rhythm reads.
	if is_player:
		_player_battle_actor.attack()
	else:
		_enemy_battle_actor.attack()

# Phase D: item triggered on the board. Show a brief floating label above the
# actor the effect targets so the player connects the cause and consequence.
func _on_item_broken(item: Resource, _location: Vector2i) -> void:
	var board_item: BoardItem = item as BoardItem
	if board_item == null:
		return
	var targets_player: bool = board_item.target == BoardItem.Target.PLAYER
	var anchor: BattleActor = _player_battle_actor if targets_player else _enemy_battle_actor
	var text: String = "%s triggered!" % board_item.display_name
	var color: Color = board_item.tint
	_spawn_status_ribbon(anchor, text, color)
	Haptics.medium_tap()

# --- Encounter behavior wiring (Phase G/H) ------------------------------

# Instantiate the encounter-specific behavior (CP1..CP5) based on the
# level's EncounterModifier.encounter_id. No modifier → no behavior; regular
# levels keep the generic combat loop.
func _install_encounter_behavior(level: LevelResource) -> void:
	if level == null or level.encounter_modifier == null:
		return
	var id: String = level.encounter_modifier.encounter_id
	if id == "":
		return
	var beh: EncounterBehavior = _instantiate_encounter_behavior(id)
	if beh == null:
		return
	beh.setup(_combat, level)
	_combat.add_child(beh)
	_combat.register_encounter_behavior(beh)
	beh.start()

func _instantiate_encounter_behavior(id: String) -> EncounterBehavior:
	match id:
		"cp1_garrison":
			return (load("res://scripts/combat/encounter_behaviors/cp1_garrison.gd") as Script).new()
		"cp2_archers":
			return (load("res://scripts/combat/encounter_behaviors/cp2_archers.gd") as Script).new()
		"cp3_catacombs":
			return (load("res://scripts/combat/encounter_behaviors/cp3_catacombs.gd") as Script).new()
		"cp4_pier":
			return (load("res://scripts/combat/encounter_behaviors/cp4_pier.gd") as Script).new()
		"cp5_supply_warden":
			return (load("res://scripts/combat/encounter_behaviors/cp5_supply_warden.gd") as Script).new()
	return null

# A behavior asked us to show a banner — reuse the status-ribbon path so
# the visual matches the rest of the battle's floating-text language.
func _on_encounter_telegraph(text: String, _seconds: float) -> void:
	_spawn_status_ribbon(_enemy_battle_actor, text, Color(1.0, 0.85, 0.40))

# CP1 garrison: enemy died but the encounter rolled in a fresh one. The
# behavior already wrote the new HP value into the actor and re-emitted
# hp_changed, so the bound HP/status views refresh themselves; we just sell
# the swap with a quick hurt flash.
func _on_enemy_replaced(_remaining_count: int) -> void:
	if _enemy_battle_actor != null:
		_enemy_battle_actor.hurt()

# --- Damage / heal / status (unchanged shape from old controller) -------

func _on_damage_dealt(target_is_player: bool, amount: int, _source_kind: int) -> void:
	var target_battle: BattleActor = _player_battle_actor if target_is_player else _enemy_battle_actor
	# Only flash hurt animation if the damage actually broke through (>0).
	if amount > 0:
		target_battle.hurt()
	var is_crit: bool = amount >= 50
	_spawn_float_text(target_battle.global_position + Vector2(0, -90), "-%d" % amount, Color(1, 0.4, 0.4), amount, is_crit)
	# Map damage → trauma. Cap at 1.0. Small hits ~0.2, ~25dmg ~0.5, ~50dmg ~0.85.
	var trauma: float = clamp(0.18 + amount * 0.016, 0.0, 1.0)
	add_shake(trauma)
	# Battle-scene punch scales with how heavy the hit feels.
	var punch_strength: float = clamp(0.02 + amount * 0.0015, 0.02, 0.08)
	_battle_scene_punch(punch_strength)
	# Hit-stop tiers — only the big and huge hits freeze the engine.
	if amount >= 50:
		_hit_stop(0.05, 0.12)
	elif amount >= 25:
		_hit_stop(0.15, 0.08)
	if target_is_player:
		Haptics.heavy_tap()
	else:
		Haptics.medium_tap()

func _on_heal_done(_target_is_player: bool, amount: int) -> void:
	_spawn_float_text(_player_battle_actor.global_position + Vector2(0, -80), "+%d" % amount, Color(0.5, 1, 0.5), amount, false, true)

func _on_status_applied(target_is_player: bool, fx: StatusEffect) -> void:
	var anchor: BattleActor = _player_battle_actor if target_is_player else _enemy_battle_actor
	# Show remaining seconds rounded for legibility.
	var label := "%s %.0fs" % [StatusEffect.kind_to_string(fx.kind), fx.seconds_remaining]
	var color := Color(1.0, 0.78, 0.30)
	match fx.kind:
		StatusEffect.Kind.BURN: color = Color(1.0, 0.50, 0.20)
		StatusEffect.Kind.SWARM: color = Color(0.55, 0.85, 0.40)
		StatusEffect.Kind.COLD: color = Color(0.55, 0.80, 1.00)
		StatusEffect.Kind.BLEED: color = Color(0.95, 0.30, 0.40)
		StatusEffect.Kind.STUN: color = Color(1.00, 0.92, 0.40)
		StatusEffect.Kind.DEFENSE_DEBUFF: color = Color(0.85, 0.55, 1.00)
		StatusEffect.Kind.ACID_BURN: color = Color(0.65, 0.95, 0.30)
		StatusEffect.Kind.IGNITE: color = Color(1.0, 0.65, 0.25)
		StatusEffect.Kind.ATTACK_BUFF: color = Color(0.95, 0.85, 0.45)
		StatusEffect.Kind.ARMOR_DEBUFF_ITEM: color = Color(0.85, 0.55, 1.00)
		StatusEffect.Kind.RANGED_SHIELD: color = Color(0.55, 0.75, 1.00)
	AudioBus.play_status(fx.kind)
	_spawn_status_ribbon(anchor, label, color)

func _on_battle_won() -> void:
	AudioBus.play_victory_sting()
	Haptics.success()
	await get_tree().create_timer(0.6).timeout
	_enemy_battle_actor.die()
	# Slow-mo + zoom into the player just before scene transition.
	Engine.time_scale = 0.5
	var zoom := create_tween()
	zoom.set_parallel(true)
	zoom.tween_property(_battle_scene, "scale", Vector2(1.18, 1.18), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Drift toward the player so the camera "follows" the win.
	var bs_target := _battle_scene.position + (_player_battle_actor.position * 0.1)
	zoom.tween_property(_battle_scene, "position", bs_target, 0.45).set_trans(Tween.TRANS_SINE)
	# Fade the enemy out subtly under the cinematic.
	zoom.tween_property(_enemy_battle_actor, "modulate:a", 0.0, 0.45)
	await get_tree().create_timer(0.4).timeout
	Engine.time_scale = 1.0
	await get_tree().create_timer(0.3).timeout
	# Stash the result so the victory scene can show level-specific copy. Done
	# BEFORE advance_to_next_castle() so we capture the *conquered* castle name
	# rather than the freshly-rolled successor.
	var level: LevelResource = GameState.get_current_level()
	var stars: int = _award_stars()
	var is_king: bool = GameState.is_current_level_king()
	GameState.last_battle_result = {
		"is_king": is_king,
		"level_name": level.level_name if level != null else "",
		"enemy_name": level.enemy_name if level != null else "",
		"castle_name": GameState.current_castle.castle_name if GameState.current_castle != null else "",
		"stars": stars,
		"rounds": int(_battle_seconds),
		"hp_remaining": _player_actor.current_hp,
		"hp_max": _player_actor.max_hp,
	}
	if is_king:
		GameState.advance_to_next_castle()
	else:
		GameState.mark_level_completed(GameState.castle_index, GameState.chapter_index, GameState.level_index)
		GameState.mark_level_stars(GameState.castle_index, GameState.chapter_index, GameState.level_index, stars)
	SceneRouter.goto_victory()

func _on_battle_lost() -> void:
	AudioBus.play_defeat_sting()
	Haptics.failure()
	await get_tree().create_timer(0.6).timeout
	_player_battle_actor.die()
	_show_loss_vignette()
	# Fade the player out alongside the vignette.
	var fade := create_tween()
	fade.tween_property(_player_battle_actor, "modulate:a", 0.0, 0.6)
	await get_tree().create_timer(0.9).timeout
	SceneRouter.goto_game_over()

func _on_enemy_stunned() -> void:
	_spawn_float_text(_enemy_battle_actor.global_position + Vector2(0, -120), "STUNNED!", Color(1, 0.92, 0.30), 99, true)

func _on_pause() -> void:
	AudioBus.play_ui_click()
	Haptics.light_tap()
	_settings_panel.visible = not _settings_panel.visible
	if _settings_panel.visible:
		AudioBus.play_panel_open()
	else:
		AudioBus.play_panel_close()

func _on_exit_pressed() -> void:
	AudioBus.play_ui_click()
	Haptics.light_tap()
	SceneRouter.goto_chapter_map()

func _award_stars() -> int:
	# Star awards retuned for real-time combat: 3 if you ended above 70% HP in
	# under 90s, 2 if above 35% or under 150s, else 1.
	var hp_pct: float = float(_player_actor.current_hp) / float(max(1, _player_actor.max_hp))
	if hp_pct > 0.70 and _battle_seconds <= 90.0:
		return 3
	if hp_pct > 0.35 or _battle_seconds <= 150.0:
		return 2
	return 1

# Spawn a floating damage/heal/info number. `is_crit` paints a red outline +
# shake during the punch-in. `is_heal` adds a small horizontal sine drift while
# rising so heals feel airier than damage drops.
func _spawn_float_text(at: Vector2, text: String, color: Color, magnitude: int, is_crit: bool = false, is_heal: bool = false) -> void:
	# Big hits get larger, more dramatic text; small hits / status notices stay subtle.
	var font_size: int = FLOAT_FONT_SIZE_BIG if magnitude >= 25 else FLOAT_FONT_SIZE_SMALL
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", font_size)
	var outline_color: Color = Color(0.85, 0.10, 0.10) if is_crit else Color.BLACK
	lbl.add_theme_color_override("font_outline_color", outline_color)
	lbl.add_theme_constant_override("outline_size", 6 if is_crit else 5)
	lbl.position = at
	lbl.pivot_offset = Vector2(40, 20)
	lbl.scale = Vector2(0.2, 0.2)
	_floating_text_root.add_child(lbl)
	# Stamp-in: punch to 1.4 over 0.10, settle to 1.0.
	var pop := create_tween()
	pop.tween_property(lbl, "scale", Vector2(1.4, 1.4), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.08).set_trans(Tween.TRANS_SINE)
	# Crit text shakes for the duration of the stamp. We only jitter x so the
	# parallel y-drift tween below isn't fighting for the same property.
	if is_crit:
		var shake := create_tween()
		for i in range(6):
			shake.tween_property(lbl, "position:x", at.x + randf_range(-4.0, 4.0), 0.03)
		shake.tween_property(lbl, "position:x", at.x, 0.04)
	# Drift up + fade. Animate y and alpha together; heals also wobble x in a
	# separate sequential tween so they feel airier than damage drops.
	var drift_dist: float = 110.0 if is_crit else 90.0
	var drift := create_tween()
	drift.set_parallel(true)
	drift.tween_property(lbl, "position:y", at.y - drift_dist, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	drift.tween_property(lbl, "modulate:a", 0.0, 0.9)
	drift.chain().tween_callback(lbl.queue_free)
	if is_heal:
		# Sequential side-to-side sway in a separate tween (the drift tween is
		# fully parallel — using it for sequential moves would break the y rise).
		var sway := create_tween()
		var sway_steps: int = 4
		var step_time: float = 0.9 / float(sway_steps * 2)
		var amp: float = 14.0
		for i in range(sway_steps):
			sway.tween_property(lbl, "position:x", at.x + amp, step_time).set_trans(Tween.TRANS_SINE)
			sway.tween_property(lbl, "position:x", at.x - amp, step_time).set_trans(Tween.TRANS_SINE)

func _on_player_low_hp(_actor: CombatActor) -> void:
	# Additive: tween the existing HP bar's modulate between full white and red
	# rapidly so the player notices they're nearly dead. We don't touch the bar's
	# internal fill/colour — just modulate at the Control level.
	if _player_hp == null:
		return
	var t := create_tween()
	t.set_loops(6)
	t.tween_property(_player_hp, "modulate", Color(1.0, 0.35, 0.35, 1.0), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_player_hp, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# A status ribbon slides in from the side of the actor it lands on, sits, then
# fades up. Cheaper / less noisy than a number-style float.
func _spawn_status_ribbon(anchor: BattleActor, text: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", FLOAT_FONT_SIZE_SMALL)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 5)
	# Slide from the side of the actor (depending on which actor it lands on).
	var side: float = -1.0 if anchor.is_player else 1.0
	var settle: Vector2 = anchor.global_position + Vector2(0, -130)
	var start: Vector2 = settle + Vector2(side * 160.0, 0)
	lbl.position = start
	lbl.pivot_offset = Vector2(40, 20)
	lbl.modulate.a = 0.0
	_floating_text_root.add_child(lbl)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(lbl, "position", settle, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(lbl, "modulate:a", 1.0, 0.18)
	# Hold, then float up + fade.
	var outro := create_tween()
	outro.tween_interval(0.55)
	outro.tween_property(lbl, "position", settle + Vector2(0, -50), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	outro.parallel().tween_property(lbl, "modulate:a", 0.0, 0.5)
	outro.tween_callback(lbl.queue_free)

# Public shake API — strength is 0..1 magnitude that accumulates into trauma.
# Multiple back-to-back hits stack but cap at 1.0.
func add_shake(strength: float) -> void:
	if _shake_base == Vector2.ZERO:
		_shake_base = position
	_shake_trauma = clamp(_shake_trauma + strength, 0.0, 1.0)

# Back-compat shim — older code calls _screen_shake(intensity, duration).
# Translate to a trauma value that produces a similar feel.
func _screen_shake(intensity: float, _duration: float) -> void:
	add_shake(clamp(intensity, 0.0, 1.0))

# Time-freeze for big hits. We use a SceneTreeTimer in idle-process so the
# wait runs in real time even though Engine.time_scale is reduced.
func _hit_stop(scale_value: float, real_seconds: float) -> void:
	_hitstop_pending += 1
	Engine.time_scale = scale_value
	# `process_always` timers tick whether the tree is paused or not, but more
	# importantly Godot's SceneTreeTimer fires on real frames regardless of
	# Engine.time_scale, so this just waits real wall-clock time.
	await get_tree().create_timer(real_seconds, true, false, true).timeout
	_hitstop_pending -= 1
	if _hitstop_pending <= 0:
		_hitstop_pending = 0
		Engine.time_scale = 1.0

# Scale-pulse the BattleScene Node2D briefly to sell impact. Strength ~0.02-0.08
# is the extra scale on top of 1.0 (so 0.04 → 1.04 peak).
func _battle_scene_punch(strength: float) -> void:
	if _battle_scene_punch_tween != null and _battle_scene_punch_tween.is_running():
		_battle_scene_punch_tween.kill()
	var peak: Vector2 = Vector2(1.0 + strength, 1.0 + strength)
	_battle_scene_punch_tween = create_tween()
	_battle_scene_punch_tween.tween_property(_battle_scene, "scale", peak, 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_battle_scene_punch_tween.tween_property(_battle_scene, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)

# Red vignette on loss — fullscreen ColorRect that tints red while we transition.
func _show_loss_vignette() -> void:
	if _loss_vignette != null and is_instance_valid(_loss_vignette):
		return
	_loss_vignette = ColorRect.new()
	_loss_vignette.color = Color(0.6, 0.05, 0.05, 0.0)
	_loss_vignette.anchor_right = 1.0
	_loss_vignette.anchor_bottom = 1.0
	_loss_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_loss_vignette)
	# Push above the battle scene but below the settings panel which lives later
	# in the tree by default.
	move_child(_loss_vignette, get_child_count() - 1)
	var t := create_tween()
	t.tween_property(_loss_vignette, "color:a", 0.55, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
