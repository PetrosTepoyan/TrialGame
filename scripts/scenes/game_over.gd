extends Control

@onready var _retry: Button = $Center/VBox/Retry
@onready var _back: Button = $Center/VBox/Back
@onready var _heading: Label = $Center/VBox/Heading
@onready var _title: Label = $Center/VBox/Title
@onready var _detail: Label = $Center/VBox/Detail

func _ready() -> void:
	SafeArea.apply(self)
	RenderingServer.set_default_clear_color(Color(0.07, 0.05, 0.09))
	# v2: "Retry" is now "Continue" — it rolls back to the most recent
	# checkpoint rather than retrying the same battle.
	_retry.text = "Continue"
	_retry.pressed.connect(_on_continue_pressed)
	_back.pressed.connect(_on_back_pressed)
	_apply_rollback_copy()
	AudioBus.play_defeat_sting()
	_animate_entry()

func _apply_rollback_copy() -> void:
	# Show the player where they're about to be rewound to. This reads
	# GameState.last_checkpoint (set when a checkpoint was cleared); if it's
	# empty for the current chapter, we're going to chapter start instead.
	var target_name: String = _rollback_target_name()
	_title.text = "You fell."
	_detail.text = "Returning to %s." % target_name

func _rollback_target_name() -> String:
	var lc: Dictionary = GameState.last_checkpoint
	var in_chapter_cp: bool = (
		not lc.is_empty()
		and int(lc.get("castle", -1)) == GameState.castle_index
		and int(lc.get("chapter", -1)) == GameState.chapter_index
	)
	if in_chapter_cp:
		var cp_idx: int = int(lc.get("checkpoint_idx", 0))
		# Try to resolve the name of the checkpoint level so the player
		# recognises where they're heading.
		var castle: CastleResource = GameState.current_castle
		if castle != null and GameState.chapter_index < castle.chapters.size():
			var ch: ChapterResource = castle.chapters[GameState.chapter_index]
			# Flat index of the checkpoint level for block `cp_idx`.
			var flat: int = cp_idx * GameState.LEVELS_PER_BLOCK + GameState.CHECKPOINT_LEVEL_INDEX
			if flat < ch.levels.size():
				return ch.levels[flat].level_name
		return "the last checkpoint"
	# Chapter start fallback.
	var castle2: CastleResource = GameState.current_castle
	if castle2 != null and GameState.chapter_index < castle2.chapters.size():
		return "the start of %s" % castle2.chapters[GameState.chapter_index].chapter_name
	return "the start of this chapter"

func _on_continue_pressed() -> void:
	AudioBus.play_ui_click()
	Haptics.medium_tap()
	GameState.rollback_to_checkpoint()
	SceneRouter.goto_chapter_map()

func _on_back_pressed() -> void:
	AudioBus.play_ui_click()
	Haptics.light_tap()
	SceneRouter.goto_main_menu()

func _animate_entry() -> void:
	# Blood-red heading drops in like a slam; supporting copy fades in after.
	_heading.pivot_offset = _heading.size * 0.5
	_heading.scale = Vector2(1.25, 1.25)
	_heading.modulate.a = 0.0
	_title.modulate.a = 0.0
	_detail.modulate.a = 0.0
	_retry.modulate.a = 0.0
	_back.modulate.a = 0.0

	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_heading, "modulate:a", 1.0, 0.35)
	t.tween_property(_heading, "scale", Vector2(1.0, 1.0), 0.45)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.chain().tween_property(_title, "modulate:a", 1.0, 0.35)
	t.chain().tween_property(_detail, "modulate:a", 1.0, 0.35)
	t.chain().tween_property(_retry, "modulate:a", 1.0, 0.35)
	t.chain().tween_property(_back, "modulate:a", 1.0, 0.35)
