class_name Board
extends Node2D

signal swap_animated
# from_rainbow flags any group that pulled in a rainbow tile — combat treats
# those as forced L3 matches regardless of axis-run length.
# effective_level: 1 = run-3 plain, 2 = run-4 OR 2x2 square OR L-corner,
# 3 = run-5+ OR rainbow. Combat reads this directly instead of recomputing.
# Callers: scripts/combat/combat_controller.gd::_on_match_resolved (will update in Phase B for effective_level arg).
signal match_resolved(kind: int, count: int, longest_run: int, from_rainbow: bool, effective_level: int)
signal cascade_finished(total_matches: int, cascade_depth: int)
signal invalid_swap
signal shuffle_started
signal shuffle_finished
# Phase D: emitted once per resolved batch with the cells the player just
# matched away. ItemPieces on the board listen and tick integrity by adjacency.
signal match_cleared_cells(cells: Array)
# Phase D: emitted when an ItemPiece's integrity reaches 0. CombatController
# subscribes and routes through ItemEffects.
signal item_broken(item: BoardItem, pos: Vector2i)

const ROWS := 9
const COLS := 9
const CELL: float = Piece.SIZE
const SPACING: float = 4.0
const MAX_CASCADE_DEPTH := 20
# 99 effectively disables diagonal matches on this 9x9 board — players found
# diagonal-4 matches confusing and unintentional. Horizontal/vertical only.
const DIAGONAL_MIN_LENGTH := 99

# Board pixel footprint at 9x9 / SIZE=108 / SPACING=4: 9*108 + 9*4 = 1008px square.
# Phase B should size BoardArea in scenes/battle.tscn accordingly (e.g. centered
# on a 1080px-wide viewport with offsets ~36px from the left/right edges).

# --- Tunable mechanics ---
# Rainbow tile removed per player feedback ("strange multi-colored icons with
# unclear effect"). Setting the chance to 0 keeps the merge-friendly plumbing
# in place but makes them never spawn.
const SPECIAL_RAINBOW_CHANCE: float = 0.0

# Weighted spawn distribution for the four army kinds. Index matches Kind enum
# (SWORD, SHIELD, STAFF, BOW). Sword is slightly favoured because most players
# want to deal damage — this keeps combat moving.
const KIND_SPAWN_WEIGHTS: Array[int] = [28, 24, 24, 24]

# How long the board must sit idle (in seconds) before we pulse a hint move.
const HINT_IDLE_SECONDS: float = 6.0
const HINT_PULSE_SCALE: float = 1.18
const HINT_PULSE_TIME: float = 0.45

enum State { IDLE, SWAPPING, RESOLVING, SHUFFLING }

@export var piece_types: Array[PieceType] = []

var grid: Array = []                          # rows x cols of Piece (or null)
var state: int = State.IDLE
var _input_locked: bool = false               # CombatController locks during round execution
var _selected_cell: Vector2i = Vector2i(-1, -1)
var _piece_layer: Node2D
var _rng := RandomNumberGenerator.new()

# Idle-hint state. _hint_timer counts down each frame while the board is idle
# and unlocked; on fire we look for a valid move and briefly pulse the two
# pieces involved. Cleared on any input (request_swap, tap_select).
var _hint_timer: float = HINT_IDLE_SECONDS
var _hint_pieces: Array[Piece] = []
var _hint_tweens: Array[Tween] = []

# Phase D items. Spawner is owned as a child so encounter code can fetch and
# tweak its forced weights. MAX_ITEMS_ON_BOARD caps concurrent clutter — at 3,
# the player still has plenty of non-item cells to plan around on 9×9.
const MAX_ITEMS_ON_BOARD: int = 3
var _item_spawner: ItemSpawner = null
var _items_on_board: Array[ItemPiece] = []

func _ready() -> void:
	_rng.randomize()
	_piece_layer = Node2D.new()
	_piece_layer.name = "Pieces"
	add_child(_piece_layer)
	_item_spawner = ItemSpawner.new()
	_item_spawner.name = "ItemSpawner"
	add_child(_item_spawner)
	if piece_types.is_empty():
		piece_types = _default_piece_types()
	populate_new_board()

# Public accessor so CombatController / encounters can wire the HP provider
# and override item weights without poking at private state.
func get_item_spawner() -> ItemSpawner:
	return _item_spawner

