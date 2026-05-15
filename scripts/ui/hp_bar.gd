class_name HpBar
extends Control

@export var actor_path: NodePath
@export var bar_color: Color = Color(0.85, 0.20, 0.20)
@export var flip_fill_direction: bool = false
@export var actor_name: String = "Hero"

# Bg is a Panel (was ColorRect) so we can pin an ornate gold-rim StyleBoxFlat
# on it. Fill stays a ColorRect — its color is the hero/enemy bar tint.
@onready var _bg: Control = $Bg
@onready var _fill: ColorRect = $Bg/Fill
@onready var _label: Label = $Bg/Label
@onready var _armor_label: Label = $ArmorLabel

var _actor: CombatActor
var _last_hp: int = 0
var _max_hp: int = 1
var _fill_tween: Tween = null

func _ready() -> void:
	if actor_path != NodePath():
		_actor = get_node_or_null(actor_path) as CombatActor
	if _actor != null:
		bind(_actor)
	_fill.color = bar_color
	_update_label()

func bind(actor: CombatActor) -> void:
	_actor = actor
	_actor.hp_changed.connect(_on_hp_changed)
	_actor.armor_changed.connect(_on_armor_changed)
	_last_hp = actor.current_hp
	_max_hp = actor.max_hp
	_on_hp_changed(actor.current_hp, actor.max_hp)
	_on_armor_changed(actor.armor + actor.inherent_armor)

func _on_hp_changed(current_hp: int, max_hp: int) -> void:
	_last_hp = current_hp
	_max_hp = max_hp
	var pct: float = float(current_hp) / float(max(1, max_hp))
	# Kill any in-flight fill tween so rapid hits don't fight; ease-out feels
	# more like blood draining than a hard linear pop.
	if _fill_tween != null and _fill_tween.is_valid():
		_fill_tween.kill()
	_fill_tween = create_tween()
	_fill_tween.tween_property(self, "_fill_pct", pct, 0.35)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_update_label()

func _on_armor_changed(armor_total: int) -> void:
	if _armor_label != null:
		_armor_label.text = ("ARM %d" % armor_total) if armor_total > 0 else ""

var _fill_pct: float = 1.0:
	set(value):
		_fill_pct = clamp(value, 0.0, 1.0)
		_apply_fill()

func _apply_fill() -> void:
	if _fill == null or _bg == null:
		return
	var w: float = _bg.size.x * _fill_pct
	if flip_fill_direction:
		_fill.position = Vector2(_bg.size.x - w, 0)
	else:
		_fill.position = Vector2.ZERO
	_fill.size = Vector2(w, _bg.size.y)

func _update_label() -> void:
	if _label != null:
		_label.text = "%s — %d / %d" % [actor_name, _last_hp, _max_hp]
