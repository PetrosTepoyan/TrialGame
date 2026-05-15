class_name CastleGenerator
extends Object

# Chapter 0 / 1 / 2 have fixed thematic identities — outer wood, the walls,
# the inner keep. Names, mottos, and level pools are picked per-chapter so the
# game reads like a siege progressing inward, not "Chapter 1, 2, 3".

const CHAPTER_THEMES := ["forest", "wall", "keep"]

# --- Difficulty curve ---
#
# Per-chapter level pacing: 5 regular skirmishes + tower boss. The intent:
#   - Levels 1-2: approachable warmups. Low HP, weak damage.
#   - Levels 3-4: challenging. HP bumps, damage bumps.
#   - Level 5: climactic — last fight before the tower. Real teeth.
#   - Tower boss: a wall, but beatable.
#   - King: a true wall — heavy HP, heavy armor, plate damage.
#
# Curves are expressed as per-level multipliers applied on top of the chapter
# baseline. Editing these tables tunes the game; the generator's API shape
# (LevelResource fields) is unchanged.
#
# Index = level-in-block (0..9). 10 regular battles per checkpoint block.
# Phase E extended the curve from 5 entries → 10 to span a full checkpoint block.
const LEVEL_HP_CURVE: Array[float] = [0.70, 0.75, 0.85, 0.90, 1.00, 1.05, 1.15, 1.20, 1.30, 1.40]
const LEVEL_DMG_CURVE: Array[float] = [0.60, 0.70, 0.80, 0.90, 1.00, 1.10, 1.20, 1.30, 1.40, 1.50]
# Chapter baseline HP/dmg before per-level curve. Chapter 0 is the gentlest.
const CHAPTER_BASE_HP: Array[float] = [60.0, 110.0, 200.0]
const CHAPTER_BASE_DMG: Array[float] = [5.0, 8.5, 11.5]
# Tower boss (5th / final checkpoint of each chapter): per-chapter HP/dmg.
const TOWER_HP_BY_CHAPTER: Array[float] = [380.0, 560.0, 800.0]
const TOWER_DMG_BY_CHAPTER: Array[float] = [16.0, 24.0, 34.0]
# In-chapter checkpoints (1st..4th) — smaller bosses gating each block.
const CHECKPOINT_HP_BY_CHAPTER: Array[float] = [240.0, 360.0, 520.0]
const CHECKPOINT_DMG_BY_CHAPTER: Array[float] = [12.0, 18.0, 26.0]
# King: the wall.
const KING_HP: float = 620.0
const KING_DMG: float = 17.0
# v2 progression: 5 blocks × 11 levels (10 regular + 1 checkpoint) per chapter.
const BLOCKS_PER_CHAPTER := 5
const LEVELS_PER_BLOCK := 10
const FINAL_CHECKPOINT_IDX := 4

const CHAPTER_NAMES := [
	["The Outer Wood", "The Black Pines", "The Hunting Wood", "The Thornwood"],
	["The Curtain Wall", "The Gatehouse", "The Bailey", "The Battlements"],
	["The Inner Keep", "The Great Hall", "The Drum Tower", "The Donjon"],
]

const CHAPTER_MOTTOS := [
	[
		"Where the King's wardens watch the road.",
		"Birch and bramble — and arrows in the dark.",
		"Outriders before the walls.",
	],
	[
		"Murder-holes above, spears below.",
		"Stone holds where men do not.",
		"Where the siege learns its name.",
	],
	[
		"Lamplight, oaths, and the long stair up.",
		"Beyond this wall, only the throne.",
		"The Warden of the Keep does not sleep.",
	],
]

const LEVEL_NAMES := [
	# Chapter 0 — outer wood
	[
		"Scout Patrol", "Forest Ambush", "Crossroads",
		"Outrider's Camp", "The Treeline",
	],
	# Chapter 1 — walls
	[
		"The Gate Approach", "Murder-Hole", "Wall Walk",
		"The Sally Port", "Under the Banner",
	],
	# Chapter 2 — keep
	[
		"The Stair", "Antechamber", "Cloister",
		"Captain's Watch", "The Inner Doors",
	],
]

