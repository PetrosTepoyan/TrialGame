extends Control

const KING_LOCKED_TEXT := "The throne is sealed. Fell the three Wardens first."

# --- Theme tokens used by medallion buttons (mirrors three_towers.tres) ---
const _C_INK := Color(0.07, 0.05, 0.09)
const _C_DUSK := Color(0.18, 0.14, 0.22)
const _C_PARCHMENT := Color(0.92, 0.85, 0.68)
const _C_GOLD := Color(0.95, 0.78, 0.30)
const _C_GOLD_DIM := Color(0.55, 0.40, 0.18)
const _C_GOLD_HOVER := Color(1, 0.92, 0.55)

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
	thumb.custom_minimum_size = Vector2(220, 180)
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
	hdr.add_theme_font_size_override("font_size", 46)
	hdr.add_theme_color_override("font_color", Color(0.97, 0.84, 0.42, 1.0))
	hdr.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	hdr.add_theme_constant_override("shadow_offset_x", 1)
	hdr.add_theme_constant_override("shadow_offset_y", 2)
	v.add_child(hdr)

	if chapter.motto != "":
		var motto := Label.new()
		motto.text = "\"%s\"" % chapter.motto
		motto.add_theme_font_size_override("font_size", 26)
		motto.add_theme_color_override("font_color", Color(0.84, 0.74, 0.54, 0.95))
		motto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(motto)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	v.add_child(spacer)

	# Level buttons row — each level is a circular medallion with stars below.
	var unlocked_chapter: bool = GameState.is_chapter_unlocked(GameState.castle_index, ch_idx)
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 14)
	btn_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(btn_row)
	for lvl_idx in range(chapter.levels.size()):
		var lvl: LevelResource = chapter.levels[lvl_idx]
		var cell := _build_level_cell(ch_idx, lvl_idx, lvl)
		btn_row.add_child(cell)
		if not unlocked_chapter:
			var medallion: Button = cell.get_node_or_null(^"Medallion") as Button
			if medallion != null:
				medallion.disabled = true

	return card

func _build_level_cell(ch_idx: int, lvl_idx: int, lvl: LevelResource) -> Control:
	# Vertical stack: medallion button on top, stars (or lock) underneath.
	var cell := VBoxContainer.new()
	cell.alignment = BoxContainer.ALIGNMENT_CENTER
	cell.add_theme_constant_override("separation", 4)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var btn := _build_level_button(ch_idx, lvl_idx, lvl)
	btn.name = "Medallion"
	var btn_wrap := CenterContainer.new()
	btn_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_wrap.add_child(btn)
	cell.add_child(btn_wrap)

	var unlocked: bool = GameState.is_level_unlocked(GameState.castle_index, ch_idx, lvl_idx)
	var completed: bool = GameState.is_level_completed(GameState.castle_index, ch_idx, lvl_idx)

	var stars_lbl := Label.new()
	stars_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stars_lbl.add_theme_font_size_override("font_size", 26)
	if completed:
		var stars: int = GameState.get_level_stars(GameState.castle_index, ch_idx, lvl_idx)
		var star_str := ""
		for s in range(stars):
			star_str += "★"
		for s in range(3 - stars):
			star_str += "☆"
		stars_lbl.text = star_str
		stars_lbl.add_theme_color_override("font_color", _C_GOLD)
		stars_lbl.add_theme_color_override("font_outline_color", _C_INK)
		stars_lbl.add_theme_constant_override("outline_size", 3)
	elif not unlocked:
		stars_lbl.text = "🔒"
		stars_lbl.add_theme_color_override("font_color", Color(0.55, 0.45, 0.40, 0.85))
	else:
		stars_lbl.text = "☆☆☆"
		stars_lbl.add_theme_color_override("font_color", Color(0.55, 0.45, 0.40, 0.7))
	cell.add_child(stars_lbl)
	return cell

func _build_level_button(ch_idx: int, lvl_idx: int, lvl: LevelResource) -> Button:
	var btn := Button.new()
	# Medallions are squarish — large corner radius makes them read as circular
	# without needing a 2D shader (iOS GL Compatibility-safe).
	var unlocked: bool = GameState.is_level_unlocked(GameState.castle_index, ch_idx, lvl_idx)
	var completed: bool = GameState.is_level_completed(GameState.castle_index, ch_idx, lvl_idx)

	var size: Vector2 = Vector2(132, 132)
	if lvl.is_boss:
		size = Vector2(168, 132)
	btn.custom_minimum_size = size

	var label: String
	if lvl.is_boss:
		label = "⚔"
		btn.add_theme_font_size_override("font_size", 64)
	else:
		label = "%d" % (lvl_idx + 1)
		btn.add_theme_font_size_override("font_size", 56)
	btn.text = label

	# Per-state stylebox — medallions get their own look so the row reads as
	# discrete coin-like buttons rather than the default rounded rectangles.
	btn.add_theme_stylebox_override("normal", _medallion_style(_medallion_bg(completed, lvl.is_boss), _C_GOLD, 3, 64))
	btn.add_theme_stylebox_override("hover", _medallion_style(_medallion_bg(completed, lvl.is_boss).lightened(0.10), _C_GOLD_HOVER, 3, 64))
	btn.add_theme_stylebox_override("pressed", _medallion_style(_C_GOLD, _C_GOLD_DIM, 3, 64))
	btn.add_theme_stylebox_override("disabled", _medallion_style(Color(0.10, 0.08, 0.12, 0.70), Color(0.45, 0.38, 0.25, 0.55), 2, 64))
	btn.add_theme_stylebox_override("focus", _focus_ring(_C_GOLD_HOVER, 64))

	# Per-state font colors. Boss medallions use a brighter gold to read as elite.
	if lvl.is_boss:
		btn.add_theme_color_override("font_color", _C_GOLD)
		btn.add_theme_color_override("font_hover_color", _C_GOLD_HOVER)
	else:
		btn.add_theme_color_override("font_color", _C_PARCHMENT)
		btn.add_theme_color_override("font_hover_color", _C_GOLD_HOVER)
	btn.add_theme_color_override("font_pressed_color", _C_INK)
	btn.add_theme_color_override("font_disabled_color", Color(0.55, 0.45, 0.40, 0.6))
	btn.add_theme_color_override("font_outline_color", _C_INK)
	btn.add_theme_constant_override("outline_size", 4)

	btn.disabled = not unlocked
	btn.tooltip_text = "%s — %s (HP %d, dmg %d)" % [lvl.level_name, lvl.enemy_name, lvl.enemy_max_hp, lvl.enemy_damage]
	btn.pressed.connect(_on_level_pressed.bind(ch_idx, lvl_idx))
	return btn

func _medallion_bg(completed: bool, is_boss: bool) -> Color:
	# Conquered cells subtly glow gold; boss medallions sit a touch deeper in
	# tone so the eye picks them out as the chapter's anchor.
	if completed:
		return Color(0.30, 0.22, 0.10, 0.95)
	if is_boss:
		return Color(0.20, 0.10, 0.12, 0.95)
	return _C_DUSK

func _medallion_style(bg: Color, border: Color, border_w: int, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.border_width_left = border_w
	sb.border_width_right = border_w
	sb.border_width_top = border_w
	sb.border_width_bottom = border_w
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 6
	return sb

func _focus_ring(c: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = c
	sb.border_width_left = 3
	sb.border_width_right = 3
	sb.border_width_top = 3
	sb.border_width_bottom = 3
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	return sb

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
