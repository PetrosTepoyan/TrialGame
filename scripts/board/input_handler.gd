class_name BoardInputHandler
extends Node2D

@export var board_path: NodePath
@onready var board: Board = get_node(board_path)

const SWIPE_THRESHOLD: float = 32.0
const TAP_MAX_DURATION: float = 0.35
const TAP_MAX_DISTANCE: float = 18.0

var _touch_active: bool = false
var _touch_start_pos: Vector2 = Vector2.ZERO
var _touch_start_cell: Vector2i = Vector2i(-1, -1)
var _touch_start_time: float = 0.0

func _unhandled_input(event: InputEvent) -> void:
	if board == null:
		return
	if not board.can_accept_input():
		return
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		var pos: Vector2 = _event_global_pos(event)
		var pressed: bool = (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed)
		if pressed:
			_begin_touch(pos)
		else:
			_end_touch(pos)
	elif event is InputEventScreenDrag or event is InputEventMouseMotion:
		if not _touch_active:
			return
		var pos: Vector2 = _event_global_pos(event)
		var delta: Vector2 = pos - _touch_start_pos
		if delta.length() >= SWIPE_THRESHOLD:
			_resolve_swipe(delta)

func _event_global_pos(event: InputEvent) -> Vector2:
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).position
	if event is InputEventScreenDrag:
		return (event as InputEventScreenDrag).position
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).position
	if event is InputEventMouseMotion:
		return (event as InputEventMouseMotion).position
	return Vector2.ZERO

func _begin_touch(global_pos: Vector2) -> void:
	var local: Vector2 = board.to_local(global_pos)
	var cell := board.world_to_board_pos(local)
	if not board.is_in_bounds(cell):
		_touch_active = false
		return
	_touch_active = true
	_touch_start_pos = global_pos
	_touch_start_cell = cell
	_touch_start_time = Time.get_ticks_msec() / 1000.0

func _resolve_swipe(delta: Vector2) -> void:
	if not _touch_active:
		return
	if not board.is_in_bounds(_touch_start_cell):
		_touch_active = false
		return
	var dir: Vector2i
	if abs(delta.x) > abs(delta.y):
		dir = Vector2i(1, 0) if delta.x > 0 else Vector2i(-1, 0)
	else:
		dir = Vector2i(0, 1) if delta.y > 0 else Vector2i(0, -1)
	var target: Vector2i = _touch_start_cell + dir
	if board.is_in_bounds(target):
		board.request_swap(_touch_start_cell, target)
	_touch_active = false

func _end_touch(global_pos: Vector2) -> void:
	if not _touch_active:
		return
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _touch_start_time
	var dist: float = (global_pos - _touch_start_pos).length()
	if elapsed <= TAP_MAX_DURATION and dist <= TAP_MAX_DISTANCE:
		board.tap_select(_touch_start_cell)
	_touch_active = false
