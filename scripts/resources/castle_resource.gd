class_name CastleResource
extends Resource

@export var castle_name: String = "Castle"
@export var castle_index: int = 0
@export var seed_value: int = 0
@export var difficulty_multiplier: float = 1.0
@export var chapters: Array[ChapterResource] = []
@export var king_level: LevelResource = null
