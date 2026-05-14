extends Node

const MAIN_MENU := "res://scenes/ui/main_menu.tscn"
const WORLD_MAP := "res://scenes/world_map.tscn"
const CHAPTER_MAP := "res://scenes/chapter_map.tscn"
const BATTLE := "res://scenes/battle.tscn"
const GAME_OVER := "res://scenes/ui/game_over.tscn"
const VICTORY := "res://scenes/ui/victory.tscn"

const FADE_TIME: float = 0.25

var _fader: ColorRect = null

func _ready() -> void:
	# Create an overlay rect that lives above all scenes for crossfades.
	var canvas := CanvasLayer.new()
	canvas.name = "FaderLayer"
	canvas.layer = 128
	add_child(canvas)
	_fader = ColorRect.new()
	_fader.color = Color(0, 0, 0, 0)
	_fader.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_fader)

func goto(path: String) -> void:
	if _fader == null:
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null:
			tree.call_deferred("change_scene_to_file", path)
		return
	# Fade to black, swap scene, fade back in.
	var t := create_tween()
	t.tween_property(_fader, "color:a", 1.0, FADE_TIME).set_trans(Tween.TRANS_QUAD)
	await t.finished
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		tree.change_scene_to_file(path)
	await get_tree().process_frame
	var t2 := create_tween()
	t2.tween_property(_fader, "color:a", 0.0, FADE_TIME).set_trans(Tween.TRANS_QUAD)

func goto_main_menu() -> void: goto(MAIN_MENU)
func goto_world_map() -> void: goto(WORLD_MAP)
func goto_chapter_map() -> void: goto(CHAPTER_MAP)
func goto_battle() -> void: goto(BATTLE)
func goto_game_over() -> void: goto(GAME_OVER)
func goto_victory() -> void: goto(VICTORY)