func _default_piece_types() -> Array[PieceType]:
	# Fallback when designer hasn't wired .tres files in the editor. Values
	# track the new spec:
	#   Sword:  level_values [10, 12, 15] (raw damage)
	#   Shield: level_values [1, 3, 5]    (armor per emblem)
	#   Staff:  level_values [3, 5, 7]    (DoT duration in rounds)
	#           level_secondary [5, 5, 5] (DoT dps)
	#   Bow:    level_values [2, 3, 5]    (armor pierce)
	#           level_secondary [1, 2, 3] (HP damage)
	var arr: Array[PieceType] = []
	var defs := [
		{
			"kind": PieceType.Kind.SWORD,  "name": "Sword",  "color": Color(0.95, 0.78, 0.30),
			"values": [10, 12, 15], "secondary": [0, 0, 0],
		},
		{
			"kind": PieceType.Kind.SHIELD, "name": "Shield", "color": Color(0.40, 0.62, 0.95),
			"values": [1, 3, 5], "secondary": [0, 0, 0],
		},
		{
			"kind": PieceType.Kind.STAFF,  "name": "Staff",  "color": Color(0.66, 0.36, 0.85),
			"values": [3, 5, 7], "secondary": [5, 5, 5],
		},
		{
			"kind": PieceType.Kind.BOW,    "name": "Bow",    "color": Color(0.40, 0.82, 0.50),
			"values": [2, 3, 5], "secondary": [1, 2, 3],
		},
	]
	for d in defs:
		var pt := PieceType.new()
		pt.kind = d["kind"]
		pt.display_name = d["name"]
		pt.color = d["color"]
		pt.level_values.assign(d["values"])
		pt.level_secondary.assign(d["secondary"])
		arr.append(pt)
	return arr

func populate_new_board() -> void:
	_clear_all_pieces()
	var kind_grid: Array = _make_blank_kind_grid()
	var attempts: int = 0
	while true:
		for y in range(ROWS):
			for x in range(COLS):
				kind_grid[y][x] = _pick_kind_without_match(kind_grid, x, y)
		if NoMovesDetector.has_any_move(kind_grid, DIAGONAL_MIN_LENGTH):
			break
		attempts += 1
		if attempts > 5:
			break
	for y in range(ROWS):
		for x in range(COLS):
			var piece := _make_piece(kind_grid[y][x], Vector2i(x, y))
			_piece_layer.add_child(piece)
			grid[y][x] = piece

func _make_blank_kind_grid() -> Array:
	var kind_grid: Array = []
	for y in range(ROWS):
		var row: Array = []
		for x in range(COLS):
			row.append(-1)
		kind_grid.append(row)
	return kind_grid

func _pick_kind_without_match(kind_grid: Array, x: int, y: int) -> int:
	# Rainbows are never placed at startup or in shuffle; restrict to army kinds.
	var candidates: Array[int] = [
		PieceType.Kind.SWORD, PieceType.Kind.SHIELD,
		PieceType.Kind.STAFF, PieceType.Kind.BOW,
	]
	candidates.shuffle()
	for k in candidates:
		kind_grid[y][x] = k
		if not _creates_immediate_match(kind_grid, x, y):
			return k
	kind_grid[y][x] = candidates[0]
	return candidates[0]

func _creates_immediate_match(kind_grid: Array, x: int, y: int) -> bool:
	var k: int = kind_grid[y][x]
	# Rainbow is wildcard — we never want one placed at startup, but if it's
	# already there for any reason it's safe to skip (it doesn't *create* a
	# match by itself, the match logic folds it in adjacent).
	if k < 0 or k == PieceType.Kind.RAINBOW:
		return false
	if x >= 2 and kind_grid[y][x - 1] == k and kind_grid[y][x - 2] == k:
		return true
	if y >= 2 and kind_grid[y - 1][x] == k and kind_grid[y - 2][x] == k:
		return true
	if x >= 2 and y >= 2 and kind_grid[y - 1][x - 1] == k and kind_grid[y - 2][x - 2] == k:
		return true
	if x >= 2 and y <= ROWS - 3 and kind_grid[y + 1][x - 1] == k and kind_grid[y + 2][x - 2] == k:
		return true
	return false

# Weighted random pick across the four army kinds. Sword is favoured per
# KIND_SPAWN_WEIGHTS. Used by refill.
func _pick_weighted_kind() -> int:
	var total: int = 0
	for w in KIND_SPAWN_WEIGHTS:
		total += w
	if total <= 0:
		return _rng.randi() % PieceType.SPAWNABLE_KIND_COUNT
	var roll: int = _rng.randi_range(0, total - 1)
	var acc: int = 0
	for i in range(KIND_SPAWN_WEIGHTS.size()):
		acc += KIND_SPAWN_WEIGHTS[i]
		if roll < acc:
			return i
	return KIND_SPAWN_WEIGHTS.size() - 1

