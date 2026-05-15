extends Control

@onready var _continue: Button = $Center/VBox/Continue
@onready var _label: Label = $Center/VBox/Label
@onready var _title: Label = $Center/VBox/Title
@onready var _detail: Label = $Center/VBox/Detail

# Captured in _apply_result so _on_continue_pressed can route correctly
# without re-reading the (cleared) last_battle_result dict.
var _was_king: bool = false
var _was_checkpoint: bool = false
var _checkpoint_chapter: int = -1
var _checkpoint_idx: int = -1

func _ready() -> void:
	SafeArea.apply(self)
	RenderingServer.set_default_clear_color(Color(0.07, 0.05, 0.09))
	_continue.pressed.connect(_on_continue_pressed)
	_apply_result()
	AudioBus.play_victory_sting()
	_animate_entry()

func _apply_result() -> void:
	# Victory screen now shows on EVERY win (level, tower, king). battle.gd
	# stashes the context in GameState.last_battle_result before routing here.
	var r: Dictionary = GameState.last_battle_result
	if r.is_empty():
		# Backstop: should only happen if someone deeplinks to this scene.
		_title.text = "Castle Conquered"
		_detail.text = ""
		return
	_was_king = bool(r.get("is_king", false))
	# Phase E: derive checkpoint status from the live level pointer (battle.gd
	# is in Phase B/owned by another agent — we don't extend its dict shape).
	# advance_level() hasn't run yet at this point, so the pointer still names
	# the level the player just cleared.
	if not _was_king:
		var current: LevelResource = GameState.get_current_level()
		if current != null and current.is_checkpoint:
			_was_checkpoint = true
			_checkpoint_chapter = GameState.chapter_index
			_checkpoint_idx = current.checkpoint_index
	var stars: int = int(r.get("stars", 0))
	var star_str: String = ""
	for i in range(stars):
		star_str += "★"
	for i in range(3 - stars):
		star_str += "☆"
	var hp_rem: int = int(r.get("hp_remaining", 0))
	var hp_max: int = int(r.get("hp_max", 0))
	if _was_king:
		_title.text = "Castle Conquered"
		var castle: String = str(r.get("castle_name", ""))
		_detail.text = "%s falls. You ride to the next stronghold.\n\n%s    HP %d / %d" % [
			castle, star_str, hp_rem, hp_max,
		]
	else:
		var lvl_name: String = str(r.get("level_name", "Tower cleared"))
		var enemy: String = str(r.get("enemy_name", ""))
		var enemy_line: String = ("%s defeated.\n" % enemy) if enemy != "" else ""
		_detail.text = "%s%s\n%s    HP %d / %d" % [
			enemy_line, lvl_name, star_str, hp_rem, hp_max,
		]
		_title.text = "Checkpoint Cleared" if _was_checkpoint else "Tower Cleared"
	# Mark the checkpoint cleared BEFORE routing to the upgrade picker — that
	# way the picker's choice can be locked into the snapshot (apply_run_upgrade
	# inspects last_battle_result.is_checkpoint to decide whether to lock).
	if _was_checkpoint and _checkpoint_chapter >= 0 and _checkpoint_idx >= 0:
		GameState.mark_checkpoint_cleared(_checkpoint_chapter, _checkpoint_idx)
	# DO NOT clear last_battle_result here — the upgrade picker still needs the
	# `is_checkpoint` hint. The picker clears it after the player makes a choice.

func _on_continue_pressed() -> void:
	AudioBus.play_ui_click()
	Haptics.light_tap()
	# King fight wraps the run — skip the upgrade picker for that one.
	if _was_king:
		GameState.last_battle_result = {}
		SceneRouter.goto_chapter_map()
		return
	# Regular battles and checkpoints both route to the picker. Advance the
	# level pointer first so the picker → chapter_map → next battle flow lands
	# on the right level. Hand the picker a flag so it can lock checkpoint
	# rewards into the snapshot.
	GameState.pending_upgrade_locks = _was_checkpoint
	GameState.advance_level()
	GameState.last_battle_result = {}
	SceneRouter.goto_upgrade_picker()

func _animate_entry() -> void:
	# Big VICTORY heading drops in with a punch-then-settle, while the
	# detail/title fade in underneath it.
	_label.pivot_offset = _label.size * 0.5
	_label.scale = Vector2(0.4, 0.4)
	_label.modulate.a = 0.0
	_title.modulate.a = 0.0
	_detail.modulate.a = 0.0
	_continue.modulate.a = 0.0

	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_label, "modulate:a", 1.0, 0.35)
	t.tween_property(_label, "scale", Vector2(1.08, 1.08), 0.45)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.chain().tween_property(_label, "scale", Vector2(1.0, 1.0), 0.18)\
		.set_trans(Tween.TRANS_SINE)
	t.chain().tween_property(_title, "modulate:a", 1.0, 0.4)
	t.chain().tween_property(_detail, "modulate:a", 1.0, 0.4)
	t.chain().tween_property(_continue, "modulate:a", 1.0, 0.4)
