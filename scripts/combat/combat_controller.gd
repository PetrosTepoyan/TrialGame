class_name CombatController
extends Node

# Real-time mana / spec-attack combat (Phase B).
#
#   - Both actors auto-attack on independent AutoAttackLoop timers. The player's
#     loop is paused around spec animations so the hit doesn't overlap the FX.
#   - Each board match fires its piece-kind's immediate effect through
#     MatchEffectApplier (small damage / armor / DoT) AND adds mana to the
#     player's ManaSystem based on run length / square / corner.
#   - When mana ≥ 100 the player can spend the WHOLE bar to fire a special
#     attack at the current tier (1/2/3). The button + animation live in
#     battle.gd; this controller just resolves and applies the effect.
#   - A 1-second timer drives status DoT/decay on both actors.

signal damage_dealt(target_is_player: bool, amount: int, source_kind: int)
signal heal_done(target_is_player: bool, amount: int)
signal status_applied(target_is_player: bool, effect: StatusEffect)
signal battle_won
signal battle_lost
signal enemy_stunned_skipped
# New Phase B signals.
signal mana_changed(value: int, max_mana: int)
signal spec_attack_fired(level: int)
signal auto_attack_fired(is_player: bool, damage: int)
# Stub: Phase D wires items, but the signal lives here so other systems can
# subscribe without bouncing through a future refactor.
signal item_broken(item: Resource, location: Vector2i)
# Phase G/H: encounter-behavior plumbing. Telegraph banners surface gimmick
# state to battle.gd; enemy_replaced lets CP1 swap in fresh garrison enemies
# without firing battle_won.
signal encounter_telegraph(text: String, seconds: float)
signal enemy_replaced(remaining_count: int)

enum State { ACTIVE, ENDED }

# Default auto-attack interval for the player when the level doesn't override.
const PLAYER_INTERVAL_DEFAULT: float = 1.8
# Per spec: each second the dot/status timer ticks.
const STATUS_TICK_SECONDS: float = 1.0

@export var board_path: NodePath
@export var player_actor_path: NodePath
@export var enemy_actor_path: NodePath
@export var level: LevelResource

@onready var board: Board = get_node(board_path)
@onready var player: CombatActor = get_node(player_actor_path)
@onready var enemy: CombatActor = get_node(enemy_actor_path)

var state: int = State.ACTIVE

var mana_system: ManaSystem = null
var player_auto: AutoAttackLoop = null
var enemy_auto: AutoAttackLoop = null

var _status_timer: Timer = null

# Phase G/H: active encounter behavior (CP1..CP5). Null on regular levels.
var _encounter_behavior: EncounterBehavior = null

# Cascade accumulator: cascade-scope bonus is applied at cascade_finished.
# Tracks per-(kind,level) counts of matches in the current cascade so the
# bonus tier matches the .tres `combo_bonus_pct` table.
var _cascade_matches: Array = []           # Array of { kind, level, longest_run }
var _cascade_deferred_damage: int = 0      # accumulated raw damage this cascade
var _cascade_deferred_armor: int = 0

func _ready() -> void:
	add_to_group("combat_controllers")
	if level == null:
		level = GameState.get_current_level()
	_apply_level_stats()
	board.match_resolved.connect(_on_match_resolved)
	board.cascade_finished.connect(_on_cascade_finished)
	board.invalid_swap.connect(_on_invalid_swap)
	# Phase D: route board-side item breaks through ItemEffects, then re-emit the
	# controller's own item_broken signal for battle.gd / encounter behaviors.
	if board.has_signal("item_broken"):
		board.item_broken.connect(_on_board_item_broken)
	player.died.connect(_on_player_died)
	enemy.died.connect(_on_enemy_died)
	_install_mana_system()
	_install_auto_attack_loops()
	_install_status_timer()
	_wire_item_spawner()
	_apply_debug_overrides()

func _process(_delta: float) -> void:
	# Re-read live debug overrides each frame so the debug menu's spinboxes
	# take effect immediately, without needing a battle restart.
	_apply_debug_overrides()

