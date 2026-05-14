class_name LevelResource
extends Resource

@export var level_name: String = "Level"
@export var background_color: Color = Color(0.12, 0.10, 0.16)
@export var background_path: String = ""
@export var enemy_name: String = "Brigand"
@export var enemy_max_hp: int = 60
@export var enemy_damage: int = 6
@export var enemy_attack_interval: int = 1  # turns between enemy attacks
@export var is_boss: bool = false
@export var boss_modifier: BossModifier = null
@export var is_king: bool = false
@export var music_path: String = ""
# Optional path to a specific enemy sprite. If empty the BattleActor falls
# back to res://assets/characters/enemy.png.
@export var enemy_sprite_path: String = ""