const TOWER_NAMES := ["Watchtower", "Drum Tower", "Keep"]
const TOWER_BOSS_TITLES := ["Warden of the Watch", "Warden of the Drum", "Warden of the Keep"]

const ENEMY_NAMES := [
	["Brigand", "Outlaw", "Marauder", "Deserter", "Scout", "Forest Stalker"],
	["Footman", "Pikeman", "Crossbowman", "Knight Errant", "Sergeant", "Wall Guard"],
	["Captain", "Lieutenant", "Champion", "Royal Veteran", "Hearthguard", "Bannerman"],
]

# Castle name + lore line pulled in lockstep by castle_index.
const CASTLE_NAMES := [
	"The Black Spire",
	"Caer Dûn",
	"Stoneraven Hold",
	"Wyrmshold",
	"Greycrown",
	"Ironreach",
	"Castle Mournfell",
	"The Sable Keep",
]
const CASTLE_SUBTITLES := [
	"Three towers, then the throne. Cut your way in.",
	"They say no army has ever passed its gate. You are no army.",
	"The stones remember the last lord who tried this.",
	"The wyrm-banner has not fallen in a hundred years.",
	"Behind these walls, a crown waits — and the man wearing it.",
	"Iron at the gate. Iron in the halls. Iron in the King.",
	"The bells toll for the siege, not the besieger.",
	"You will be the first to reach the throne. Or the next name on the wall.",
]

const KING_NAMES := [
	"King Aldric", "King Mordrek", "King Sigwald",
	"King Tharon", "King Valenor", "King Coreth",
	"King Belkor", "King Hadrius",
]
const KING_EPITHETS := [
	"The Iron-Crowned", "The Black Wolf", "The Pale Sovereign",
	"Of the Long Stair", "The Last Wyrm-King", "The Vow-Breaker",
	"Of the Hollow Throne", "The Crowned Hound",
]

