class_name MatchDetector
extends Object

# Returns Array of "match groups". Each group is an Array of Vector2i positions
# that share the same kind, formed from one or more overlapping runs of length >= 3
# in any of the 8 directions (4 axes).
#
# grid is Array[Array[int]] where -1 means empty and 0..3 is an army kind; 4 is
# the rainbow special. Rainbows are treated as wildcards: when adjacent to a run
# of any army kind they are folded into that run and additionally pull in EVERY
# other tile of that kind on the board.
#
# Diagonals are included unconditionally; a flag could later restrict diagonals
# to length-4+ matches if play-testing shows it's too easy.

static func find_matches(grid: Array, diagonal_min_length: int = 3) -> Array:
	var size_rows: int = grid.size()
	if size_rows == 0:
		return []
	var size_cols: int = grid[0].size()
	var runs: Array = []  # Array of Array of Vector2i, tagged with axis info
	var run_axes: Array = []  # parallel: "H" / "V" / "D" per run for corner detection
	# Axes: dx, dy, min_length, tag
	var axes := [
		[1, 0, 3, "H"],   # horizontal
		[0, 1, 3, "V"],   # vertical
		[1, 1, diagonal_min_length, "D"],  # diag down-right
		[1, -1, diagonal_min_length, "D"], # diag up-right
	]
	for axis in axes:
		var dx: int = axis[0]
		var dy: int = axis[1]
		var minlen: int = axis[2]
		var tag: String = axis[3]
		# Iterate each cell as a candidate run-start; only count it if previous
		# cell on this axis is different kind (or out of bounds), otherwise skip.
		for y in range(size_rows):
			for x in range(size_cols):
				var k: int = grid[y][x]
				# Phase D: ItemPiece cells will report kind == -1 and break runs naturally.
				if k < 0 or k == PieceType.Kind.RAINBOW:
					# Rainbows never start a run on their own — they only fold
					# into an existing army-kind run.
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
					run_axes.append(tag)
	# Standalone 2x2 squares — detected even when no axis-3 run exists.
	var squares: Array = _find_squares(grid, size_cols, size_rows)
	if runs.is_empty() and squares.is_empty():
		return []
	var merged: Array = _merge_overlapping(runs, run_axes, squares, grid)
	# Pull in rainbows adjacent (orthogonally OR diagonally) to any matched cell,
	# and then expand the cluster to include ALL board tiles of that kind.
	return _expand_rainbows(merged, grid, size_cols, size_rows)

# Returns Array of squares; each square is { "cells": [4 Vector2i], "kind": int }.
static func _find_squares(grid: Array, cols: int, rows: int) -> Array:
	var out: Array = []
	for y in range(rows - 1):
		for x in range(cols - 1):
			var k: int = grid[y][x]
			# Phase D: ItemPiece cells will report kind == -1 and break runs naturally.
			if k < 0 or k == PieceType.Kind.RAINBOW:
				continue
			if grid[y][x + 1] != k:
				continue
			if grid[y + 1][x] != k:
				continue
			if grid[y + 1][x + 1] != k:
				continue
			out.append({
				"kind": k,
				"cells": [
					Vector2i(x, y), Vector2i(x + 1, y),
					Vector2i(x, y + 1), Vector2i(x + 1, y + 1),
				],
			})
	return out

static func _expand_rainbows(groups: Array, grid: Array, cols: int, rows: int) -> Array:
	if groups.is_empty():
		return groups
	# Build the lookup of all rainbow positions once.
	var rainbow_cells: Array = []
	for y in range(rows):
		for x in range(cols):
			if grid[y][x] == PieceType.Kind.RAINBOW:
				rainbow_cells.append(Vector2i(x, y))
	if rainbow_cells.is_empty():
		return groups
	var dirs := [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1),
	]
	for g in groups:
		var k: int = g["kind"]
		var cell_set: Dictionary = {}
		for c in g["cells"]:
			cell_set[c] = true
		# Sweep: any rainbow touching a cell in this group joins it.
		var touched: Array = []
		for rc_v in rainbow_cells:
			var rc: Vector2i = rc_v
			for d in dirs:
				var neighbor: Vector2i = rc + d
				if cell_set.has(neighbor):
					touched.append(rc)
					break
		if touched.is_empty():
			continue
		# A rainbow is in the cluster — pull in every same-kind tile + every
		# touched rainbow tile.
		for tc in touched:
			cell_set[tc] = true
		for y in range(rows):
			for x in range(cols):
				if grid[y][x] == k:
					cell_set[Vector2i(x, y)] = true
		g["cells"] = cell_set.keys()
		g["had_rainbow"] = true
	return groups

# Merge runs that share at least one cell AND the same kind.
# `run_axes` is a parallel array tagging each run as "H", "V", or "D" so we can
# flag clusters that contain BOTH an H-run >=3 AND a V-run >=3 sharing a cell
# (an L-corner). `squares` are pre-detected 2x2 groups absorbed into matching
# clusters; standalone squares stay as their own group with `is_square=true`.
static func _merge_overlapping(runs: Array, run_axes: Array, squares: Array, grid: Array) -> Array:
	# Each item bundles a run-or-square's cells + flags so they merge uniformly.
	# axis: "H" | "V" | "D" | "S" (S = square; not used for corner flag).
	var items: Array = []
	for i in range(runs.size()):
		var first: Vector2i = runs[i][0]
		items.append({
			"kind": int(grid[first.y][first.x]),
			"cells": runs[i],
			"axis": String(run_axes[i]),
			"length": runs[i].size(),
		})
	for sq in squares:
		items.append({
			"kind": int(sq["kind"]),
			"cells": sq["cells"],
			"axis": "S",
			"length": 4,
		})
	# Group by kind first to avoid mixing.
	var by_kind: Dictionary = {}
	for it in items:
		var k: int = it["kind"]
		if not by_kind.has(k):
			by_kind[k] = []
		by_kind[k].append(it)
	var result: Array = []
	for k in by_kind.keys():
		var pool: Array = by_kind[k]
		while not pool.is_empty():
			var cluster: Dictionary = {}
			var has_h3: bool = false
			var has_v3: bool = false
			var has_square: bool = false
			var queue: Array = [pool.pop_back()]
			while not queue.is_empty():
				var it: Dictionary = queue.pop_back()
				for cell in it["cells"]:
					cluster[cell] = true
				if it["axis"] == "H" and int(it["length"]) >= 3:
					has_h3 = true
				elif it["axis"] == "V" and int(it["length"]) >= 3:
					has_v3 = true
				elif it["axis"] == "S":
					has_square = true
				var still_outside: Array = []
				for other in pool:
					var shares: bool = false
					for cell in other["cells"]:
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
				"is_square": has_square,
				"had_corner": has_h3 and has_v3,
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
