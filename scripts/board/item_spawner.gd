class_name ItemSpawner
extends Node

# Decides per-refill whether a board cell should be replaced by an ItemPiece.
# Owned by Board. Encounters can override the spawn weights via
# set_forced_weights() — those are id→weight pairs that supersede each
# BoardItem.spawn_weight when present.

const BASE_SPAWN_CHANCE_PER_REFILL: float = 0.18
const FORCED_SPAWN_FLOOR_SECONDS: float = 15.0

var _items_pool: Array[BoardItem] = []
var _forced_item_weights: Dictionary = {}   # encounter-controlled override
var _last_spawn_time: float = 0.0
var _rng := RandomNumberGenerator.new()
var _player_hp_provider: Callable = Callable()
# Debug knob: when true, every refill spawns an item (subject to the board's
# MAX_ITEMS_ON_BOARD cap). Toggled from the Items debug tab.
var _force_spawn_every_refill: bool = false

func _ready() -> void:
	_rng.randomize()
	_load_items()
	_last_spawn_time = Time.get_ticks_msec() / 1000.0

func _load_items() -> void:
	var dir = DirAccess.open("res://data/board_items/")
	if dir == null:
		return
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			var res = load("res://data/board_items/%s" % fname)
			if res is BoardItem:
				_items_pool.append(res)
		fname = dir.get_next()
	dir.list_dir_end()

# Battle code passes a Callable returning the player's HP fraction (0..1).
# We pressure-multiply the spawn chance when the player is hurt.
func set_player_hp_provider(c: Callable) -> void:
	_player_hp_provider = c

func set_forced_weights(w: Dictionary) -> void:
	_forced_item_weights = w

func should_spawn_item() -> BoardItem:
	if _items_pool.is_empty():
		return null
	var now: float = Time.get_ticks_msec() / 1000.0
	var elapsed: float = now - _last_spawn_time
	var pressure: float = _hp_pressure_multiplier()
	var chance: float = BASE_SPAWN_CHANCE_PER_REFILL * pressure
	var force: bool = _force_spawn_every_refill or elapsed >= FORCED_SPAWN_FLOOR_SECONDS
	if force or _rng.randf() < chance:
		var picked: BoardItem = _weighted_pick()
		if picked != null:
			_last_spawn_time = now
			return picked
	return null

# Debug-menu toggle: force every refill to spawn an item until cleared.
func set_force_spawn_every_refill(state: bool) -> void:
	_force_spawn_every_refill = state

func _hp_pressure_multiplier() -> float:
	if _player_hp_provider.is_null():
		return 1.0
	var pct: float = float(_player_hp_provider.call())
	if pct < 0.3:
		return 2.5
	if pct < 0.6:
		return 1.5
	return 1.0

func _weighted_pick() -> BoardItem:
	if _items_pool.is_empty():
		return null
	var total: float = 0.0
	var weights: Array[float] = []
	for it in _items_pool:
		var w: float = float(_forced_item_weights.get(it.id, it.spawn_weight))
		if w < 0.0:
			w = 0.0
		weights.append(w)
		total += w
	if total <= 0.0:
		return null
	var roll: float = _rng.randf() * total
	var acc: float = 0.0
	for i in _items_pool.size():
		acc += weights[i]
		if roll <= acc:
			return _items_pool[i]
	return _items_pool[-1]
