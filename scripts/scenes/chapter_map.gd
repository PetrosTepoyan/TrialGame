extends Control

const KING_LOCKED_TEXT := "The throne is sealed. Fell the three Wardens first."

@onready var _title: Label = $TopBar/Title
@onready var _subtitle: Label = $TopBar/Subtitle
@onready var _chapters_container: VBoxContainer = $Scroll/Chapters
@onready var _back_button: Button = $TopBar/Back
@onready var _king_button: Button = $KingPanel/KingVBox/KingButton
@onready var _king_flavor: Label = $KingPanel/KingVBox/KingFlavor

func _ready() -> void:
	SafeArea.apply(self)
	_back_button.pressed.connect(_on_back)
	_king_button.pressed.connect(_on_king_pressed)
	_render()

func _render() -> void:
	if GameState.current_castle == null:
		GameState._ensure_castle()
	var castle: CastleResource = GameState.current_castle
	_title.text = castle.castle_name
	_subtitle.text = castle.subtitle if castle.subtitle != "" else "Topple three towers, then the King."

	for c in _chapters_container.get_children():
		c.queue_free()
	for ch_idx in range(castle.chapters.size()):
		var chapter: ChapterResource = castle.chapters[ch_idx]
		var chapter_card := _build_chapter_card(ch_idx, chapter)
		_chapters_container.add_child(chapter_card)

	var king_unlocked: bool = GameState.is_king_unlocked()
	_king_button.disabled = not king_unlocked
	if king_unlocked:
		var king_label: String = castle.king_level.level_name if castle.king_level != null else "Fight the King"
		_king_button.text = "⚔  %s  ⚔" % king_label
		_king_flavor.text = "The throne stands open. Walk in."
	else:
		_king_button.text = "The Throne — sealed"
		_king_flavor.text = KING_LOCKED_TEXT

func _build_chapter_card(ch_idx: int, chapter: ChapterResource) -> Control:
	# Outer card — dark translucent panel so chapter blocks read as distinct
	# against the keep background.
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card_bg := StyleBoxFlat.new()
	card_bg.bg_color = Color(0.07, 0.05, 0.08, 0.78)
	card_bg.border_width_left = 2
	card_bg.border_width_right = 2
	card_bg.border_width_top = 2
	card_bg.border_width_bottom = 2
	card_bg.border_color = Color(0.55, 0.40, 0.18, 0.75)
	card_bg.corner_radius_top_left = 6
	card_bg.corner_radius_top_right = 6
	card_bg.corner_radius_bottom_left = 6
	card_bg.corner_radius_bottom_right = 6
	card_bg.content_margin_left = 14
	card_bg.content_margin_right = 14
	card_bg.content_margin_top = 12
	card_bg.content_margin_bottom = 14
	card.add_theme_stylebox_override("panel", card_bg)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)

	# Theme thumbnail on the left.
	var thumb := TextureRect.new()
	thumb.custom_minimum_size = Vector2(150, 110)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var tex_path: String = _theme_texture_path(chapter.theme)
	if tex_path != "":
		thumb.texture = load(tex_path)
	thumb.modulate = Color(0.85, 0.78, 0.74, 1.0)
	row.add_child(thumb)

	# Right column: title, motto, level buttons.
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	row.add_child(v)

	var hdr := Label.new()
	hdr.text = chapter.chapter_name
	hdr.add_theme_font_size_override("font_size", 26)
	hdr.add_theme_color_override("font_color", Color(0.97, 0.84, 0.42, 1.0))
	hdr.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	hdr.add_theme_constant_override("shadow_offset_x", 1)
	hdr.add_theme_constant_override("shadow_offset_y", 2)
	v.add_child(hdr)

	if chapter.motto != "":
		var motto := Label.new()
		motto.text = "\"%s\"" % chapter.motto
		motto.add_theme_font_size_override("font_size", 15)
		motto.add_theme_color_override("font_color", Color(0.84, 0.74, 0.54, 0.95))
		motto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(motto)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	v.add_child(spacer)

	# Level buttons row.
	var unlocked_chapter: bool = GameState.is_chapter_unlocked(GameState.castle_index, ch_idx)
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	btn_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(btn_row)
	for lvl_idx in range(chapter.levels.size()):
		var lvl: LevelResource = chapter.levels[lvl_idx]
		var btn := _build_level_button(ch_idx, lvl_idx, lvl)
		btn_row.add_child(btn)
		if not unlocked_chapter:
			btn.disabled = true

	return card

func _build_level_button(ch_idx: int, lvl_idx: int, lvl: LevelResource) -> Button:
	var btn := Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(72, 78)
	var unlocked: bool = GameState.is_level_unlocked(GameState.castle_index, ch_idx, lvl_idx)
	var completed: bool = GameState.is_level_completed(GameState.castle_index, ch_idx, lvl_idx)

	var label: String
	if lvl.is_boss:
		label = "⚔ Tower"
		btn.custom_minimum_size = Vector2(120, 78)
		btn.add_theme_color_override("font_color", Color(1.0, 0.78, 0.30, 1.0))
		btn.add_theme_font_size_override("font_size", 20)
	else:
		label = "%d" % (lvl_idx + 1)
		btn.add_theme_color_override("font_color", Color(0.94, 0.86, 0.66, 1.0))
		btn.add_theme_font_size_override("font_size", 22)

	if completed:
		var stars: int = GameState.get_level_stars(GameState.castle_index, ch_idx, lvl_idx)
		var star_str := ""
		for s in range(stars):
			star_str += "★"
		while star_str.length() < 3:
			star_str += "·"
		btn.text = "%s\n%s" % [label, star_str]
	elif not unlocked:
		btn.text = "%s\n🔒" % label
	else:
		btn.text = label

	btn.add_theme_color_override("font_disabled_color", Color(0.55, 0.45, 0.40, 0.6))
	btn.disabled = not unlocked
	btn.tooltip_text = "%s — %s (HP %d, dmg %d)" % [lvl.level_name, lvl.enemy_name, lvl.enemy_max_hp, lvl.enemy_damage]
	btn.pressed.connect(_on_level_pressed.bind(ch_idx, lvl_idx))
	return btn

func _theme_texture_path(theme_id: String) -> String:
	match theme_id:
		"forest": return "res://assets/backgrounds/forest.png"
		"wall": return "res://assets/backgrounds/walls.png"
		"keep": return "res://assets/backgrounds/keep.png"
	return ""

func _on_level_pressed(ch_idx: int, lvl_idx: int) -> void:
	GameState.set_current_pointer(ch_idx, lvl_idx)
	SceneRouter.goto_battle()

func _on_king_pressed() -> void:
	GameState.set_current_pointer(3, 0)
	SceneRouter.goto_battle()

func _on_back() -> void:
	SceneRouter.goto_main_menu()
