class_name ShakeDetector
extends Node

## Polls Input.get_accelerometer() and emits shake_detected when shaken.
## Editor fallback: Ctrl+D or Meta+D.

signal shake_detected()

const SHAKE_THRESHOLD: float = 2.5
const WINDOW_SIZE: int = 8
const SPIKES_REQUIRED: int = 2
const COOLDOWN_SECONDS: float = 1.5

var _spike_history: Array[bool] = []
var _last_trigger_time_msec: int = -100000


func _ready() -> void:
	_spike_history.resize(WINDOW_SIZE)
	for i in range(WINDOW_SIZE):
		_spike_history[i] = false
	set_process(true)
	set_process_unhandled_input(true)


func _process(_delta: float) -> void:
	var accel: Vector3 = Input.get_accelerometer()
	var magnitude: float = accel.length()
	# Platforms without an accelerometer (macOS editor, desktop, headless) report
	# Vector3.ZERO — treat that as "no signal" rather than as a constant 9.8-m/s²
	# spike against a gravity baseline.
	if magnitude < 0.1:
		_spike_history.pop_front()
		_spike_history.append(false)
		return
	# Subtract a rough gravity baseline so a still device reads ~0.
	var shifted: float = absf(magnitude - 9.8)
	var is_spike: bool = shifted > SHAKE_THRESHOLD

	_spike_history.pop_front()
	_spike_history.append(is_spike)

	var spike_count: int = 0
	for s in _spike_history:
		if s:
			spike_count += 1

	if spike_count >= SPIKES_REQUIRED:
		_try_trigger()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event: InputEventKey = event
		if key_event.keycode == KEY_D and (key_event.ctrl_pressed or key_event.meta_pressed):
			_try_trigger()


func _try_trigger() -> void:
	var now_msec: int = Time.get_ticks_msec()
	if now_msec - _last_trigger_time_msec < int(COOLDOWN_SECONDS * 1000.0):
		return
	_last_trigger_time_msec = now_msec
	# Clear history so we don't re-trigger immediately.
	for i in range(WINDOW_SIZE):
		_spike_history[i] = false
	shake_detected.emit()
