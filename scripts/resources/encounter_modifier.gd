class_name EncounterModifier
extends Resource

@export var encounter_id: String = ""
@export var enemies_in_a_row: int = 1
@export var forced_item_weights: Dictionary = {}
@export var ranged_volley_period: float = 0.0
@export var ranged_volley_damage: int = 0
@export var cannon_telegraph_time: float = 0.0
@export var cannon_damage: int = 0
@export var cannon_period: float = 0.0
@export var weak_to_dot_kinds: Array[int] = []
@export var weak_to_dot_multiplier: float = 1.0
@export var resupply_interval_seconds: float = 0.0
@export var resupply_heal_fraction: float = 0.0
@export var resupply_telegraph_seconds: float = 0.0
@export var interrupt_damage_threshold: int = 0
