extends Control

const KING_LOCKED_TEXT := "The throne is sealed. Fell the three Wardens first."

# --- Theme tokens used by medallion buttons (mirrors three_towers.tres) ---
const _C_INK := Color(0.07, 0.05, 0.09)
const _C_DUSK := Color(0.18, 0.14, 0.22)
const _C_PARCHMENT := Color(0.92, 0.85, 0.68)
const _C_GOLD := Color(0.95, 0.78, 0.30)
const _C_GOLD_DIM := Color(0.55, 0.40, 0.18)
const _C_GOLD_HOVER := Color(1, 0.92, 0.55)
const _C_LOCKED := Color(0.45, 0.38, 0.30, 0.55)

# Block-progress flag glyphs.
const _FLAG_CLEARED := "⚑"
const _FLAG_CURRENT := "⚐"
const _FLAG_LOCKED := "·"

@onready var _title: Label = $TopBar/Title
@onready var _subtitle: Label = $TopBar/Subtitle
@onready var _chapters_container: VBoxContainer = $Scroll/Chapters
@onready var _back_button: Button = $TopBar/Back
@onready var _king_button: Button = $KingPanel/KingVBox/KingButton
@onready var _king_flavor: Label = $KingPanel/KingVBox/KingFlavor

func _ready() -> void:
	SafeArea.apply(self)
	RenderingServer.set_default_clear_color(Color(0.07, 0.05, 0.09))
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
	thumb.custom_minimum_size = Vector2(220, 220)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var tex_path: String = _theme_texture_path(chapter.theme)
	if tex_path != "":
		thumb.texture = load(tex_path)
	thumb.modulate = Color(0.85, 0.78, 0.74, 1.0)
	row.add_child(thumb)

	# Right column: title, motto, block rails.
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

	# Checkpoint progress flags — one glyph per block, shows at-a-glance which
	# blocks have been cleared, which is current, and which are locked.
	v.add_child(_build_checkpoint_flag_strip(ch_idx))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	v.add_child(spacer)

	# Render only the rails relevant to the player. Cleared blocks remain
	# tappable for replay (dimmed), the current block is fully interactive
	# (10 medallions + checkpoint boss), future blocks are stubs with a lock.
	var unlocked_chapter: bool = GameState.is_chapter_unlocked(GameState.castle_index, ch_idx)
	var is_current_chapter: bool = ch_idx == GameState.chapter_index
	for block_idx in range(GameState.BLOCKS_PER_CHAPTER):
		var rail := _build_block_rail(ch_idx, block_idx, chapter, unlocked_chapter, is_current_chapter)
		v.add_child(rail)

	return card