# Hand the spawner a Callable into the player's HP fraction so it can boost the
# spawn chance as the player gets low.
func _wire_item_spawner() -> void:
	if board == null or not board.has_method("get_item_spawner"):
		return
	var spawner: ItemSpawner = board.get_item_spawner()
	if spawner == null:
		return
	spawner.set_player_hp_provider(Callable(self, "_player_hp_fraction"))
	# Respect the debug menu's force-spawn override so testers' toggle persists
	# into freshly-started battles.
	var dbg: Node = get_node_or_null("/root/DebugOverlay")
	if dbg != null and dbg.has_method("get_override"):
		var force_v: Variant = dbg.call("get_override", "items.force_spawn_every_refill", false)
		if force_v == true and spawner.has_method("set_force_spawn_every_refill"):
			spawner.set_force_spawn_every_refill(true)

func _player_hp_fraction() -> float:
	if player == null or player.max_hp <= 0:
		return 1.0
	return float(player.current_hp) / float(player.max_hp)

func _on_board_item_broken(item: Resource, pos: Vector2i) -> void:
	if state == State.ENDED:
		return
	var board_item: BoardItem = item as BoardItem
	if board_item != null:
		ItemEffects.apply_effect(board_item, player, enemy)
	# Re-emit on this controller so battle.gd / encounter code can show feedback
	# without listening to two different signal sources.
	emit_signal("item_broken", item, pos)
	if _encounter_behavior != null and board_item != null:
		_encounter_behavior.on_item_broken(board_item, pos)

# Re-read live debug overrides (called each frame from _process so spinbox
# edits take effect mid-battle without restarting the scene).
func _apply_debug_overrides() -> void:
	var dbg: Node = get_node_or_null("/root/DebugOverlay")
	if dbg == null or not dbg.has_method("get_override"):
		return
	var dmg_v: Variant = dbg.call("get_override", "combat.enemy_damage", null)
	if dmg_v != null and enemy != null:
		var dmg_i: int = int(dmg_v)
		if dmg_i >= 0:
			enemy.base_damage = dmg_i
			if enemy_auto != null:
				enemy_auto.base_damage = dmg_i
	# Live enemy max HP — when the spinbox changes, resize max_hp and clamp
	# current_hp so the HP bar reflects the new ceiling immediately.
	var ehp_v: Variant = dbg.call("get_override", "combat.enemy_max_hp_live", null)
	if ehp_v != null and enemy != null:
		var ehp_i: int = int(ehp_v)
		if ehp_i >= 1 and enemy.max_hp != ehp_i:
			enemy.max_hp = ehp_i
			if enemy.current_hp > ehp_i:
				enemy.current_hp = ehp_i
			enemy.emit_signal("hp_changed", enemy.current_hp, enemy.max_hp)
	# Live player auto-attack damage.
	var pdmg_v: Variant = dbg.call("get_override", "combat.player_auto_damage", null)
	if pdmg_v != null and player != null:
		var pdmg_i: int = int(pdmg_v)
		if pdmg_i >= 0:
			player.base_damage = pdmg_i
			if player_auto != null:
				player_auto.base_damage = pdmg_i

func _apply_level_stats() -> void:
	player.is_player = true
	player.display_name = "Hero"
	# Auto-attack damage = 6 base + run-upgrade bonus; match damage is owned by
	# PieceType.level_values so this only affects the player_auto loop.
	var player_dmg: int = 6 + GameState.player_base_damage_bonus
	player.setup(GameState.player_max_hp, player_dmg, GameState.player_max_armor)
	enemy.is_player = false
	enemy.display_name = level.enemy_name
	var enemy_armor: int = 0
	if level.boss_modifier != null:
		enemy_armor = level.boss_modifier.armor
	enemy.setup(level.enemy_max_hp, level.enemy_damage, enemy_armor)

