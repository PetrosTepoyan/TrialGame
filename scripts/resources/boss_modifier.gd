class_name BossModifier
extends Resource

# Armor flat-reduces incoming non-archer damage by this amount per hit (min 0).
@export var armor: int = 0
# When boss HP fraction <= this threshold, boss enrages (damage x enrage_mult).
@export var enrage_threshold: float = 0.3
@export var enrage_multiplier: float = 1.5
# Every N player turns boss does a special attack (extra damage).
@export var special_attack_every_n_turns: int = 0
@export var special_attack_damage: int = 8
@export var description: String = ""
