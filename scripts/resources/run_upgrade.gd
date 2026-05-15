class_name RunUpgrade
extends Resource

enum Kind { MAX_HP, MAX_ARMOR, MAX_DAMAGE }

@export var kind: int = Kind.MAX_HP
@export var magnitude: int = 0
@export var label: String = ""