func _clear_all_pieces() -> void:
	if _piece_layer != null:
		for c in _piece_layer.get_children():
			c.queue_free()
	grid.clear()
	for y in range(ROWS):
		var row: Array = []
		for x in range(COLS):
			row.append(null)
		grid.append(row)

func _make_piece(kind: int, board_pos: Vector2i) -> Piece:
	var p := Piece.new()
	var tint: Color = _color_for_kind(kind)
	p.configure(kind, tint, board_pos)
	p.position = board_pos_to_world(board_pos)
	return p

func _color_for_kind(kind: int) -> Color:
	if kind == PieceType.Kind.RAINBOW:
		# Rainbow ignores per-kind palette; piece._draw paints the swirl itself.
		return Color(1.0, 1.0, 1.0)
	if kind >= 0 and kind < piece_types.size():
		return piece_types[kind].color
	return Color.WHITE

# Refill pick: occasionally returns RAINBOW; otherwise weighted army kind.
func _roll_refill_kind() -> int:
	if _rng.randf() < SPECIAL_RAINBOW_CHANCE:
		return PieceType.Kind.RAINBOW
	return _pick_weighted_kind()

func board_pos_to_world(bp: Vector2i) -> Vector2:
	var step: float = CELL + SPACING
	return Vector2(bp.x * step + step * 0.5, bp.y * step + step * 0.5)

func board_total_size() -> Vector2:
	var step: float = CELL + SPACING
	return Vector2(COLS * step, ROWS * step)

func world_to_board_pos(world_pos: Vector2) -> Vector2i:
	var step: float = CELL + SPACING
	var x: int = int(floor(world_pos.x / step))
	var y: int = int(floor(world_pos.y / step))
	return Vector2i(x, y)

func is_in_bounds(bp: Vector2i) -> bool:
	return bp.x >= 0 and bp.y >= 0 and bp.x < COLS and bp.y < ROWS

func can_accept_input() -> bool:
	return state == State.IDLE and not _input_locked

func set_input_locked(value: bool) -> void:
	_input_locked = value

# Public API: request a swap. Returns true if accepted.
func request_swap(a: Vector2i, b: Vector2i) -> bool:
	# Any swap attempt counts as input — kill the idle hint and reset its timer.
	_reset_hint_timer()
	if state != State.IDLE or _input_locked:
		return false
	if not is_in_bounds(a) or not is_in_bounds(b):
		return false
	var diff: Vector2i = b - a
	if abs(diff.x) + abs(diff.y) != 1:
		return false
	# Phase D: items are anchored; never swap into or out of an item cell.
	if grid[a.y][a.x] is ItemPiece or grid[b.y][b.x] is ItemPiece:
		return false
	state = State.SWAPPING
	AudioBus.play_swap()
	Haptics.medium_tap()
	_do_swap(a, b, true)
	return true

func _do_swap(a: Vector2i, b: Vector2i, check_match: bool) -> void:
	var pa: Piece = grid[a.y][a.x]
	var pb: Piece = grid[b.y][b.x]
	if pa == null or pb == null:
		state = State.IDLE
		return
	grid[a.y][a.x] = pb
	grid[b.y][b.x] = pa
	pa.board_pos = b
	pb.board_pos = a
	var from_a: Vector2 = pa.position
	var from_b: Vector2 = pb.position
	var to_a: Vector2 = board_pos_to_world(b)
	var to_b: Vector2 = board_pos_to_world(a)
	# Subtle trail on the forward swap only; the revert (check_match == false)
	# stays quiet so invalid swaps don't double-flash.
	if check_match:
		SwapTrail.spawn(from_a, to_a, piece_types[pa.kind].color, from_b, to_b, piece_types[pb.kind].color, _piece_layer)
	var t1 := pa.tween_to(to_a)
	var t2 := pb.tween_to(to_b)
	await t1.finished
	await t2.finished
	if check_match:
		var groups := _find_matches()
		if groups.is_empty():
			await _do_swap(b, a, false)
			AudioBus.play_invalid()
			Haptics.warning()
			emit_signal("invalid_swap")
			return
		state = State.RESOLVING
		await _resolve_cascade()
	else:
		state = State.IDLE