func _install_mana_system() -> void:
	mana_system = ManaSystem.new()
	mana_system.name = "ManaSystem"
	add_child(mana_system)
	mana_system.mana_changed.connect(_on_mana_changed_internal)

func _on_mana_changed_internal(value: int, max_mana: int) -> void:
	mana_changed.emit(value, max_mana)

func _install_auto_attack_loops() -> void:
	# Player auto-attack: targets the enemy.
	player_auto = AutoAttackLoop.new()
	player_auto.name = "PlayerAutoAttack"
	player_auto.attacker = player
	player_auto.target = enemy
	player_auto.interval = PLAYER_INTERVAL_DEFAULT
	player_auto.base_damage = player.base_damage
	add_child(player_auto)
	player_auto.auto_attacked.connect(_on_player_auto_attacked)
	player_auto.start()
	# Enemy auto-attack: targets the player.
	enemy_auto = AutoAttackLoop.new()
	enemy_auto.name = "EnemyAutoAttack"
	enemy_auto.attacker = enemy
	enemy_auto.target = player
	# level.enemy_attack_interval is stored as int "turns" in pre-Phase-B saves;
	# reinterpret as seconds with a reasonable floor.
	var enemy_interval: float = 2.0
	if level != null and level.enemy_attack_interval > 0:
		enemy_interval = max(0.8, float(level.enemy_attack_interval))
	# Boss / king authoring used enemy_attack_interval=1 to mean "fast"; that
	# becomes a 1.4s tempo to keep them threatening but not unfair.
	if enemy_interval <= 1.0:
		enemy_interval = 1.4
	enemy_auto.interval = enemy_interval
	enemy_auto.base_damage = enemy.base_damage
	add_child(enemy_auto)
	enemy_auto.auto_attacked.connect(_on_enemy_auto_attacked)
	enemy_auto.start()

func _install_status_timer() -> void:
	_status_timer = Timer.new()
	_status_timer.wait_time = STATUS_TICK_SECONDS
	_status_timer.one_shot = false
	_status_timer.autostart = false
	add_child(_status_timer)
	_status_timer.timeout.connect(_on_status_tick)
	_status_timer.start()

func _on_status_tick() -> void:
	if state == State.ENDED:
		return
	# Apply DoT damage and decay durations. emit damage_dealt for any DoT tick
	# so the floating-text layer in battle.gd can show it.
	var enemy_dot: int = enemy.tick_dot_seconds(STATUS_TICK_SECONDS)
	if enemy_dot > 0:
		emit_signal("damage_dealt", false, enemy_dot, -1)
		_notify_enemy_damaged(enemy_dot)
	if state == State.ENDED:
		return
	var player_dot: int = player.tick_dot_seconds(STATUS_TICK_SECONDS)
	if player_dot > 0:
		emit_signal("damage_dealt", true, player_dot, -1)

# --- Match handling -------------------------------------------------------

func _on_match_resolved(kind: int, _count: int, longest_run: int, _from_rainbow: bool, effective_level: int) -> void:
	if state == State.ENDED:
		return
	# Apply the per-match effect. effective_level is the canonical tier (the
	# board has already bumped it for squares/corners/rainbow).
	var lvl: int = effective_level
	if lvl < 1:
		lvl = PieceType.level_from_match(longest_run)
	var result: Dictionary = MatchEffectApplier.apply(kind, lvl, longest_run, player, enemy)
	_consume_match_result(result, kind)
	# Mana gain.
	var mana_amount: int = mana_for_match(lvl, longest_run)
	if mana_system != null and mana_amount > 0:
		mana_system.add(mana_amount)
	# Track for cascade-scope bonus.
	_cascade_matches.append({ "kind": kind, "level": lvl, "longest_run": longest_run })
	# Fan out to the active encounter behavior, if any.
	if _encounter_behavior != null:
		_encounter_behavior.on_match_resolved(kind, lvl, longest_run)