static func generate(castle_index: int) -> CastleResource:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337 + castle_index * 7919
	var castle := CastleResource.new()
	castle.castle_index = castle_index
	castle.seed_value = int(rng.seed)
	castle.castle_name = CASTLE_NAMES[castle_index % CASTLE_NAMES.size()]
	castle.subtitle = CASTLE_SUBTITLES[castle_index % CASTLE_SUBTITLES.size()]
	castle.difficulty_multiplier = 1.0 + 0.15 * castle_index

	for ch_idx in range(3):
		var ch := ChapterResource.new()
		var name_pool: Array = CHAPTER_NAMES[ch_idx]
		var motto_pool: Array = CHAPTER_MOTTOS[ch_idx]
		ch.chapter_name = name_pool[rng.randi() % name_pool.size()]
		ch.motto = motto_pool[rng.randi() % motto_pool.size()]
		ch.theme = CHAPTER_THEMES[ch_idx]
		ch.levels = []
		# 5 blocks × 11 entries (10 regular battles + 1 checkpoint). Total 55.
		for block_idx in range(BLOCKS_PER_CHAPTER):
			for in_block in range(LEVELS_PER_BLOCK):
				var lvl := LevelResource.new()
				lvl.level_name = _regular_level_name(ch_idx, block_idx, in_block, rng)
				lvl.background_color = _background_for_theme(ch.theme, rng)
				lvl.background_path = _background_path_for_chapter(ch_idx)
				lvl.enemy_name = _enemy_name_for_chapter(ch_idx, rng)
				lvl.enemy_sprite_path = _regular_enemy_sprite_for_chapter(ch_idx)
				# Curve-driven HP/dmg. Per-level multipliers ramp across the
				# 10-level block; block_idx layers an additional difficulty
				# scalar so block 4 lvl 9 isn't equal to block 0 lvl 9.
				var chapter_base_hp: float = CHAPTER_BASE_HP[clampi(ch_idx, 0, CHAPTER_BASE_HP.size() - 1)]
				var chapter_base_dmg: float = CHAPTER_BASE_DMG[clampi(ch_idx, 0, CHAPTER_BASE_DMG.size() - 1)]
				var hp_mult: float = LEVEL_HP_CURVE[clampi(in_block, 0, LEVEL_HP_CURVE.size() - 1)]
				var dmg_mult: float = LEVEL_DMG_CURVE[clampi(in_block, 0, LEVEL_DMG_CURVE.size() - 1)]
				var block_scalar: float = 1.0 + block_idx * 0.20
				lvl.enemy_max_hp = int(chapter_base_hp * hp_mult * block_scalar * castle.difficulty_multiplier)
				lvl.enemy_damage = int(chapter_base_dmg * dmg_mult * block_scalar * castle.difficulty_multiplier)
				lvl.enemy_attack_interval = 1
				lvl.is_boss = false
				lvl.is_checkpoint = false
				lvl.checkpoint_index = -1
				ch.levels.append(lvl)
			# Checkpoint level — 11th entry of each block.
			var cp := LevelResource.new()
			var is_final_cp: bool = block_idx == FINAL_CHECKPOINT_IDX
			if is_final_cp:
				cp.level_name = "%s — %s" % [TOWER_NAMES[ch_idx], TOWER_BOSS_TITLES[ch_idx]]
				cp.enemy_name = TOWER_BOSS_TITLES[ch_idx]
				cp.enemy_sprite_path = _boss_sprite_path(ch_idx)
				var tower_hp: float = TOWER_HP_BY_CHAPTER[clampi(ch_idx, 0, TOWER_HP_BY_CHAPTER.size() - 1)]
				var tower_dmg: float = TOWER_DMG_BY_CHAPTER[clampi(ch_idx, 0, TOWER_DMG_BY_CHAPTER.size() - 1)]
				cp.enemy_max_hp = int(tower_hp * castle.difficulty_multiplier)
				cp.enemy_damage = int(tower_dmg * castle.difficulty_multiplier)
				cp.is_boss = true
				cp.boss_modifier = _make_boss_modifier(ch_idx, castle.difficulty_multiplier)
			else:
				cp.level_name = _in_chapter_checkpoint_name(ch_idx, block_idx)
				cp.enemy_name = _checkpoint_enemy_name(ch_idx, block_idx, rng)
				cp.enemy_sprite_path = _boss_sprite_path(ch_idx)
				var cp_hp_base: float = CHECKPOINT_HP_BY_CHAPTER[clampi(ch_idx, 0, CHECKPOINT_HP_BY_CHAPTER.size() - 1)]
				var cp_dmg_base: float = CHECKPOINT_DMG_BY_CHAPTER[clampi(ch_idx, 0, CHECKPOINT_DMG_BY_CHAPTER.size() - 1)]
				var cp_scalar: float = (block_idx + 1) * 0.1 + 1.0
				cp.enemy_max_hp = int(cp_hp_base * cp_scalar * castle.difficulty_multiplier)
				cp.enemy_damage = int(cp_dmg_base * cp_scalar * castle.difficulty_multiplier)
				cp.is_boss = false
				cp.boss_modifier = _make_boss_modifier(ch_idx, castle.difficulty_multiplier * 0.7)
			cp.background_color = _background_for_theme(ch.theme, rng).darkened(0.25)
			cp.background_path = _background_path_for_chapter(ch_idx)
			cp.enemy_attack_interval = 1
			cp.is_checkpoint = true
			cp.checkpoint_index = block_idx
			# Phase G/H: chapter 1 (index 0) gets the named checkpoint encounters.
			# Block 4 of chapter 1 is the tower boss "Supply Tower Warden" — CP5
			# combines the supply-caravan keg gimmick with the resupply boss
			# mechanic into one fight. Chapter 2/3 stay procedural per spec.
			if ch_idx == 0:
				cp.encounter_modifier = _make_chapter1_encounter(block_idx)
				_apply_chapter1_naming(cp, block_idx)
			ch.levels.append(cp)
		castle.chapters.append(ch)

	# King
	var king := LevelResource.new()
	var king_name: String = KING_NAMES[castle_index % KING_NAMES.size()]
	var king_epithet: String = KING_EPITHETS[castle_index % KING_EPITHETS.size()]
	castle.king_epithet = king_epithet
	king.level_name = "%s, %s" % [king_name, king_epithet]
	king.background_color = Color(0.15, 0.08, 0.18)
	king.enemy_name = king_name
	# King is the wall: heavier than any tower boss and visibly meatier.
	king.enemy_max_hp = int(KING_HP * castle.difficulty_multiplier)
	king.enemy_damage = int(KING_DMG * castle.difficulty_multiplier)
	king.enemy_attack_interval = 1
	king.is_boss = true
	king.is_king = true
	king.boss_modifier = _make_king_modifier(castle.difficulty_multiplier)
	king.enemy_sprite_path = "res://assets/characters/bosses/king.png"
	king.background_path = "res://assets/backgrounds/throne.png"
	castle.king_level = king

	return castle