func _find_matches() -> Array:
	return MatchDetector.find_matches(_kind_snapshot(), DIAGONAL_MIN_LENGTH)

func _kind_snapshot() -> Array:
	var arr: Array = []
	for y in range(ROWS):
		var row: Array = []
		for x in range(COLS):
			var p: Piece = grid[y][x]
			row.append(p.kind if p != null else -1)
		arr.append(row)
	return arr

func _resolve_cascade() -> void:
	var total: int = 0
	var depth: int = 0
	while depth < MAX_CASCADE_DEPTH:
		var groups: Array = _find_matches()
		if groups.is_empty():
			break
		total += groups.size()
		var kind_grid := _kind_snapshot()
		# Build per-cell metadata so each piece's burst is sized to the run it
		# belongs to. If a cell sits in more than one group (intersections),
		# the larger run wins.
		var cell_run: Dictionary = {}
		for g in groups:
			var k: int = g["kind"]
			var cells: Array = g["cells"]
			var longest: int = MatchDetector.longest_axis_run_in(cells, kind_grid)
			var from_rainbow: bool = bool(g.get("had_rainbow", false))
			var is_square: bool = bool(g.get("is_square", false))
			var had_corner: bool = bool(g.get("had_corner", false))
			var effective_level: int = 1
			if longest >= 5 or from_rainbow:
				effective_level = 3
			elif longest >= 4 or is_square or had_corner:
				effective_level = 2
			emit_signal("match_resolved", k, cells.size(), longest, from_rainbow, effective_level)
			Haptics.light_tap()
			for cell_v in cells:
				var prev: int = int(cell_run.get(cell_v, 0))
				if longest > prev:
					cell_run[cell_v] = longest
		AudioBus.play_match(groups.map(func(g): return MatchDetector.longest_axis_run_in(g["cells"], kind_grid)).max())
		var all_removed: Dictionary = {}
		for g in groups:
			for cell in g["cells"]:
				all_removed[cell] = true
		var remove_tweens: Array[Tween] = []
		var pieces_to_free: Array[Piece] = []
		for cell_v in all_removed.keys():
			var cell: Vector2i = cell_v
			var p: Piece = grid[cell.y][cell.x]
			if p != null:
				remove_tweens.append(p.tween_remove())
				pieces_to_free.append(p)
				grid[cell.y][cell.x] = null
				var run_len: int = int(cell_run.get(cell, 3))
				MatchParticles.spawn(p.position, _color_for_kind(p.kind), _piece_layer, p.kind, run_len)
		if not remove_tweens.is_empty():
			await remove_tweens[remove_tweens.size() - 1].finished
		for p in pieces_to_free:
			p.queue_free()
		# Phase D: notify item pieces of which cells were just cleared so each
		# adjacent ItemPiece can decrement integrity. We do this BEFORE refill so
		# items that break can be replaced by the gravity/refill pass.
		var cleared_array: Array = all_removed.keys()
		emit_signal("match_cleared_cells", cleared_array)
		_tick_items_for_cleared(cleared_array)
		await _apply_gravity_and_refill()
		depth += 1
	state = State.IDLE
	emit_signal("cascade_finished", total, depth)

func _apply_gravity_and_refill() -> void:
	# Items are unmovable: they act as anchors during gravity. Within a column we
	# collapse pieces *between* item anchors so falling tiles stack on top of an
	# item instead of dropping through it. Refilled tiles spawn only into the
	# top-most empty region (above the highest item or row 0 if no item).
	var tweens: Array[Tween] = []
	for x in range(COLS):
		# Find item anchor rows in this column (sorted ascending y).
		var anchors: Array[int] = []
		for y in range(ROWS):
			if grid[y][x] is ItemPiece:
				anchors.append(y)
		# Walk segments from bottom to top, anchored by items.
		var segments: Array = []  # array of [top_y_inclusive, bottom_y_inclusive]
		var cursor: int = ROWS - 1
		for i in range(anchors.size() - 1, -1, -1):
			var a: int = anchors[i]
			if a < cursor:
				segments.append([a + 1, cursor])
			cursor = a - 1
		# Top-most segment (above the highest anchor — this is also where refill spawns).
		if cursor >= 0:
			segments.append([0, cursor])
		else:
			# No empty cells above the top-most anchor — still keep an empty top
			# segment so refill never spawns through an item.
			segments.append([0, -1])
		var top_segment_index: int = segments.size() - 1
		for seg_i in range(segments.size()):
			var seg: Array = segments[seg_i]
			var top_y: int = seg[0]
			var bot_y: int = seg[1]
			if bot_y < top_y:
				continue
			# Collapse non-null pieces within this segment downward.
			var write_y: int = bot_y
			for y in range(bot_y, top_y - 1, -1):
				var p: Piece = grid[y][x]
				if p != null:
					if y != write_y:
						grid[write_y][x] = p
						grid[y][x] = null
						p.board_pos = Vector2i(x, write_y)
						tweens.append(p.tween_to(board_pos_to_world(p.board_pos), 0.22))
					write_y -= 1
			# Refill: only the top segment receives new tiles dropping in from above.
			if seg_i == top_segment_index:
				var spawn_index: int = 0
				for y in range(write_y, top_y - 1, -1):
					var spawned: Piece = _spawn_refill_piece(Vector2i(x, y))
					grid[y][x] = spawned
					var step: float = CELL + SPACING
					spawned.position = Vector2(spawned.position.x, -step * (spawn_index + 1) - step * 0.5)
					tweens.append(spawned.tween_to(board_pos_to_world(Vector2i(x, y)), 0.25))
					spawn_index += 1
	if tweens.is_empty():
		return
	await tweens[tweens.size() - 1].finished