func _build_checkpoint_flag_strip(ch_idx: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var header := Label.new()
	header.text = "Checkpoints:"
	header.add_theme_font_size_override("font_size", 22)
	header.add_theme_color_override("font_color", Color(0.78, 0.70, 0.54, 0.85))
	row.add_child(header)
	for block_idx in range(GameState.BLOCKS_PER_CHAPTER):
		var glyph := Label.new()
		glyph.add_theme_font_size_override("font_size", 30)
		var cleared: bool = GameState.has_checkpoint_cleared(ch_idx, block_idx)
		var is_current: bool = (
			ch_idx == GameState.chapter_index
			and block_idx == GameState.current_block_index
			and not cleared
		)
		if cleared:
			glyph.text = _FLAG_CLEARED
			glyph.add_theme_color_override("font_color", _C_GOLD)
		elif is_current:
			glyph.text = _FLAG_CURRENT
			glyph.add_theme_color_override("font_color", _C_GOLD_HOVER)
		else:
			glyph.text = _FLAG_LOCKED
			glyph.add_theme_color_override("font_color", _C_LOCKED)
		row.add_child(glyph)
	return row

func _build_block_rail(
	ch_idx: int,
	block_idx: int,
	chapter: ChapterResource,
	chapter_unlocked: bool,
	is_current_chapter: bool,
) -> Control:
	var cleared_block: bool = GameState.has_checkpoint_cleared(ch_idx, block_idx)
	var current_block: bool = is_current_chapter and block_idx == GameState.current_block_index and not cleared_block
	var future_block: bool = not cleared_block and not current_block

	# Locked / future blocks get a compact stub row with a chain icon.
	if future_block or not chapter_unlocked:
		return _build_locked_rail_stub(block_idx)

	# Wrap the 10 regular medallions + 1 checkpoint into a two-row VBox so the
	# checkpoint (boss) medallion always has visible real estate even on the
	# narrowest 1080-wide layout. The chapter card's right column is ~794px;
	# 10 × 72 + 9 × 8 + 50px label ≈ 842px, which already wraps past the edge
	# before we add the checkpoint. Splitting the row avoids the clip.
	var wrap := VBoxContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.add_theme_constant_override("separation", 8)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 6)
	top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER

	# Block label on the left of the top row.
	var block_label := Label.new()
	block_label.text = "B%d" % (block_idx + 1)
	block_label.custom_minimum_size = Vector2(50, 0)
	block_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	block_label.add_theme_font_size_override("font_size", 26)
	block_label.add_theme_color_override("font_color", _C_GOLD if (current_block or cleared_block) else _C_LOCKED)
	top_row.add_child(block_label)

	var checkpoint_cell: Control = null
	# Build 10 regular medallions on the top row; the 11th (checkpoint boss)
	# drops onto its own centered row below so it can't be clipped off-screen.
	for in_block in range(GameState.LEVELS_PER_BLOCK):
		var flat: int = block_idx * GameState.LEVELS_PER_BLOCK + in_block
		if flat >= chapter.levels.size():
			break
		var lvl: LevelResource = chapter.levels[flat]
		var cell := _build_level_cell(ch_idx, block_idx, in_block, lvl, cleared_block, current_block)
		if in_block == GameState.CHECKPOINT_LEVEL_INDEX:
			checkpoint_cell = cell
		else:
			top_row.add_child(cell)

	wrap.add_child(top_row)

	if checkpoint_cell != null:
		var boss_row := HBoxContainer.new()
		boss_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		boss_row.alignment = BoxContainer.ALIGNMENT_CENTER
		boss_row.add_child(checkpoint_cell)
		wrap.add_child(boss_row)

	# Replay-only rail: dim the whole thing so it visually recedes.
	if cleared_block and not current_block:
		wrap.modulate = Color(1, 1, 1, 0.65)

	return wrap

func _build_locked_rail_stub(block_idx: int) -> Control:
	var stub := PanelContainer.new()
	stub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.03, 0.06, 0.55)
	sb.border_color = _C_LOCKED
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	stub.add_theme_stylebox_override("panel", sb)
	var lbl := Label.new()
	lbl.text = "⛓  Block %d — sealed" % (block_idx + 1)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", _C_LOCKED)
	stub.add_child(lbl)
	return stub

func _build_level_cell(
	ch_idx: int,
	block_idx: int,
	in_block: int,
	lvl: LevelResource,
	cleared_block: bool,
	current_block: bool,
) -> Control:
	# Vertical stack: medallion button on top, stars (or lock) underneath.
	var cell := VBoxContainer.new()
	cell.alignment = BoxContainer.ALIGNMENT_CENTER
	cell.add_theme_constant_override("separation", 4)

	var btn := _build_level_button(ch_idx, block_idx, in_block, lvl)
	btn.name = "Medallion"
	var btn_wrap := CenterContainer.new()
	btn_wrap.add_child(btn)
	cell.add_child(btn_wrap)

	# Unlock rules:
	#  - Cleared block: every level tappable (replay).
	#  - Current block: only the next-up level is unlocked.
	var unlocked: bool
	if cleared_block:
		unlocked = true
	elif current_block:
		unlocked = in_block <= GameState.current_level_in_block
	else:
		unlocked = false
	btn.disabled = not unlocked

	var flat_lvl: int = block_idx * GameState.LEVELS_PER_BLOCK + in_block
	var completed: bool = GameState.is_level_completed(GameState.castle_index, ch_idx, flat_lvl)

	var stars_lbl := Label.new()
	stars_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stars_lbl.add_theme_font_size_override("font_size", 20)
	if completed:
		var stars: int = GameState.get_level_stars(GameState.castle_index, ch_idx, flat_lvl)
		var star_str := ""
		for s in range(stars):
			star_str += "★"
		for s in range(3 - stars):
			star_str += "☆"
		stars_lbl.text = star_str
		stars_lbl.add_theme_color_override("font_color", _C_GOLD)
	elif not unlocked:
		stars_lbl.text = "🔒"
		stars_lbl.add_theme_color_override("font_color", Color(0.55, 0.45, 0.40, 0.85))
	else:
		stars_lbl.text = "☆☆☆"
		stars_lbl.add_theme_color_override("font_color", Color(0.55, 0.45, 0.40, 0.7))
	cell.add_child(stars_lbl)
	return cell

