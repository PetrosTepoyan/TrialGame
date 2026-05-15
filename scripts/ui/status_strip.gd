class_name StatusStrip
extends HBoxContainer

# Small row of badges showing the current status effects on an actor (e.g.,
# "Burn 2" / "Stun 1"). Each badge is a dusk-and-gold framed PanelContainer
# matching the rest of the medieval UI.

@export var align_right: bool = false

const _C_INK := Color(0.07, 0.05, 0.09)
const _C_DUSK := Color(0.18, 0.14, 0.22, 0.95)
const _C_GOLD_RIM := Color(0.95, 0.78, 0.30, 0.85)

func bind(actor: CombatActor) -> void:
	actor.status_changed.connect(_on_status_changed)
	_render(actor.active_effects)

func _on_status_changed(effects: Array) -> void:
	_render(effects)

func _render(effects: Array) -> void:
	for c in get_children():
		c.queue_free()
	if effects.is_empty():
		return
	for fx_v in effects:
		var fx: StatusEffect = fx_v
		add_child(_make_badge(fx))

func _make_badge(fx: StatusEffect) -> Control:
	var icon_color: Color = _color_for_kind(fx.kind)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _badge_style(icon_color))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	panel.add_child(row)

	var icon_lbl := Label.new()
	icon_lbl.text = StatusEffect.kind_to_string(fx.kind)
	icon_lbl.add_theme_font_size_override("font_size", 28)
	icon_lbl.add_theme_color_override("font_color", icon_color)
	icon_lbl.add_theme_color_override("font_outline_color", _C_INK)
	icon_lbl.add_theme_constant_override("outline_size", 4)
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(icon_lbl)

	var count := Label.new()
	# Seconds-based durations as of Phase B; round to int for the badge.
	count.text = "%ds" % int(round(fx.seconds_remaining))
	count.add_theme_font_size_override("font_size", 28)
	count.add_theme_color_override("font_color", Color(0.92, 0.85, 0.68, 1))
	count.add_theme_color_override("font_outline_color", _C_INK)
	count.add_theme_constant_override("outline_size", 4)
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(count)
	return panel

func _badge_style(rim: Color) -> StyleBoxFlat:
	# Dusk-fill badge with a gold-ish rim that tints toward the effect's color
	# (e.g., burn-orange rim on the burn badge).
	var sb := StyleBoxFlat.new()
	sb.bg_color = _C_DUSK
	# Blend gold with the kind color so each effect has its own accent.
	sb.border_color = Color(
		(rim.r + _C_GOLD_RIM.r) * 0.5,
		(rim.g + _C_GOLD_RIM.g) * 0.5,
		(rim.b + _C_GOLD_RIM.b) * 0.5,
		_C_GOLD_RIM.a,
	)
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	return sb

func _color_for_kind(kind: int) -> Color:
	match kind:
		StatusEffect.Kind.BURN: return Color(1.0, 0.50, 0.20)
		StatusEffect.Kind.SWARM: return Color(0.55, 0.85, 0.40)
		StatusEffect.Kind.COLD: return Color(0.55, 0.80, 1.00)
		StatusEffect.Kind.BLEED: return Color(0.95, 0.30, 0.40)
		StatusEffect.Kind.STUN: return Color(1.00, 0.92, 0.40)
		StatusEffect.Kind.DEFENSE_DEBUFF: return Color(0.85, 0.55, 1.00)
	return Color.WHITE
