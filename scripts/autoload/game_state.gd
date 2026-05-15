extends Node

signal progress_changed
signal castle_completed(castle_index: int)
signal save_loaded

const SAVE_PATH := "user://savegame.json"
const SAVE_TMP := "user://savegame.json.tmp"
# Bumped to 2 in Phase E. v1 saves are wiped on first load of v2 build.
const SAVE_VERSION := 2

# Each chapter holds 5 blocks of 11 levels (10 regular + 1 checkpoint).
const BLOCKS_PER_CHAPTER := 5
const LEVELS_PER_BLOCK := 11  # 10 regular + 1 checkpoint at index 10
const CHECKPOINT_LEVEL_INDEX := 10
const FINAL_CHECKPOINT_IDX := 4  # block 4's checkpoint == tower boss

var castle_index: int = 0
var chapter_index: int = 0
var level_index: int = 0
var completed_levels: Dictionary = {}
var level_stars: Dictionary = {}  # "c.ch.l" -> stars (1..3)
var player_max_hp: int = 100
var current_castle: CastleResource = null
var tutorial_seen: bool = false
var music_enabled: bool = true
var sfx_enabled: bool = true

# --- Phase E additions ---
# Flat checkpoint indices (chapter * BLOCKS_PER_CHAPTER + checkpoint_idx) cleared this castle.
var completed_checkpoints: Array[int] = []
# { castle: int, chapter: int, checkpoint_idx: int (0..4) }
var last_checkpoint: Dictionary = {}
var run_upgrades: Array = []  # Array[RunUpgrade] accumulated this run
var run_upgrades_locked_at_checkpoint: Array = []  # locked at most recent checkpoint
var player_max_armor: int = 0
var player_base_damage_bonus: int = 0
var current_level_in_block: int = 0  # 0..10 (10 = checkpoint level)
var current_block_index: int = 0  # 0..4 within current chapter
var save_v1_wipe_notice_shown: bool = true
# Transient flag set by load_game when it wiped a pre-v2 save; main menu
# reads this and shows a one-time banner.
var save_was_wiped_this_launch: bool = false

# Transient — set by battle.gd right before goto_victory so the victory
# scene can show level-specific copy. Not persisted.
var last_battle_result: Dictionary = {}
# Transient: set by victory.gd before routing to the upgrade picker so the
# picker can lock a checkpoint reward into the snapshot.
var pending_upgrade_locks: bool = false

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

# --- Phase E: 11-block progression unlock rules ---

func is_level_unlocked(c_idx: int, ch_idx: int, block_idx: int, level_in_block: int) -> bool:
	# Phase E uses 4-tuple addressing: (castle, chapter, block, level-in-block).
	# All callers updated in the Phase E migration.
	if c_idx != castle_index:
		return false
	if not is_chapter_unlocked(c_idx, ch_idx):
		return false
	if ch_idx < chapter_index:
		# Whole chapter already cleared (we've advanced past it) — fully replayable.
		return true
	if ch_idx > chapter_index:
		return false
	if block_idx < current_block_index:
		# Already-cleared blocks in the current chapter remain unlocked for replay.
		return true
	if block_idx > current_block_index:
		# Future blocks within this chapter are locked.
		return false
	# Within the current block, only the next-up level is unlocked.
	return level_in_block <= current_level_in_block

func is_chapter_unlocked(c_idx: int, ch_idx: int) -> bool:
	if c_idx != castle_index:
		return false
	if ch_idx == 0:
		return true
	# Need previous chapter's final checkpoint (idx 4) cleared.
	return has_checkpoint_cleared(ch_idx - 1, FINAL_CHECKPOINT_IDX)

func has_checkpoint_cleared(ch_idx: int, checkpoint_idx: int) -> bool:
	var flat: int = ch_idx * BLOCKS_PER_CHAPTER + checkpoint_idx
	return completed_checkpoints.has(flat)

func is_king_unlocked() -> bool:
	# King is unlocked when chapter 2's final checkpoint (the keep tower boss) is cleared.
	return has_checkpoint_cleared(2, FINAL_CHECKPOINT_IDX)

func is_ready_for_king() -> bool:
	return is_king_unlocked()

func advance_to_next_castle() -> void:
	castle_index += 1
	chapter_index = 0
	level_index = 0
	current_block_index = 0
	current_level_in_block = 0
	completed_levels.clear()
	completed_checkpoints.clear()
	last_checkpoint = {}
	run_upgrades.clear()
	run_upgrades_locked_at_checkpoint.clear()
	# Reset derived stats — fresh castle, fresh run.
	player_max_hp = 100
	player_max_armor = 0
	player_base_damage_bonus = 0
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
	# Translate (current_block_index, current_level_in_block) to flat index.
	var flat: int = current_block_index * LEVELS_PER_BLOCK + current_level_in_block
	# Also keep legacy `level_index` pointer in sync.
	level_index = flat
	if flat >= chapter.levels.size():
		# Defensive: if a checkpoint flat index overshoots (e.g. a tower boss
		# generator regression), fall back to the last entry.
		return chapter.levels[chapter.levels.size() - 1]
	return chapter.levels[flat]

