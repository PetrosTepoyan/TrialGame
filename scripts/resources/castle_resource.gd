class_name CastleResource
extends Resource

@export var castle_name: String = "Castle"
@export var castle_index: int = 0
@export var seed_value: int = 0
@export var difficulty_multiplier: float = 1.0
@export var chapters: Array[ChapterResource] = []
@export var king_level: LevelResource = null
# Lore line shown under the castle name on the chapter map.
@export var subtitle: String = ""
# Short epithet for the king (e.g. "The Iron-Crowned"). Combined with king_level.enemy_name.
@export var king_epithet: String = ""
