class_name BoardItem
extends Resource

enum EffectKind {
	ENEMY_ARMOR_DEBUFF,
	PLAYER_RESTORE_ARMOR,
	PLAYER_HEAL,
	PLAYER_ATTACK_BUFF,
	ENEMY_ACID_DOT,
	ENEMY_FIRE_DOT,
}

enum Target { PLAYER, ENEMY }

@export var id: String = ""
@export var display_name: String = ""
@export var integrity: int = 1
@export var sprite_path: String = ""
@export var effect_kind: int = EffectKind.PLAYER_HEAL
@export var effect_magnitude: float = 0.0
@export var effect_duration: float = 0.0
@export var spawn_weight: float = 1.0
@export var target: int = Target.PLAYER
@export var tint: Color = Color.WHITE
