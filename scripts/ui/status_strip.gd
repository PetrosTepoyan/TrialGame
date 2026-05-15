class_name StatusStrip
extends HBoxContainer

# Small row of badges showing the current status effects on an actor (e.g.,
# "Burn 2" / "Stun 1"). Re-renders on every status_changed signal.

@export var align_right: bool = false

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
		var lbl := Label.new()
		lbl.text = "%s %d" % [StatusEffect.kind_to_string(fx.kind), fx.rounds_remaining]
		lbl.add_theme_font_size_override("font_size", 32)
		lbl.add_theme_color_override("font_color", _color_for_kind(fx.kind))
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		lbl.add_theme_constant_override("outline_size", 4)
		add_child(lbl)

func _color_for_kind(kind: int) -> Color:
	match kind:
		StatusEffect.Kind.BURN: return Color(1.0, 0.50, 0.20)
		StatusEffect.Kind.SWARM: return Color(0.55, 0.85, 0.40)
		StatusEffect.Kind.COLD: return Color(0.55, 0.80, 1.00)
		StatusEffect.Kind.BLEED: return Color(0.95, 0.30, 0.40)
		StatusEffect.Kind.STUN: return Color(1.00, 0.92, 0.40)
		StatusEffect.Kind.DEFENSE_DEBUFF: return Color(0.85, 0.55, 1.00)
	return Color.WHITE
