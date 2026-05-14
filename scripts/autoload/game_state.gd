extends Node

signal progress_changed
signal castle_completed(castle_index: int)
signal save_loaded

const SAVE_PATH := "user://savegame.json"
const SAVE_TMP := "user://savegame.json.tmp"
const SAVE_VERSION := 1

var castle_index: int = 0
var chapter_index: int = 0
var level_index: int = 0
var completed_levels: Dictionary = {}
var level_stars: Dictionary = {}  # "c.ch.l" -> stars (1..3)
var player_max_hp: int = 100
var current_castle: CastleResource = null
var tutorial_seen: bool = false

func _ready() -> void:
	load_game()
	_ensure_castle()

func _ensure_castle() -> void:
	if current_castle == null:
		current_castle = CastleGenerator.generate(castle_index)

func mark_level_completed(c_idx: int, ch_idx: int, lvl_idx: int) -> void:
	var key := _key(c_idx, ch_idx, lvl_idx)
	completed_levels[key] = true
	emit_signal("progress_changed")
	save_game()

func mark_level_stars(c_idx: int, ch_idx: int, lvl_idx: int, stars: int) -> void:
	var key := _key(c_idx, ch_idx, lvl_idx)
	var existing: int = int(level_stars.get(key, 0))
	if stars > existing:
		level_stars[key] = stars
		save_game()

func get_level_stars(c_idx: int, ch_idx: int, lvl_idx: int) -> int:
	return int(level_stars.get(_key(c_idx, ch_idx, lvl_idx), 0))

func has_seen_tutorial() -> bool:
	return tutorial_seen

func mark_tutorial_seen() -> void:
	tutorial_seen = true
	save_game()

func is_level_completed(c_idx: int, ch_idx: int, lvl_idx: int) -> bool:
	return completed_levels.get(_key(c_idx, ch_idx, lvl_idx), false)

func is_level_unlocked(c_idx: int, ch_idx: int, lvl_idx: int) -> bool:
	# Level 0 of chapter 0 always unlocked; otherwise previous must be completed.
	if c_idx != castle_index:
		return false
	if ch_idx == 0 and lvl_idx == 0:
		return true
	if lvl_idx == 0:
		# Need previous chapter's boss done.
		return is_level_completed(c_idx, ch_idx - 1, 5)
	return is_level_completed(c_idx, ch_idx, lvl_idx - 1)

func is_chapter_unlocked(c_idx: int, ch_idx: int) -> bool:
	if c_idx != castle_index:
		return false
	if ch_idx == 0:
		return true
	return is_level_completed(c_idx, ch_idx - 1, 5)

func is_king_unlocked() -> bool:
	# King is unlocked when all 3 tower bosses (index 5 in chapters 0,1,2) done.
	for ch in range(3):
		if not is_level_completed(castle_index, ch, 5):
			return false
	return true

func advance_to_next_castle() -> void:
	castle_index += 1
	chapter_index = 0
	level_index = 0
	completed_levels.clear()
	current_castle = CastleGenerator.generate(castle_index)
	emit_signal("castle_completed", castle_index - 1)
	emit_signal("progress_changed")
	save_game()

func get_current_level() -> LevelResource:
	if current_castle == null:
		_ensure_castle()
	if chapter_index >= current_castle.chapters.size():
		return current_castle.king_level
	var chapter: ChapterResource = current_castle.chapters[chapter_index]
	return chapter.levels[level_index]

func is_current_level_king() -> bool:
	if current_castle == null:
		return false
	return chapter_index >= current_castle.chapters.size()

func set_current_pointer(ch_idx: int, lvl_idx: int) -> void:
	chapter_index = ch_idx
	level_index = lvl_idx

func get_king_level() -> LevelResource:
	return current_castle.king_level

func _key(c_idx: int, ch_idx: int, lvl_idx: int) -> String:
	return "%d.%d.%d" % [c_idx, ch_idx, lvl_idx]

func save_game() -> void:
	var data := {
		"version": SAVE_VERSION,
		"castle_index": castle_index,
		"chapter_index": chapter_index,
		"level_index": level_index,
		"player_max_hp": player_max_hp,
		"completed_levels": completed_levels,
		"level_stars": level_stars,
		"tutorial_seen": tutorial_seen,
	}
	var f := FileAccess.open(SAVE_TMP, FileAccess.WRITE)
	if f == null:
		push_warning("Could not open save tmp file")
		return
	f.store_string(JSON.stringify(data))
	f.close()
	var d := DirAccess.open("user://")
	if d != null:
		if d.file_exists("savegame.json"):
			d.remove("savegame.json")
		d.rename("savegame.json.tmp", "savegame.json")

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var raw := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Save file corrupted")
		return
	var data: Dictionary = parsed
	if int(data.get("version", 0)) != SAVE_VERSION:
		push_warning("Save version mismatch")
		return
	castle_index = int(data.get("castle_index", 0))
	chapter_index = int(data.get("chapter_index", 0))
	level_index = int(data.get("level_index", 0))
	player_max_hp = int(data.get("player_max_hp", 100))
	completed_levels = data.get("completed_levels", {})
	level_stars = data.get("level_stars", {})
	tutorial_seen = bool(data.get("tutorial_seen", false))
	emit_signal("save_loaded")

func reset_save() -> void:
	castle_index = 0
	chapter_index = 0
	level_index = 0
	completed_levels.clear()
	level_stars.clear()
	tutorial_seen = false
	player_max_hp = 100
	current_castle = CastleGenerator.generate(0)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.open("user://").remove("savegame.json")
	emit_signal("progress_changed")
