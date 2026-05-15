extends Control

# Phase F — Post-battle 1-of-3 upgrade picker.
#
# The scene file (upgrade_picker.tscn) carries just a Control root + theme
# reference. Card construction is done programmatically here so we can keep
# the picker visually consistent with the rest of the theme tokens without
# fighting the .tscn format for per-state styleboxes.

const _CHOICES_PER_OFFER: int = 3

const _C_INK := Color(0.07, 0.05, 0.09)
const _C_DUSK := Color(0.18, 0.14, 0.22)
const _C_PARCHMENT := Color(0.92, 0.85, 0.68)
const _C_GOLD := Color(0.95, 0.78, 0.30)
const _C_GOLD_HOVER := Color(1.00, 0.92, 0.55)
const _C_GOLD_DIM := Color(0.55, 0.40, 0.18)

var _offered: Array = []  # Array[RunUpgrade]
var _was_checkpoint: bool = false

func _ready() -> void:
	SafeArea.apply(self)
	RenderingServer.set_default_clear_color(Color(0.07, 0.05, 0.09))
	# Victory hands us a transient flag indicating whether the cleared level
	# was a checkpoint; if so, the player's chosen upgrade is locked into the
	# snapshot so it survives a future death.
	_was_checkpoint = GameState.pending_upgrade_locks
	GameState.pending_upgrade_locks = false
	_generate_offerings()
	_build_ui()

func _generate_offerings() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var pool: Array = [
		_make_upgrade(RunUpgrade.Kind.MAX_HP, 10, "+10 Max HP"),
		_make_upgrade(RunUpgrade.Kind.MAX_ARMOR, 2, "+2 Max Armor"),
		_make_upgrade(RunUpgrade.Kind.MAX_DAMAGE, 1, "+1 Damage"),
	]
	# Occasional rare HP roll — adds some replay variance even at this early stage.
	if rng.randf() < 0.25:
		pool.append(_make_upgrade(RunUpgrade.Kind.MAX_HP, 20, "+20 Max HP (Rare)"))
	pool.shuffle()
	_offered = pool.slice(0, _CHOICES_PER_OFFER)

func _make_upgrade(kind: int, magnitude: int, label: String) -> RunUpgrade:
	var u := RunUpgrade.new()
	u.kind = kind
	u.magnitude = magnitude
	u.label = label
	return u

func _build_ui() -> void:
	# Dim background.
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.03, 0.06, 0.95)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 36)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	var sigil := Label.new()
	sigil.text = "✶  ⚜  ✶"
	sigil.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sigil.add_theme_font_size_override("font_size", 42)
	sigil.add_theme_color_override("font_color", Color(0.78, 0.55, 0.22, 0.95))
	vbox.add_child(sigil)

	var title := Label.new()
	title.text = "Choose your reward"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", _C_GOLD)
	title.add_theme_color_override("font_outline_color", _C_INK)
	title.add_theme_constant_override("outline_size", 6)
	vbox.add_child(title)

	if _was_checkpoint:
		var sub := Label.new()
		sub.text = "Checkpoint cleared — this reward is locked in."
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.add_theme_font_size_override("font_size", 30)
		sub.add_theme_color_override("font_color", Color(0.82, 0.74, 0.54, 0.95))
		vbox.add_child(sub)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(row)

	for idx in range(_offered.size()):
		var u: RunUpgrade = _offered[idx]
		row.add_child(_build_card(u, idx))

func _build_card(u: RunUpgrade, idx: int) -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(280, 360)
	btn.focus_mode = Control.FOCUS_ALL
	btn.add_theme_stylebox_override("normal", _card_style(_card_bg(u.kind), _C_GOLD, 3))
	btn.add_theme_stylebox_override("hover", _card_style(_card_bg(u.kind).lightened(0.12), _C_GOLD_HOVER, 3))
	btn.add_theme_stylebox_override("pressed", _card_style(_C_GOLD, _C_GOLD_DIM, 3))
	btn.add_theme_stylebox_override("focus", _focus_ring(_C_GOLD_HOVER))
	btn.pressed.connect(_on_card_pressed.bind(idx))

	# Manually layout label + icon inside the button using a margin child.
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 20.0
	vbox.offset_right = -20.0
	vbox.offset_top = 24.0
	vbox.offset_bottom = -24.0
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vbox)

	var icon := ColorRect.new()
	icon.custom_minimum_size = Vector2(120, 120)
	icon.color = _icon_color(u.kind)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_wrap := CenterContainer.new()
	icon_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_wrap.add_child(icon)
	vbox.add_child(icon_wrap)

	var kind_label := Label.new()
	kind_label.text = _kind_name(u.kind)
	kind_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kind_label.add_theme_font_size_override("font_size", 34)
	kind_label.add_theme_color_override("font_color", _C_PARCHMENT)
	kind_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(kind_label)

	var mag_label := Label.new()
	mag_label.text = u.label if u.label != "" else "+%d" % u.magnitude
	mag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mag_label.add_theme_font_size_override("font_size", 42)
	mag_label.add_theme_color_override("font_color", _C_GOLD)
	mag_label.add_theme_color_override("font_outline_color", _C_INK)
	mag_label.add_theme_constant_override("outline_size", 4)
	mag_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(mag_label)

	return btn

func _kind_name(kind: int) -> String:
	match kind:
		RunUpgrade.Kind.MAX_HP: return "Max HP"
		RunUpgrade.Kind.MAX_ARMOR: return "Max Armor"
		RunUpgrade.Kind.MAX_DAMAGE: return "Damage"
	return "?"

func _icon_color(kind: int) -> Color:
	match kind:
		RunUpgrade.Kind.MAX_HP: return Color(0.85, 0.30, 0.30, 1.0)
		RunUpgrade.Kind.MAX_ARMOR: return Color(0.40, 0.62, 0.82, 1.0)
		RunUpgrade.Kind.MAX_DAMAGE: return Color(0.95, 0.78, 0.30, 1.0)
	return _C_DUSK

func _card_bg(kind: int) -> Color:
	# Same hue as the icon but heavily darkened — the card hints at its kind
	# without overpowering the gold trim.
	return _icon_color(kind).darkened(0.78)

func _card_style(bg: Color, border: Color, border_w: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.border_width_left = border_w
	sb.border_width_right = border_w
	sb.border_width_top = border_w
	sb.border_width_bottom = border_w
	sb.corner_radius_top_left = 16
	sb.corner_radius_top_right = 16
	sb.corner_radius_bottom_left = 16
	sb.corner_radius_bottom_right = 16
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 8
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 12.0
	return sb

func _focus_ring(c: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = c
	sb.border_width_left = 3
	sb.border_width_right = 3
	sb.border_width_top = 3
	sb.border_width_bottom = 3
	sb.corner_radius_top_left = 16
	sb.corner_radius_top_right = 16
	sb.corner_radius_bottom_left = 16
	sb.corner_radius_bottom_right = 16
	return sb

func _on_card_pressed(idx: int) -> void:
	if idx < 0 or idx >= _offered.size():
		return
	AudioBus.play_ui_click()
	Haptics.medium_tap()
	# Checkpoint reward gets locked into the snapshot so it survives a
	# subsequent death within this chapter.
	GameState.apply_run_upgrade(_offered[idx], _was_checkpoint)
	SceneRouter.goto_chapter_map()
