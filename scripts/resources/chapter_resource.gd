class_name ChapterResource
extends Resource

@export var chapter_name: String = "Chapter"
@export var theme: String = "forest"
# 5 regular levels + 1 boss = 6 total
# v2: this array becomes 55 entries (5 blocks of 10 regular + 1 checkpoint). Phase E migration.
@export var levels: Array[LevelResource] = []
# One-line flavor text shown under the chapter title on the chapter map.
@export var motto: String = ""