func _build_level_button(ch_idx: int, block_idx: int, in_block: int, lvl: LevelResource) -> Button:
	var btn := Button.new()
	# Regular medallions shrunk to 60×60 so all 10 fit on one row inside the
	# chapter card without horizontal clipping. The checkpoint stays larger and
	# lives on its own row underneath (see _build_block_rail).
	var is_checkpoint: bool = lvl.is_checkpoint or lvl.is_boss
	var size: Vector2 = Vector2(60, 60)
	if is_checkpoint:
		size = Vector2(140, 84)
	btn.custom_minimum_size = size

	var label: String
	if is_checkpoint:
		label = "⚔  Boss"
		btn.add_theme_font_size_override("font_size", 36)
	else:
		label = "%d" % (in_block + 1)
		btn.add_theme_font_size_override("font_size", 28)
	btn.text = label

	# Per-state stylebox — medallions get their own look.
	var flat_lvl: int = block_idx * GameState.LEVELS_PER_BLOCK + in_block
	var completed: bool = GameState.is_level_completed(GameState.castle_index, ch_idx, flat_lvl)
	btn.add_theme_stylebox_override("normal", _medallion_style(_medallion_bg(completed, is_checkpoint), _C_GOLD, 3, 36))
	btn.add_theme_stylebox_override("hover", _medallion_style(_medallion_bg(completed, is_checkpoint).lightened(0.10), _C_GOLD_HOVER, 3, 36))
	btn.add_theme_stylebox_override("pressed", _medallion_style(_C_GOLD, _C_GOLD_DIM, 3, 36))
	btn.add_theme_stylebox_override("disabled", _medallion_style(Color(0.10, 0.08, 0.12, 0.70), Color(0.45, 0.38, 0.25, 0.55), 2, 36))
	btn.add_theme_stylebox_override("focus", _focus_ring(_C_GOLD_HOVER, 36))

	if is_checkpoint:
		btn.add_theme_color_override("font_color", _C_GOLD)
		btn.add_theme_color_override("font_hover_color", _C_GOLD_HOVER)
	else:
		btn.add_theme_color_override("font_color", _C_PARCHMENT)
		btn.add_theme_color_override("font_hover_color", _C_GOLD_HOVER)
	btn.add_theme_color_override("font_pressed_color", _C_INK)
	btn.add_theme_color_override("font_disabled_color", Color(0.55, 0.45, 0.40, 0.6))
	btn.add_theme_color_override("font_outline_color", _C_INK)
	btn.add_theme_constant_override("outline_size", 3)

	btn.tooltip_text = "%s — %s (HP %d, dmg %d)" % [lvl.level_name, lvl.enemy_name, lvl.enemy_max_hp, lvl.enemy_damage]
	btn.pressed.connect(_on_level_pressed.bind(ch_idx, block_idx, in_block))
	return btn

func _medallion_bg(completed: bool, is_boss: bool) -> Color:
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
	sb.content_margin_left = 6.0
	sb.content_margin_right = 6.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 4
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

func _on_level_pressed(ch_idx: int, block_idx: int, in_block: int) -> void:
	AudioBus.play_ui_click()
	Haptics.light_tap()
	GameState.set_current_pointer(ch_idx, block_idx, in_block)
	SceneRouter.goto_battle()

func _on_king_pressed() -> void:
	AudioBus.play_ui_click()
	Haptics.medium_tap()
	# King pointer: chapter_index = 3 keeps "is_current_level_king" true.
	GameState.set_current_pointer(3, 0, 0)
	SceneRouter.goto_battle()

func _on_back() -> void:
	AudioBus.play_ui_click()
	Haptics.light_tap()
	SceneRouter.goto_main_menu()
