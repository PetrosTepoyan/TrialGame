extends Control

@onready var _title: Label = $TopBar/Title
@onready var _subtitle: Label = $TopBar/Subtitle
@onready var _chapters_container: VBoxContainer = $Scroll/Chapters
@onready var _back_button: Button = $TopBar/Back
@onready var _king_button: Button = $KingButton

func _ready() -> void:
	_back_button.pressed.connect(_on_back)
	_king_button.pressed.connect(_on_king_pressed)
	_render()

func _render() -> void:
	if GameState.current_castle == null:
		GameState._ensure_castle()
	_title.text = GameState.current_castle.castle_name
	_subtitle.text = "Topple three towers, then the King."
	for c in _chapters_container.get_children():
		c.queue_free()
	for ch_idx in range(GameState.current_castle.chapters.size()):
		var chapter: ChapterResource = GameState.current_castle.chapters[ch_idx]
		var chapter_panel := _build_chapter_panel(ch_idx, chapter)
		_chapters_container.add_child(chapter_panel)
	_king_button.disabled = not GameState.is_king_unlocked()
	_king_button.text = "Fight the King" if GameState.is_king_unlocked() else "King — locked"

func _build_chapter_panel(ch_idx: int, chapter: ChapterResource) -> Control:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	var hdr := Label.new()
	hdr.text = "%s — %s" % [chapter.chapter_name, chapter.theme.capitalize()]
	hdr.add_theme_font_size_override("font_size", 24)
	v.add_child(hdr)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	for lvl_idx in range(chapter.levels.size()):
		var lvl: LevelResource = chapter.levels[lvl_idx]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(80, 80)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var label: String = "%d" % (lvl_idx + 1)
		if lvl.is_boss:
			label = "Tower"
		btn.text = label
		var unlocked: bool = GameState.is_level_unlocked(GameState.castle_index, ch_idx, lvl_idx)
		var completed: bool = GameState.is_level_completed(GameState.castle_index, ch_idx, lvl_idx)
		if completed:
			var stars: int = GameState.get_level_stars(GameState.castle_index, ch_idx, lvl_idx)
			var star_str := ""
			for s in range(stars):
				star_str += "*"
			btn.text = label + "\n" + star_str
		btn.disabled = not unlocked
		btn.pressed.connect(_on_level_pressed.bind(ch_idx, lvl_idx))
		h.add_child(btn)
	v.add_child(h)
	return v

func _on_level_pressed(ch_idx: int, lvl_idx: int) -> void:
	GameState.set_current_pointer(ch_idx, lvl_idx)
	SceneRouter.goto_battle()

func _on_king_pressed() -> void:
	# King fight uses a synthetic chapter/level index (3, 0) for save-tracking.
	GameState.set_current_pointer(3, 0)
	SceneRouter.goto_battle()

func _on_back() -> void:
	SceneRouter.goto_main_menu()