static func _boss_sprite_path(ch_idx: int) -> String:
	match ch_idx:
		0: return "res://assets/characters/bosses/watchtower_warden.png"
		1: return "res://assets/characters/bosses/drum_tower_warden.png"
		2: return "res://assets/characters/bosses/keep_warden.png"
	return ""

static func _background_path_for_chapter(ch_idx: int) -> String:
	match ch_idx:
		0: return "res://assets/backgrounds/forest.png"
		1: return "res://assets/backgrounds/walls.png"
		2: return "res://assets/backgrounds/keep.png"
	return "res://assets/backgrounds/forest.png"

static func _regular_enemy_sprite_for_chapter(ch_idx: int) -> String:
	match ch_idx:
		0: return "res://assets/characters/enemy.png"
		1: return "res://assets/characters/enemy_warrior.png"
		2: return "res://assets/characters/enemy_slime.png"
	return "res://assets/characters/enemy.png"

static func _enemy_name_for_chapter(ch_idx: int, rng: RandomNumberGenerator) -> String:
	var pool: Array = ENEMY_NAMES[ch_idx]
	return pool[rng.randi() % pool.size()]

static func _regular_level_name(ch_idx: int, block_idx: int, in_block: int, rng: RandomNumberGenerator) -> String:
	# Reuse the 5-name pool seeded with block_idx so each block reads as a
	# fresh stage. The in-block index becomes a small numeric suffix.
	var pool: Array = LEVEL_NAMES[ch_idx]
	var base: String = pool[(block_idx + in_block) % pool.size()]
	# Pick a deterministic but flavorful suffix per (block, in_block).
	return "%s — %d-%d" % [base, block_idx + 1, in_block + 1]

static func _in_chapter_checkpoint_name(ch_idx: int, block_idx: int) -> String:
	# Reads "Forward Garrison — Block 1 Checkpoint" etc. Tower boss (block 4)
	# is handled separately and named after its warden.
	var pool: Array = ["Forward Garrison", "Wall Archers", "Catacombs", "Naval Pier", "Supply Caravan"]
	var base: String = pool[clampi(block_idx, 0, pool.size() - 1)]
	if ch_idx != 0:
		# Outside chapter 1 these labels are placeholder — keep neutral.
		base = "Checkpoint %d" % (block_idx + 1)
	return base

static func _checkpoint_enemy_name(ch_idx: int, block_idx: int, rng: RandomNumberGenerator) -> String:
	# In-chapter checkpoints get an "elite" version of a regular enemy.
	var pool: Array = ENEMY_NAMES[ch_idx]
	var base: String = pool[(block_idx + rng.randi()) % pool.size()]
	return "Elite %s" % base

static func _background_for_theme(theme: String, rng: RandomNumberGenerator) -> Color:
	match theme:
		"forest": return Color(0.10, 0.20, 0.12).lerp(Color(0.08, 0.16, 0.10), rng.randf())
		"wall": return Color(0.20, 0.18, 0.18).lerp(Color(0.16, 0.14, 0.14), rng.randf())
		"keep": return Color(0.18, 0.14, 0.18).lerp(Color(0.14, 0.10, 0.16), rng.randf())
	return Color(0.12, 0.10, 0.16)

