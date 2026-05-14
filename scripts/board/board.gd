class_name Board
extends Node2D

signal swap_animated
signal match_resolved(kind: int, count: int, longest_run: int)
signal cascade_finished(total_matches: int, cascade_depth: int)
signal invalid_swap
signal shuffle_started
signal shuffle_finished

const ROWS := 9
const COLS := 9
const CELL: float = Piece.SIZE
const SPACING: float = 4.0
const MAX_CASCADE_DEPTH := 20
const DIAGONAL_MIN_LENGTH := 3  # set to 4 to dial down match frequency

enum State { IDLE, SWAPPING, RESOLVING, SHUFFLING }

@export var piece_types: Array[PieceType] = []

var grid: Array = []  # rows x cols of Piece (or null)
var state: int = State.IDLE
var _input_locked: bool = false  # owner (CombatController) locks during enemy turn
var _selected_cell: Vector2i = Vector2i(-1, -1)
var _piece_layer: Node2D
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_piece_layer = Node2D.new()
	_piece_layer.name = "Pieces"
	add_child(_piece_layer)
	if piece_types.is_empty():
		piece_types = _default_piece_types()
	populate_new_board()

func _default_piece_types() -> Array[PieceType]:
	# Fallback when designer hasn't wired .tres files in the editor.
	var arr: Array[PieceType] = []
	var defs := [
		{"kind": PieceType.Kind.KING,   "name": "King",   "color": Color(0.95, 0.78, 0.30), "base": 5},
		{"kind": PieceType.Kind.SHIELD, "name": "Shield", "color": Color(0.40, 0.62, 0.95), "base": 4},
		{"kind": PieceType.Kind.SPEAR,  "name": "Spear",  "color": Color(0.85, 0.32, 0.32), "base": 5},
		{"kind": PieceType.Kind.ARCHER, "name": "Archer", "color": Color(0.40, 0.82, 0.50), "base": 4},
	]
	for d in defs:
		var pt := PieceType.new()
		pt.kind = d["kind"]
		pt.display_name = d["name"]
		pt.color = d["color"]
		pt.base_value = d["base"]
		arr.append(pt)
	return arr

func populate_new_board() -> void:
	_clear_all_pieces()
	# Build kind grid first; reroll cells that would form pre-existing matches.
	var kind_grid: Array = []
	for y in range(ROWS):
		var row: Array = []
		for x in range(COLS):
			row.append(-1)
		kind_grid.append(row)
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
	# Instantiate pieces.
	for y in range(ROWS):
		for x in range(COLS):
			var piece := _make_piece(kind_grid[y][x], Vector2i(x, y))
			_piece_layer.add_child(piece)
			grid[y][x] = piece

func _pick_kind_without_match(kind_grid: Array, x: int, y: int) -> int:
	var candidates: Array[int] = [0, 1, 2, 3]
	candidates.shuffle()
	for k in candidates:
		kind_grid[y][x] = k
		if not _creates_immediate_match(kind_grid, x, y):
			return k
	kind_grid[y][x] = candidates[0]
	return candidates[0]

func _creates_immediate_match(kind_grid: Array, x: int, y: int) -> bool:
	var k: int = kind_grid[y][x]
	if k < 0:
		return false
	# Horizontal: 2 cells to the left same?
	if x >= 2 and kind_grid[y][x - 1] == k and kind_grid[y][x - 2] == k:
		return true
	# Vertical: 2 above same?
	if y >= 2 and kind_grid[y - 1][x] == k and kind_grid[y - 2][x] == k:
		return true
	# Diagonal down-right (looking up-left)
	if x >= 2 and y >= 2 and kind_grid[y - 1][x - 1] == k and kind_grid[y - 2][x - 2] == k:
		return true
	# Diagonal up-right (looking down-left)
	if x >= 2 and y <= ROWS - 3 and kind_grid[y + 1][x - 1] == k and kind_grid[y + 2][x - 2] == k:
		return true
	return false

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
	p.configure(kind, piece_types[kind].color, board_pos)
	p.position = board_pos_to_world(board_pos)
	return p

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
	if state != State.IDLE:
		return false
	if not is_in_bounds(a) or not is_in_bounds(b):
		return false
	var diff: Vector2i = b - a
	# Must be orthogonally adjacent
	if abs(diff.x) + abs(diff.y) != 1:
		return false
	state = State.SWAPPING
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
	var t1 := pa.tween_to(board_pos_to_world(b))
	var t2 := pb.tween_to(board_pos_to_world(a))
	# Await the longer tween
	await t1.finished
	await t2.finished
	if check_match:
		var groups := _find_matches()
		if groups.is_empty():
			# Swap back
			await _do_swap(b, a, false)
			emit_signal("invalid_swap")
			return
		# Resolve cascades — _resolve_cascade is responsible for restoring IDLE
		# state before emitting cascade_finished so signal handlers can chain.
		state = State.RESOLVING
		await _resolve_cascade()
	else:
		state = State.IDLE

