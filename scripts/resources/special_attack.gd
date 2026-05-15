class_name SpecialAttack
extends Resource

@export var id: String = ""
@export var level: int = 1
@export var base_damage: int = 0
@export var status_on_hit: StatusEffect = null
@export var bypass_armor: bool = false
@export var animation_id: String = ""
@export var button_color: Color = Color.WHITE
@export var stun_seconds: float = 0.0
