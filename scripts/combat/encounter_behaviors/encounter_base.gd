class_name EncounterBehavior
extends Node

# Lifecycle for a checkpoint-specific encounter gimmick. battle.gd reads
# level.encounter_modifier.encounter_id, instantiates the right subclass,
# wires it into the CombatController, and lets the subclass override hooks.
#
# Hooks are intentionally fire-and-forget so a behavior can ignore anything
# irrelevant to its mechanic. on_enemy_died returns a bool — true means the
# behavior absorbed the death (e.g. CP1 swapping in the next garrison enemy)
# and CombatController should NOT fire battle_won.

var combat: CombatController = null
var level: LevelResource = null
var modifier: EncounterModifier = null

func setup(combat_ref: CombatController, level_ref: LevelResource) -> void:
	combat = combat_ref
	level = level_ref
	if level_ref != null:
		modifier = level_ref.encounter_modifier

func start() -> void:
	pass

# Return true to absorb the death (battle_won will NOT fire). Default: allow win.
func on_enemy_died() -> bool:
	return false

func on_player_attacked(_damage: int) -> void:
	pass

func on_match_resolved(_kind: int, _level_val: int, _longest_run: int) -> void:
	pass

func on_spec_attack_fired(_level_val: int) -> void:
	pass

func on_item_broken(_item: BoardItem, _location: Vector2i) -> void:
	pass

func _process(delta: float) -> void:
	on_tick(delta)

func on_tick(_delta: float) -> void:
	pass

func teardown() -> void:
	pass