func _find_matches() -> Array:
	var kind_grid: Array = _kind_snapshot()
	return MatchDetector.find_matches(kind_grid, DIAGONAL_MIN_LENGTH)

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
		# Emit per-group events
		var kind_grid := _kind_snapshot()
		for g in groups:
			var k: int = g["kind"]
			var cells: Array = g["cells"]
			var longest: int = MatchDetector.longest_axis_run_in(cells, kind_grid)
			emit_signal("match_resolved", k, cells.size(), longest)
		# Remove cells
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
		# Wait for removal animation
		if not remove_tweens.is_empty():
			await remove_tweens[remove_tweens.size() - 1].finished
		for p in pieces_to_free:
			p.queue_free()
		# Apply gravity + refill
		await _apply_gravity_and_refill()
		depth += 1
	state = State.IDLE
	emit_signal("cascade_finished", total, depth)

func _apply_gravity_and_refill() -> void:
	var tweens: Array[Tween] = []
	# Gravity: for each column, slide non-null pieces down
	for x in range(COLS):
		var write_y: int = ROWS - 1
		for y in range(ROWS - 1, -1, -1):
			var p: Piece = grid[y][x]
			if p != null:
				if y != write_y:
					grid[write_y][x] = p
					grid[y][x] = null
					p.board_pos = Vector2i(x, write_y)
					tweens.append(p.tween_to(board_pos_to_world(p.board_pos), 0.22))
				write_y -= 1
		# Refill from top
		var spawn_index: int = 0
		for y in range(write_y, -1, -1):
			var kind: int = _rng.randi() % piece_types.size()
			var p := _make_piece(kind, Vector2i(x, y))
			_piece_layer.add_child(p)
			grid[y][x] = p
			# Start above the board, drop in
			var step: float = CELL + SPACING
			p.position = Vector2(p.position.x, -step * (spawn_index + 1) - step * 0.5)
			tweens.append(p.tween_to(board_pos_to_world(Vector2i(x, y)), 0.25))
			spawn_index += 1
	if tweens.is_empty():
		return
	await tweens[tweens.size() - 1].finished

# Shuffle: rebuild the kind layout in-place if there are no available moves.
func shuffle_board_if_dead() -> bool:
	var kg := _kind_snapshot()
	if NoMovesDetector.has_any_move(kg, DIAGONAL_MIN_LENGTH):
		return false
	state = State.SHUFFLING
	emit_signal("shuffle_started")
	# Repick kinds with no pre-existing matches and at least one move.
	for attempt in range(10):
		var kind_grid: Array = []
		for y in range(ROWS):
			var row: Array = []
			for x in range(COLS):
				row.append(-1)
			kind_grid.append(row)
		for y in range(ROWS):
			for x in range(COLS):
				kind_grid[y][x] = _pick_kind_without_match(kind_grid, x, y)
		if NoMovesDetector.has_any_move(kind_grid, DIAGONAL_MIN_LENGTH):
			# Animate: shrink existing, swap kinds, grow back.
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
					p.configure(new_kind, piece_types[new_kind].color, Vector2i(x, y))
			emit_signal("shuffle_finished")
			state = State.IDLE
			return true
	state = State.IDLE
	emit_signal("shuffle_finished")
	return false

# Select first piece (tap), then second (tap-adjacent) — alt to swipe.
func tap_select(bp: Vector2i) -> void:
	if state != State.IDLE:
		return
	if _selected_cell == Vector2i(-1, -1):
		_selected_cell = bp
		var p: Piece = grid[bp.y][bp.x]
		if p != null:
			p.set_selected(true)
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
		# Move selection to new cell
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

# Remove all pieces of a given kind (used by King special / match-5 bonus).
func clear_kind(kind: int) -> int:
	var removed: int = 0
	var freed: Array[Piece] = []
	var last_tween: Tween = null
	for y in range(ROWS):
		for x in range(COLS):
			var p: Piece = grid[y][x]
			if p != null and p.kind == kind:
				last_tween = p.tween_remove()
				freed.append(p)
				grid[y][x] = null
				removed += 1
	if last_tween != null:
		await last_tween.finished
	for p in freed:
		p.queue_free()
	return removed

# Remove a whole row (used by King special).
func clear_row(y: int) -> int:
	if y < 0 or y >= ROWS:
		return 0
	var removed: int = 0
	var freed: Array[Piece] = []
	var last_tween: Tween = null
	for x in range(COLS):
		var p: Piece = grid[y][x]
		if p != null:
			last_tween = p.tween_remove()
			freed.append(p)
			grid[y][x] = null
			removed += 1
	if last_tween != null:
		await last_tween.finished
	for p in freed:
		p.queue_free()
	return removed

# After external clears, drive the cascade resolution loop.
func resolve_externally() -> void:
	state = State.RESOLVING
	await _apply_gravity_and_refill()
	await _resolve_cascade()
