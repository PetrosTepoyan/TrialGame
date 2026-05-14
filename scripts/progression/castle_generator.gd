class_name CastleGenerator
extends Object

const THEMES := ["forest", "village", "wall", "courtyard", "throne_room", "battlements", "mountain", "coast", "desert"]
const ENEMY_NAMES := [
	["Brigand", "Outlaw", "Marauder", "Deserter", "Scout"],
	["Footman", "Pikeman", "Crossbowman", "Knight", "Sergeant"],
	["Captain", "Lieutenant", "Champion", "Warden", "Veteran"],
]
const TOWER_NAMES := ["Watchtower", "Drum Tower", "Keep"]
const KING_NAMES := ["King Aldric", "King Mordrek", "King Sigwald", "King Tharon", "King Valenor", "King Coreth"]

static func generate(castle_index: int) -> CastleResource:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337 + castle_index * 7919
	var castle := CastleResource.new()
	castle.castle_index = castle_index
	castle.seed_value = int(rng.seed)
	castle.castle_name = "Castle %d" % (castle_index + 1)
	castle.difficulty_multiplier = 1.0 + 0.15 * castle_index

	for ch_idx in range(3):
		var ch := ChapterResource.new()
		ch.chapter_name = "Chapter %d" % (ch_idx + 1)
		ch.theme = THEMES[rng.randi() % THEMES.size()]
		ch.levels = []
		for lvl_idx in range(5):
			var lvl := LevelResource.new()
			lvl.level_name = "%s — Skirmish %d" % [_theme_label(ch.theme), lvl_idx + 1]
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
		boss.level_name = "%s Tower" % TOWER_NAMES[ch_idx]
		boss.background_color = _background_for_theme(ch.theme, rng).darkened(0.25)
		boss.background_path = _background_path_for_chapter(ch_idx)
		boss.enemy_name = "%s Warden" % TOWER_NAMES[ch_idx]
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
	king.level_name = KING_NAMES[castle_index % KING_NAMES.size()]
	king.background_color = Color(0.15, 0.08, 0.18)
	king.enemy_name = king.level_name
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

# Each chapter has its own regular footsoldier sprite so the world looks
# different as the player progresses (forest brigand -> walls guard -> keep mage).
static func _regular_enemy_sprite_for_chapter(ch_idx: int) -> String:
	match ch_idx:
		0: return "res://assets/characters/enemy.png"          # generic soldier
		1: return "res://assets/characters/enemy_warrior.png"  # armoured warrior
		2: return "res://assets/characters/enemy_slime.png"    # otherworldly slime
	return "res://assets/characters/enemy.png"

static func _theme_label(theme: String) -> String:
	return theme.capitalize().replace("_", " ")

static func _enemy_name_for_chapter(ch_idx: int, rng: RandomNumberGenerator) -> String:
	var pool: Array = ENEMY_NAMES[ch_idx]
	return pool[rng.randi() % pool.size()]

static func _background_for_theme(theme: String, rng: RandomNumberGenerator) -> Color:
	match theme:
		"forest": return Color(0.10, 0.20, 0.12).lerp(Color(0.08, 0.16, 0.10), rng.randf())
		"village": return Color(0.30, 0.22, 0.14).lerp(Color(0.26, 0.18, 0.12), rng.randf())
		"wall": return Color(0.20, 0.18, 0.18).lerp(Color(0.16, 0.14, 0.14), rng.randf())
		"courtyard": return Color(0.22, 0.20, 0.16)
		"throne_room": return Color(0.18, 0.10, 0.20)
		"battlements": return Color(0.18, 0.18, 0.22)
		"mountain": return Color(0.16, 0.16, 0.20)
		"coast": return Color(0.12, 0.22, 0.28)
		"desert": return Color(0.34, 0.26, 0.16)
	return Color(0.12, 0.10, 0.16)

static func _make_boss_modifier(ch_idx: int, mult: float) -> BossModifier:
	var bm := BossModifier.new()
	bm.armor = int((1 + ch_idx) * 2 * mult)
	bm.enrage_threshold = 0.3
	bm.enrage_multiplier = 1.5
	bm.special_attack_every_n_turns = 4 - ch_idx  # gets faster
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
