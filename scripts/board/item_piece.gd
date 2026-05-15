class_name ItemPiece
extends Piece

# A board cell that holds a BoardItem. Reports kind == -1 so match detectors
# skip it and runs naturally break across the cell. Integrity decrements when
# matches clear cells in 8-dir adjacency. At integrity 0, the item triggers
# and the board replaces this cell with a normal Piece.

var item: BoardItem = null
var integrity_remaining: int = 0

func configure_item(item_res: BoardItem) -> void:
	item = item_res
	integrity_remaining = max(1, item_res.integrity)
	# Poison the run detectors. Board.kind == -1 cells never join a match.
	kind = -1
	color = item_res.tint if item_res != null else Color(0.3, 0.3, 0.3)
	queue_redraw()

func decrement_integrity(by_count: int = 1) -> bool:
	# Returns true when integrity hits 0 (item should trigger now).
	if integrity_remaining <= 0:
		return false
	integrity_remaining -= by_count
	if integrity_remaining < 0:
		integrity_remaining = 0
	queue_redraw()
	return integrity_remaining <= 0

# Items don't participate in selection / swap UX. Override to no-op so any
# accidental tap doesn't scale or highlight the item cell.
func set_selected(_value: bool) -> void:
	is_selected = false

# Override Piece._ready: skip the sprite swap-in (items draw themselves only).
func _ready() -> void:
	z_index = 6  # one above regular pieces so it always reads on top

func _draw() -> void:
	var half: float = Piece.SIZE * 0.5
	var rect := Rect2(-half, -half, Piece.SIZE, Piece.SIZE)
	# Backdrop in the item tint (or grey fallback).
	var fill: Color = item.tint if item != null else Color(0.3, 0.3, 0.3)
	draw_rect(rect, fill, true)
	# Heavy black border so the item visually pops vs neighbour pieces.
	draw_rect(rect.grow(-2), Color.BLACK, false, 4.0)
	# Integrity counter / short name. Show the count when >1 so the player can
	# track adjacent-match cost; show a short label on the last hit so the
	# effect is hinted before it triggers.
	if item != null:
		var label: String = str(integrity_remaining) if integrity_remaining > 1 else item.display_name.substr(0, 4)
		var font: Font = ThemeDB.fallback_font
		draw_string(font, Vector2(-18.0, 12.0), label, HORIZONTAL_ALIGNMENT_CENTER, -1, 36, Color.WHITE)
