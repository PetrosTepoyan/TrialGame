class_name CastleGenerator
extends Object

# Chapter 0 / 1 / 2 have fixed thematic identities — outer wood, the walls,
# the inner keep. Names, mottos, and level pools are picked per-chapter so the
# game reads like a siege progressing inward, not "Chapter 1, 2, 3".

const CHAPTER_THEMES := ["forest", "wall", "keep"]

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
		for lvl_idx in range(5):
			var lvl := LevelResource.new()
			lvl.level_name = LEVEL_NAMES[ch_idx][lvl_idx]
			lvl.background_color = _background_for_theme(ch.theme, rng)
			lvl.background_path = _background_path_for_chapter(ch_idx)
			lvl.enemy_name = _enemy_name_for_chapter(ch_idx, rng)
			lvl.enemy_sprite_path = _regular_enemy_sprite_for_chapter(ch_idx)
			var base_hp: float = 50.0 + ch_idx * 30.0 + lvl_idx * 12.0
			var base_dmg: float = 5.0 + ch_idx * 3.0 + lvl_idx * 1.0
			lvl.enemy_max_hp = int(base_hp * castle.difficulty_multiplier)
			lvl.enemy_damage = int(base_dmg * castle.difficulty_multiplier)
			lvl.enemy_attack_interval = 1
			lvl.is_boss = false
			ch.levels.append(lvl)
		# Boss level
		var boss := LevelResource.new()
		boss.level_name = "%s — %s" % [TOWER_NAMES[ch_idx], TOWER_BOSS_TITLES[ch_idx]]
		boss.background_color = _background_for_theme(ch.theme, rng).darkened(0.25)
		boss.background_path = _background_path_for_chapter(ch_idx)
		boss.enemy_name = TOWER_BOSS_TITLES[ch_idx]
		boss.enemy_max_hp = int((180.0 + ch_idx * 80.0) * castle.difficulty_multiplier)
		boss.enemy_damage = int((10.0 + ch_idx * 3.0) * castle.difficulty_multiplier)
		boss.enemy_attack_interval = 1
		boss.is_boss = true
		boss.boss_modifier = _make_boss_modifier(ch_idx, castle.difficulty_multiplier)
		boss.enemy_sprite_path = _boss_sprite_path(ch_idx)
		ch.levels.append(boss)
		castle.chapters.append(ch)

	# King
	var king := LevelResource.new()
	var king_name: String = KING_NAMES[castle_index % KING_NAMES.size()]
	var king_epithet: String = KING_EPITHETS[castle_index % KING_EPITHETS.size()]
	castle.king_epithet = king_epithet
	king.level_name = "%s, %s" % [king_name, king_epithet]
	king.background_color = Color(0.15, 0.08, 0.18)
	king.enemy_name = king_name
	king.enemy_max_hp = int(450.0 * castle.difficulty_multiplier)
	king.enemy_damage = int(14.0 * castle.difficulty_multiplier)
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

static func _make_king_modifier(mult: float) -> BossModifier:
	var bm := BossModifier.new()
	bm.armor = int(6 * mult)
	bm.enrage_threshold = 0.4
	bm.enrage_multiplier = 1.75
	bm.special_attack_every_n_turns = 3
	bm.special_attack_damage = int(18 * mult)
	bm.description = "The King — heavy plate, royal guard, devastating royal command"
	return bm
