class_name MatchDetector
extends Object

# Returns Array of "match groups". Each group is an Array of Vector2i positions
# that share the same kind, formed from one or more overlapping runs of length >= 3
# in any of the 8 directions (4 axes).
#
# grid is Array[Array[int]] where -1 means empty and 0..3 is kind.
#
# Diagonals are included unconditionally; a flag could later restrict diagonals
# to length-4+ matches if play-testing shows it's too easy.

static func find_matches(grid: Array, diagonal_min_length: int = 3) -> Array:
	var size_rows: int = grid.size()
	if size_rows == 0:
		return []
	var size_cols: int = grid[0].size()
	var runs: Array = []  # Array of Array of Vector2i
	# Axes: dx, dy, min_length
	var axes := [
		[1, 0, 3],   # horizontal
		[0, 1, 3],   # vertical
		[1, 1, diagonal_min_length],  # diag down-right
		[1, -1, diagonal_min_length], # diag up-right
	]
	for axis in axes:
		var dx: int = axis[0]
		var dy: int = axis[1]
		var minlen: int = axis[2]
		# Iterate each cell as a candidate run-start; only count it if previous
		# cell on this axis is different kind (or out of bounds), otherwise skip.
		for y in range(size_rows):
			for x in range(size_cols):
				var k: int = grid[y][x]
				if k < 0:
					continue
				var px: int = x - dx
				var py: int = y - dy
				if _in_bounds(px, py, size_cols, size_rows) and grid[py][px] == k:
					continue  # not a run start on this axis
				# Walk forward
				var run: Array = []
				var cx: int = x
				var cy: int = y
				while _in_bounds(cx, cy, size_cols, size_rows) and grid[cy][cx] == k:
					run.append(Vector2i(cx, cy))
					cx += dx
					cy += dy
				if run.size() >= minlen:
					runs.append(run)
	if runs.is_empty():
		return []
	return _merge_overlapping(runs, grid)

# Merge runs that share at least one cell AND the same kind.
static func _merge_overlapping(runs: Array, grid: Array) -> Array:
	# Group by kind first to avoid mixing.
	var by_kind: Dictionary = {}
	for run in runs:
		var first: Vector2i = run[0]
		var k: int = grid[first.y][first.x]
		if not by_kind.has(k):
			by_kind[k] = []
		by_kind[k].append(run)
	var result: Array = []
	for k in by_kind.keys():
		var pool: Array = by_kind[k]
		while not pool.is_empty():
			var cluster: Dictionary = {}
			var queue: Array = [pool.pop_back()]
			while not queue.is_empty():
				var run: Array = queue.pop_back()
				for cell in run:
					cluster[cell] = true
				var still_outside: Array = []
				for other in pool:
					var shares: bool = false
					for cell in other:
						if cluster.has(cell):
							shares = true
							break
					if shares:
						queue.append(other)
					else:
						still_outside.append(other)
				pool = still_outside
			result.append({
				"kind": k,
				"cells": cluster.keys(),
			})
	return result

# Convenience: longest run length within a match cluster (per-axis) — used to
# determine match-3/4/5 bonuses. Walks each axis from any cluster cell.
static func longest_axis_run_in(cluster_cells: Array, grid: Array) -> int:
	if cluster_cells.is_empty():
		return 0
	var k: int = grid[cluster_cells[0].y][cluster_cells[0].x]
	var cell_set: Dictionary = {}
	for c in cluster_cells:
		cell_set[c] = true
	var dirs := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]
	var best: int = 0
	for d in dirs:
		for cell in cluster_cells:
			# Walk backwards to find run start
			var start: Vector2i = cell
			while cell_set.has(start - d):
				start -= d
			# Walk forward to count length
			var length: int = 0
			var cur: Vector2i = start
			while cell_set.has(cur):
				length += 1
				cur += d
			if length > best:
				best = length
	return best

static func _in_bounds(x: int, y: int, cols: int, rows: int) -> bool:
	return x >= 0 and y >= 0 and x < cols and y < rows