func is_current_level_king() -> bool:
	if current_castle == null:
		return false
	return chapter_index >= current_castle.chapters.size()

func set_current_pointer(ch_idx: int, block_idx: int, level_in_block: int = -1) -> void:
	chapter_index = ch_idx
	if level_in_block < 0:
		# Legacy 2-arg call (ch, flat lvl_idx). Decode.
		var lvl_idx: int = block_idx
		current_block_index = lvl_idx / LEVELS_PER_BLOCK
		current_level_in_block = lvl_idx % LEVELS_PER_BLOCK
		level_index = lvl_idx
	else:
		current_block_index = block_idx
		current_level_in_block = level_in_block
		level_index = block_idx * LEVELS_PER_BLOCK + level_in_block

func get_king_level() -> LevelResource:
	return current_castle.king_level

func _key(c_idx: int, ch_idx: int, lvl_idx: int) -> String:
	return "%d.%d.%d" % [c_idx, ch_idx, lvl_idx]

# --- Phase E: progression mutation helpers ---

func apply_run_upgrade(upgrade: RunUpgrade, lock_immediately: bool = false) -> void:
	if upgrade == null:
		return
	run_upgrades.append(upgrade)
	match upgrade.kind:
		RunUpgrade.Kind.MAX_HP:
			player_max_hp += upgrade.magnitude
		RunUpgrade.Kind.MAX_ARMOR:
			player_max_armor += upgrade.magnitude
		RunUpgrade.Kind.MAX_DAMAGE:
			player_base_damage_bonus += upgrade.magnitude
	if lock_immediately:
		run_upgrades_locked_at_checkpoint.append(upgrade)
	save_game()

func lock_upgrades_at_checkpoint() -> void:
	run_upgrades_locked_at_checkpoint = run_upgrades.duplicate()

func mark_checkpoint_cleared(ch_idx: int, checkpoint_idx: int) -> void:
	last_checkpoint = {
		"castle": castle_index,
		"chapter": ch_idx,
		"checkpoint_idx": checkpoint_idx,
	}
	var flat: int = ch_idx * BLOCKS_PER_CHAPTER + checkpoint_idx
	if not completed_checkpoints.has(flat):
		completed_checkpoints.append(flat)
	lock_upgrades_at_checkpoint()
	save_game()

func advance_level() -> void:
	# Advance pointer after a victory. Handles block→chapter→king transitions.
	if current_level_in_block < CHECKPOINT_LEVEL_INDEX:
		current_level_in_block += 1
		level_index = current_block_index * LEVELS_PER_BLOCK + current_level_in_block
		save_game()
		return
	# Just finished the block's checkpoint level — advance to next block.
	current_block_index += 1
	current_level_in_block = 0
	if current_block_index > FINAL_CHECKPOINT_IDX:
		# Block 4 (tower boss) cleared — advance to next chapter or king.
		current_block_index = 0
		chapter_index += 1
	level_index = current_block_index * LEVELS_PER_BLOCK + current_level_in_block
	save_game()

func rollback_to_checkpoint() -> void:
	# Death rollback. Two flavours:
	#  - No usable in-chapter checkpoint: rewind to chapter start, wipe run upgrades.
	#  - In-chapter checkpoint exists: rewind to checkpoint+1, restore locked upgrades.
	var in_chapter_cp: bool = (
		not last_checkpoint.is_empty()
		and int(last_checkpoint.get("castle", -1)) == castle_index
		and int(last_checkpoint.get("chapter", -1)) == chapter_index
	)
	if not in_chapter_cp:
		current_block_index = 0
		current_level_in_block = 0
		run_upgrades.clear()
		# Clear locked snapshot too — nothing in this chapter has been locked yet.
		run_upgrades_locked_at_checkpoint.clear()
	else:
		var cp_idx: int = int(last_checkpoint.get("checkpoint_idx", 0))
		current_block_index = cp_idx + 1
		current_level_in_block = 0
		run_upgrades = run_upgrades_locked_at_checkpoint.duplicate()
	level_index = current_block_index * LEVELS_PER_BLOCK + current_level_in_block
	_reapply_run_upgrades_to_stats()
	save_game()

func _reapply_run_upgrades_to_stats() -> void:
	# Reset derived stats to baseline, then apply each surviving run upgrade.
	player_max_hp = 100
	player_max_armor = 0
	player_base_damage_bonus = 0
	for u in run_upgrades:
		if u == null:
			continue
		match u.kind:
			RunUpgrade.Kind.MAX_HP:
				player_max_hp += u.magnitude
			RunUpgrade.Kind.MAX_ARMOR:
				player_max_armor += u.magnitude
			RunUpgrade.Kind.MAX_DAMAGE:
				player_base_damage_bonus += u.magnitude

