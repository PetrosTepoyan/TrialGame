class_name Emblem
extends Resource

# An emblem is created each time the player completes a match. It is added
# to the CombatController's action scale (capacity 5). When the scale fills,
# emblems are resolved together to produce the round's effects.

@export var piece_kind: int = 0  # PieceType.Kind
@export var level: int = 1  # 1..3 based on match run length

func _init(p_kind: int = 0, p_level: int = 1) -> void:
	piece_kind = p_kind
	level = p_level