func _consume_match_result(result: Dictionary, kind: int) -> void:
	var damage: int = int(result.get("damage", 0))
	var pierce: int = int(result.get("pierce", 0))
	var armor: int = int(result.get("armor", 0))
	var heal: int = int(result.get("heal", 0))
	var status_v: Variant = result.get("status", null)
	if armor > 0:
		player.add_armor(armor)
	if heal > 0:
		var healed: int = player.heal(heal)
		if healed > 0:
			emit_signal("heal_done", true, healed)
	if pierce > 0 or damage > 0:
		var dealt: int = enemy.take_damage(damage, false, pierce)
		if dealt > 0:
			AudioBus.play_kind_hit(kind)
			emit_signal("damage_dealt", false, dealt, kind)
			_notify_enemy_damaged(dealt)
	if status_v != null:
		var fx: StatusEffect = status_v
		enemy.apply_status(fx)
		emit_signal("status_applied", false, fx)

# Mana awarded per match (placeholder values; balance pass in Phase I).
#   match-3       → 20
#   match-4       → 35
#   match-5+      → 55
#   2×2 / corner  → 30 (effective_level=2 with run=3 means a square or corner)
#   any L3 chord  → 55
func mana_for_match(effective_level: int, longest_run: int) -> int:
	# L3 always pays out the top tier.
	if effective_level >= 3:
		return 55
	# L2 with a long run (4) pays 35; L2 with short run (3, i.e. square/corner)
	# pays 30 — square/corner is the smaller-board geometry path.
	if effective_level == 2:
		if longest_run >= 4:
			return 35
		return 30
	# L1: standard 3-in-a-row.
	return 20

func _on_cascade_finished(_total: int, _depth: int) -> void:
	if state == State.ENDED:
		return
	_apply_cascade_bonus()
	_cascade_matches.clear()

# Cascade-scope combo bonus: count (kind, level) frequencies across this
# cascade. For any (kind, level) with 3+ same-level matches, look up the
# combo_bonus_pct from the .tres and bonus the enemy with extra damage.
# Damage-only — armor/heal stay match-scoped so the bonus reads as "combo
# damage".
func _apply_cascade_bonus() -> void:
	if _cascade_matches.is_empty():
		return
	# Bucket by (kind, level).
	var counts: Dictionary = {}
	for m_v in _cascade_matches:
		var m: Dictionary = m_v
		var key := "%d.%d" % [int(m["kind"]), int(m["level"])]
		counts[key] = int(counts.get(key, 0)) + 1
	for key_v in counts.keys():
		var key: String = key_v
		var c: int = int(counts[key])
		if c < 3:
			continue
		var parts: Array = key.split(".")
		var k: int = int(parts[0])
		var lvl: int = int(parts[1])
		var pct: int = MatchEffectApplier.cascade_bonus_pct(k, lvl, c)
		if pct <= 0:
			continue
		# Base damage for the bonus = level_values[lvl] × count.
		var pt: PieceType = MatchEffectApplier.load_piece_type(k)
		if pt == null or pt.level_values.size() < 3:
			continue
		var base: int = pt.level_values[lvl - 1] * c
		var bonus: int = int(base * pct / 100.0)
		if bonus <= 0:
			continue
		var dealt: int = enemy.take_damage(bonus, false, 0)
		if dealt > 0:
			AudioBus.play_kind_hit(k)
			emit_signal("damage_dealt", false, dealt, k)
			_notify_enemy_damaged(dealt)

func _on_invalid_swap() -> void:
	pass

# --- Special attack ------------------------------------------------------

