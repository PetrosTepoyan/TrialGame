class_name NoMovesDetector
extends Object

# Returns true if there exists at least one adjacent (orthogonal) swap that
# would produce a match of length >= 3 on any axis. Used to detect dead boards.
static func has_any_move(grid: Array, diagonal_min_length: int = 3) -> bool:
	return find_any_move(grid, diagonal_min_length) != []

# Same scan, but returns the (a, b) pair of cells whose swap produces a match.
# Empty Array when the board is dead. Rainbows ALWAYS produce a match when
# swapped with any in-bounds neighbour, so they short-circuit the search.
static func find_any_move(grid: Array, diagonal_min_length: int = 3) -> Array:
	var rows: int = grid.size()
	if rows == 0:
		return []
	var cols: int = grid[0].size()
	for y in range(rows):
		for x in range(cols):
			# Rainbow at (x, y) — any orthogonal swap with a non-rainbow tile
			# triggers its wildcard match. Prefer that as the hint.
			if grid[y][x] == PieceType.Kind.RAINBOW:
				if x + 1 < cols and grid[y][x + 1] != PieceType.Kind.RAINBOW:
					return [Vector2i(x, y), Vector2i(x + 1, y)]
				if y + 1 < rows and grid[y + 1][x] != PieceType.Kind.RAINBOW:
					return [Vector2i(x, y), Vector2i(x, y + 1)]
			# Try right swap
			if x + 1 < cols:
				if _swap_creates_match(grid, x, y, x + 1, y, diagonal_min_length):
					return [Vector2i(x, y), Vector2i(x + 1, y)]
			# Try down swap
			if y + 1 < rows:
				if _swap_creates_match(grid, x, y, x, y + 1, diagonal_min_length):
					return [Vector2i(x, y), Vector2i(x, y + 1)]
	return []

static func _swap_creates_match(grid: Array, x1: int, y1: int, x2: int, y2: int, dmin: int) -> bool:
	var k1: int = grid[y1][x1]
	var k2: int = grid[y2][x2]
	if k1 == k2:
		return false
	grid[y1][x1] = k2
	grid[y2][x2] = k1
	var has := _has_any_match_at(grid, x1, y1, dmin) or _has_any_match_at(grid, x2, y2, dmin)
	grid[y1][x1] = k1
	grid[y2][x2] = k2
	return has

static func _has_any_match_at(grid: Array, x: int, y: int, dmin: int) -> bool:
	var k: int = grid[y][x]
	if k < 0:
		return false
	var rows: int = grid.size()
	var cols: int = grid[0].size()
	var axes := [
		[Vector2i(1, 0), 3],
		[Vector2i(0, 1), 3],
		[Vector2i(1, 1), dmin],
		[Vector2i(1, -1), dmin],
	]
	for entry in axes:
		var d: Vector2i = entry[0]
		var minlen: int = entry[1]
		var count: int = 1
		var cx: int = x + d.x
		var cy: int = y + d.y
		while cx >= 0 and cy >= 0 and cx < cols and cy < rows and grid[cy][cx] == k:
			count += 1
			cx += d.x
			cy += d.y
		cx = x - d.x
		cy = y - d.y
		while cx >= 0 and cy >= 0 and cx < cols and cy < rows and grid[cy][cx] == k:
			count += 1
			cx -= d.x
			cy -= d.y
		if count >= minlen:
			return true
	return false