func dismiss_save_wipe_notice() -> void:
	save_was_wiped_this_launch = false
	save_v1_wipe_notice_shown = true
	save_game()

# --- Save serialization ---

func save_game() -> void:
	var data := {
		"version": SAVE_VERSION,
		"castle_index": castle_index,
		"chapter_index": chapter_index,
		"level_index": level_index,
		"player_max_hp": player_max_hp,
		"player_max_armor": player_max_armor,
		"player_base_damage_bonus": player_base_damage_bonus,
		"completed_levels": completed_levels,
		"level_stars": level_stars,
		"completed_checkpoints": completed_checkpoints,
		"last_checkpoint": last_checkpoint,
		"run_upgrades": _serialize_upgrades(run_upgrades),
		"run_upgrades_locked_at_checkpoint": _serialize_upgrades(run_upgrades_locked_at_checkpoint),
		"current_block_index": current_block_index,
		"current_level_in_block": current_level_in_block,
		"tutorial_seen": tutorial_seen,
		"music_enabled": music_enabled,
		"sfx_enabled": sfx_enabled,
		"save_v1_wipe_notice_shown": save_v1_wipe_notice_shown,
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
		# Fresh save — don't show the v1 wipe banner.
		save_v1_wipe_notice_shown = true
		save_was_wiped_this_launch = false
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
	var version: int = int(data.get("version", 1))
	if version < SAVE_VERSION:
		# Pre-v2 save → wipe, remember to show one-time banner on main menu.
		reset_save(false)
		save_v1_wipe_notice_shown = false
		save_was_wiped_this_launch = true
		save_game()
		return
	if version > SAVE_VERSION:
		push_warning("Save version newer than build (%d > %d) — ignoring." % [version, SAVE_VERSION])
		return

	castle_index = int(data.get("castle_index", 0))
	chapter_index = int(data.get("chapter_index", 0))
	level_index = int(data.get("level_index", 0))
	player_max_hp = int(data.get("player_max_hp", 100))
	player_max_armor = int(data.get("player_max_armor", 0))
	player_base_damage_bonus = int(data.get("player_base_damage_bonus", 0))
	completed_levels = data.get("completed_levels", {})
	level_stars = data.get("level_stars", {})
	var cp_raw: Variant = data.get("completed_checkpoints", [])
	completed_checkpoints = []
	if cp_raw is Array:
		for v in cp_raw:
			completed_checkpoints.append(int(v))
	last_checkpoint = data.get("last_checkpoint", {})
	run_upgrades = _deserialize_upgrades(data.get("run_upgrades", []))
	run_upgrades_locked_at_checkpoint = _deserialize_upgrades(
		data.get("run_upgrades_locked_at_checkpoint", [])
	)
	current_block_index = int(data.get("current_block_index", 0))
	current_level_in_block = int(data.get("current_level_in_block", 0))
	tutorial_seen = bool(data.get("tutorial_seen", false))
	music_enabled = bool(data.get("music_enabled", true))
	sfx_enabled = bool(data.get("sfx_enabled", true))
	save_v1_wipe_notice_shown = bool(data.get("save_v1_wipe_notice_shown", true))
	save_was_wiped_this_launch = false
	emit_signal("save_loaded")

func _serialize_upgrades(arr: Array) -> Array:
	var out: Array = []
	for u in arr:
		if u == null:
			continue
		out.append({"kind": int(u.kind), "magnitude": int(u.magnitude), "label": String(u.label)})
	return out

func _deserialize_upgrades(raw: Variant) -> Array:
	var out: Array = []
	if not (raw is Array):
		return out
	for entry in raw:
		if not (entry is Dictionary):
			continue
		var u := RunUpgrade.new()
		u.kind = int(entry.get("kind", RunUpgrade.Kind.MAX_HP))
		u.magnitude = int(entry.get("magnitude", 0))
		u.label = String(entry.get("label", ""))
		out.append(u)
	return out

func reset_save(persist: bool = true) -> void:
	castle_index = 0
	chapter_index = 0
	level_index = 0
	current_block_index = 0
	current_level_in_block = 0
	completed_levels.clear()
	level_stars.clear()
	completed_checkpoints = []
	last_checkpoint = {}
	run_upgrades = []
	run_upgrades_locked_at_checkpoint = []
	tutorial_seen = false
	player_max_hp = 100
	player_max_armor = 0
	player_base_damage_bonus = 0
	# Banner already shown / not applicable after a fresh reset.
	save_v1_wipe_notice_shown = true
	save_was_wiped_this_launch = false
	current_castle = CastleGenerator.generate(0)
	if persist:
		if FileAccess.file_exists(SAVE_PATH):
			DirAccess.open("user://").remove("savegame.json")
	emit_signal("progress_changed")