func fire_special(level_requested: int) -> Dictionary:
	# Returns the resolved-data dict so battle.gd can play the right anim. An
	# invalid request (mana too low, wrong level, dead actors) returns {} —
	# battle.gd checks for that.
	if state == State.ENDED or mana_system == null:
		return {}
	var charge: int = mana_system.get_charge_level()
	if charge <= 0:
		return {}
	# If a higher level was requested than is currently charged, downshift to
	# the highest the player has paid for. This is the "tap at any level burns
	# the bar" behaviour from the spec.
	var lvl: int = clampi(level_requested, 1, 3)
	if lvl > charge:
		lvl = charge
	var spec: SpecialAttack = _load_special(lvl)
	if spec == null:
		return {}
	var data: Dictionary = SpecialAttackResolver.resolve(spec, player, enemy)
	# Burn the whole bar regardless of tier.
	mana_system.consume_all()
	# Apply damage / status. Animation timing belongs to battle.gd; we apply
	# the hit immediately so the resolver can stun the enemy before the
	# animation completes (auto-attacks pause around the spec, so a fast
	# follow-up isn't possible anyway).
	var dmg: int = int(data.get("damage", 0))
	var bypass: bool = bool(data.get("bypass_armor", false))
	if dmg > 0:
		var dealt: int = enemy.take_damage(dmg, bypass, 0)
		if dealt > 0:
			AudioBus.play_kind_hit(PieceType.Kind.SWORD)
			emit_signal("damage_dealt", false, dealt, -1)
			_notify_enemy_damaged(dealt)
	var status_v: Variant = data.get("status", null)
	if status_v != null:
		var fx: StatusEffect = status_v
		enemy.apply_status(fx)
		emit_signal("status_applied", false, fx)
	emit_signal("spec_attack_fired", lvl)
	if _encounter_behavior != null:
		_encounter_behavior.on_spec_attack_fired(lvl)
	Haptics.heavy_tap()
	return data

func _load_special(lvl: int) -> SpecialAttack:
	var path: String = ""
	match lvl:
		1: path = "res://data/special_attacks/shield_bash.tres"
		2: path = "res://data/special_attacks/spinning_strike.tres"
		3: path = "res://data/special_attacks/shadow_strike.tres"
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path)

# --- Auto-attack relay ---------------------------------------------------

func _on_player_auto_attacked(damage: int) -> void:
	if damage > 0:
		emit_signal("damage_dealt", false, damage, -1)
		_notify_enemy_damaged(damage)
	emit_signal("auto_attack_fired", true, damage)
	Haptics.medium_tap()

func _on_enemy_auto_attacked(damage: int) -> void:
	if damage > 0:
		emit_signal("damage_dealt", true, damage, -1)
		if _encounter_behavior != null:
			_encounter_behavior.on_player_attacked(damage)
	emit_signal("auto_attack_fired", false, damage)
	Haptics.light_tap()

# --- End-of-battle plumbing ---------------------------------------------

func _on_player_died(_a: CombatActor) -> void:
	if state == State.ENDED:
		return
	state = State.ENDED
	_stop_loops()
	emit_signal("battle_lost")

func _on_enemy_died(_a: CombatActor) -> void:
	if state == State.ENDED:
		return
	# Encounter behaviors may absorb the death — CP1 garrison swaps in the next
	# enemy, refills HP, and returns true so battle_won does NOT fire.
	if _encounter_behavior != null:
		var absorbed: bool = _encounter_behavior.on_enemy_died()
		if absorbed:
			return
	state = State.ENDED
	_stop_loops()
	emit_signal("battle_won")

func _stop_loops() -> void:
	if player_auto != null:
		player_auto.stop()
	if enemy_auto != null:
		enemy_auto.stop()
	if _status_timer != null:
		_status_timer.stop()

# --- Encounter behavior plumbing (Phase G/H) -----------------------------

# battle.gd instantiates the right EncounterBehavior subclass and hands it in.
# We hold the reference; the per-signal forwarders inline check _encounter_behavior
# so we don't bind on every dispatch.
func register_encounter_behavior(b: EncounterBehavior) -> void:
	_encounter_behavior = b

# Inline helper so the four enemy-damage paths (match, spec, auto-attack,
# DoT, cascade bonus) all funnel into the behavior the same way without each
# growing a connect()/disconnect() pair.
func _notify_enemy_damaged(amount: int) -> void:
	if _encounter_behavior == null or amount <= 0:
		return
	if _encounter_behavior.has_method("on_enemy_damaged"):
		_encounter_behavior.call("on_enemy_damaged", amount)
