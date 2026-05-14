extends Node

const MAIN_MENU := "res://scenes/ui/main_menu.tscn"
const WORLD_MAP := "res://scenes/world_map.tscn"
const CHAPTER_MAP := "res://scenes/chapter_map.tscn"
const BATTLE := "res://scenes/battle.tscn"
const GAME_OVER := "res://scenes/ui/game_over.tscn"
const VICTORY := "res://scenes/ui/victory.tscn"

func goto(path: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	tree.call_deferred("change_scene_to_file", path)

func goto_main_menu() -> void:
	goto(MAIN_MENU)

func goto_world_map() -> void:
	goto(WORLD_MAP)

func goto_chapter_map() -> void:
	goto(CHAPTER_MAP)

func goto_battle() -> void:
	goto(BATTLE)

func goto_game_over() -> void:
	goto(GAME_OVER)

func goto_victory() -> void:
	goto(VICTORY)