# Refill-time spawn: ask the item spawner first. If it returns an item and
# we're under the on-board cap, spawn an ItemPiece; otherwise a normal piece.
func _spawn_refill_piece(board_pos: Vector2i) -> Piece:
	if _item_spawner != null and _items_on_board.size() < MAX_ITEMS_ON_BOARD:
		var item_res: BoardItem = _item_spawner.should_spawn_item()
		if item_res != null:
			var ip: ItemPiece = ItemPiece.new()
			ip.board_pos = board_pos
			ip.position = board_pos_to_world(board_pos)
			_piece_layer.add_child(ip)
			ip.configure_item(item_res)
			_items_on_board.append(ip)
			return ip
	var kind: int = _roll_refill_kind()
	var p := _make_piece(kind, board_pos)
	_piece_layer.add_child(p)
	return p

# Phase D: for each cleared cell, every ItemPiece with at least one cleared
# neighbour (8-dir, including the cell itself) loses integrity by the count of
# neighbours in the clear set. When integrity hits 0, the item triggers: emit
# item_broken, remove the cell, and let the refill pass replace it.
func _tick_items_for_cleared(cleared: Array) -> void:
	if cleared.is_empty() or _items_on_board.is_empty():
		return
	var cleared_set: Dictionary = {}
	for c in cleared:
		cleared_set[c] = true
	var survivors: Array[ItemPiece] = []
	var triggered: Array[ItemPiece] = []
	for ip in _items_on_board:
		if ip == null or not is_instance_valid(ip):
			continue
		var count: int = _count_adjacent_in_set(ip.board_pos, cleared_set)
		if count <= 0:
			survivors.append(ip)
			continue
		var broke: bool = ip.decrement_integrity(count)
		if broke:
			triggered.append(ip)
		else:
			survivors.append(ip)
	_items_on_board = survivors
	for ip in triggered:
		_break_item(ip)

# 8-dir adjacency count of a position against a set of Vector2i cells. The
# item's own cell is intentionally excluded — matches can't form on it.
func _count_adjacent_in_set(pos: Vector2i, cleared_set: Dictionary) -> int:
	var count: int = 0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var n := Vector2i(pos.x + dx, pos.y + dy)
			if cleared_set.has(n):
				count += 1
	return count

# Triggered item: notify combat (which dispatches the effect), spawn a small
# particle burst, queue-free the ItemPiece, and clear its grid slot so gravity
# refills with a normal piece next pass.
func _break_item(ip: ItemPiece) -> void:
	var pos: Vector2i = ip.board_pos
	var item_res: BoardItem = ip.item
	# Visual: reuse MatchParticles with the item tint. A dedicated particle is
	# Phase I polish; this reads as a "thing broke here" beat.
	var tint: Color = item_res.tint if item_res != null else Color.WHITE
	MatchParticles.spawn(ip.position, tint, _piece_layer, -1, 4)
	grid[pos.y][pos.x] = null
	ip.queue_free()
	emit_signal("item_broken", item_res, pos)