static func _make_boss_modifier(ch_idx: int, mult: float) -> BossModifier:
	var bm := BossModifier.new()
	bm.armor = int((1 + ch_idx) * 2 * mult)
	bm.enrage_threshold = 0.3
	bm.enrage_multiplier = 1.5
	bm.special_attack_every_n_turns = 4 - ch_idx
	bm.special_attack_damage = int((8 + ch_idx * 4) * mult)
	bm.description = "Tower Warden — heavy armor and enrage at low HP"
	return bm

static func _make_chapter1_encounter(block_idx: int) -> EncounterModifier:
	# One named encounter per block in chapter 1. Block 4 = tower boss; the
	# CP5 supply-warden behavior layers keg defuse, resupply heal, and L2
	# interrupt into a single fight.
	match block_idx:
		0: return _make_cp1_modifier()
		1: return _make_cp2_modifier()
		2: return _make_cp3_modifier()
		3: return _make_cp4_modifier()
		4: return _make_cp5_modifier()
	return null

static func _apply_chapter1_naming(cp: LevelResource, block_idx: int) -> void:
	# Override the generic checkpoint name with the spec's named encounter so
	# the chapter map / level label reads "Forward Garrison", "Wall Archers",
	# etc. Block 4 also gets the Supply Tower Warden boss title.
	match block_idx:
		0:
			cp.level_name = "Forward Garrison"
			cp.enemy_name = "Garrison Captain"
		1:
			cp.level_name = "Wall Archers"
			cp.enemy_name = "Archer Sergeant"
		2:
			cp.level_name = "Catacombs"
			cp.enemy_name = "Catacomb Dweller"
		3:
			cp.level_name = "Naval Pier"
			cp.enemy_name = "Pier Bombardier"
		4:
			cp.level_name = "Supply Tower"
			cp.enemy_name = "Supply Tower Warden"

static func _make_cp1_modifier() -> EncounterModifier:
	var em := EncounterModifier.new()
	em.encounter_id = "cp1_garrison"
	em.enemies_in_a_row = 5
	em.forced_item_weights = {"shield": 3.0, "red_potion": 3.0}
	return em

static func _make_cp2_modifier() -> EncounterModifier:
	var em := EncounterModifier.new()
	em.encounter_id = "cp2_archers"
	em.ranged_volley_period = 6.0
	em.ranged_volley_damage = 10
	em.forced_item_weights = {"shield": 4.0}
	return em

static func _make_cp3_modifier() -> EncounterModifier:
	var em := EncounterModifier.new()
	em.encounter_id = "cp3_catacombs"
	em.weak_to_dot_kinds = [
		StatusEffect.Kind.BURN,
		StatusEffect.Kind.IGNITE,
		StatusEffect.Kind.ACID_BURN,
	]
	em.weak_to_dot_multiplier = 2.0
	em.forced_item_weights = {"acid": 3.0, "fire_bomb": 3.0}
	return em

static func _make_cp4_modifier() -> EncounterModifier:
	var em := EncounterModifier.new()
	em.encounter_id = "cp4_pier"
	em.cannon_period = 8.0
	em.cannon_telegraph_time = 2.0
	em.cannon_damage = 18
	return em

static func _make_cp5_modifier() -> EncounterModifier:
	var em := EncounterModifier.new()
	em.encounter_id = "cp5_supply_warden"
	em.resupply_interval_seconds = 20.0
	em.resupply_heal_fraction = 0.10
	em.resupply_telegraph_seconds = 5.0
	em.interrupt_damage_threshold = 200
	em.forced_item_weights = {"fire_bomb": 8.0, "red_potion": 0.5}
	return em

static func _make_king_modifier(mult: float) -> BossModifier:
	var bm := BossModifier.new()
	bm.armor = int(6 * mult)
	bm.enrage_threshold = 0.4
	bm.enrage_multiplier = 1.75
	bm.special_attack_every_n_turns = 3
	bm.special_attack_damage = int(18 * mult)
	bm.description = "The King — heavy plate, royal guard, devastating royal command"
	return bm