func shuffle_board_if_dead() -> bool:
	var kg := _kind_snapshot()
	if NoMovesDetector.has_any_move(kg, DIAGONAL_MIN_LENGTH):
		return false
	state = State.SHUFFLING
	emit_signal("shuffle_started")
	for attempt in range(10):
		var kind_grid: Array = _make_blank_kind_grid()
		for y in range(ROWS):
			for x in range(COLS):
				kind_grid[y][x] = _pick_kind_without_match(kind_grid, x, y)
		if NoMovesDetector.has_any_move(kind_grid, DIAGONAL_MIN_LENGTH):
			var tweens: Array[Tween] = []
			for y in range(ROWS):
				for x in range(COLS):
					var p: Piece = grid[y][x]
					if p == null:
						continue
					tweens.append(p.tween_to(p.position + Vector2(0, -8), 0.12))
			if not tweens.is_empty():
				await tweens[tweens.size() - 1].finished
			for y in range(ROWS):
				for x in range(COLS):
					var p: Piece = grid[y][x]
					if p == null:
						continue
					var new_kind: int = kind_grid[y][x]
					p.configure(new_kind, _color_for_kind(new_kind), Vector2i(x, y))
			emit_signal("shuffle_finished")
			state = State.IDLE
			return true
	state = State.IDLE
	emit_signal("shuffle_finished")
	return false

# Tap-then-tap UX as alternative to swipe. Tap a piece (it highlights), then
# tap an orthogonal neighbour to swap.
func tap_select(bp: Vector2i) -> void:
	# Any tap counts as input — kill the idle hint and reset its timer.
	_reset_hint_timer()
	if state != State.IDLE or _input_locked:
		return
	if _selected_cell == Vector2i(-1, -1):
		_selected_cell = bp
		var p: Piece = grid[bp.y][bp.x]
		if p != null:
			p.set_selected(true)
		Haptics.light_tap()
		return
	if _selected_cell == bp:
		_clear_selection()
		return
	var diff: Vector2i = bp - _selected_cell
	if abs(diff.x) + abs(diff.y) == 1:
		var prev := _selected_cell
		_clear_selection()
		request_swap(prev, bp)
	else:
		_clear_selection()
		_selected_cell = bp
		var p: Piece = grid[bp.y][bp.x]
		if p != null:
			p.set_selected(true)

func _clear_selection() -> void:
	if _selected_cell.x >= 0 and _selected_cell.y >= 0:
		var p: Piece = grid[_selected_cell.y][_selected_cell.x]
		if p != null:
			p.set_selected(false)
	_selected_cell = Vector2i(-1, -1)

func get_piece_at(bp: Vector2i) -> Piece:
	if not is_in_bounds(bp):
		return null
	return grid[bp.y][bp.x]

# --- No-moves hint ---
#
# When the player sits idle (state == IDLE and input unlocked) for
# HINT_IDLE_SECONDS, we scan once for any valid swap and pulse the two pieces
# involved so they catch the eye. The expensive scan only runs when the timer
# fires — not every frame.

func _process(delta: float) -> void:
	if state != State.IDLE or _input_locked:
		# Active board / locked input — don't pulse hints and don't decay the timer.
		_clear_hint()
		_hint_timer = HINT_IDLE_SECONDS
		return
	# Already showing a hint — keep it visible until input.
	if not _hint_pieces.is_empty():
		return
	if _hint_timer > 0.0:
		_hint_timer -= delta
		if _hint_timer <= 0.0:
			_show_hint()

func _reset_hint_timer() -> void:
	_hint_timer = HINT_IDLE_SECONDS
	_clear_hint()

func _show_hint() -> void:
	var pair: Array = NoMovesDetector.find_any_move(_kind_snapshot(), DIAGONAL_MIN_LENGTH)
	if pair.size() != 2:
		# No moves — shuffle will handle this elsewhere.
		return
	var a: Vector2i = pair[0]
	var b: Vector2i = pair[1]
	var pa: Piece = grid[a.y][a.x]
	var pb: Piece = grid[b.y][b.x]
	if pa == null or pb == null:
		return
	_hint_pieces = [pa, pb]
	for p in _hint_pieces:
		var t := create_tween()
		t.set_loops()
		t.tween_property(p, "scale", Vector2(HINT_PULSE_SCALE, HINT_PULSE_SCALE), HINT_PULSE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t.tween_property(p, "scale", Vector2(1.0, 1.0), HINT_PULSE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_hint_tweens.append(t)

func _clear_hint() -> void:
	for t in _hint_tweens:
		if t != null and t.is_running():
			t.kill()
	_hint_tweens.clear()
	for p in _hint_pieces:
		if p != null and is_instance_valid(p) and not p.is_selected:
			p.scale = Vector2.ONE
	_hint_pieces.clear()
