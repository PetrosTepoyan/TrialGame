extends Node

# Haptics autoload. Wraps Input.vibrate_handheld behind a semantic API so the
# rest of the codebase calls intent (light_tap, success, warning, ...) instead
# of raw vibration parameters. Mirrors AudioBus' toggleable pattern with a
# private _enabled flag and getter/setter pair.
#
# Platform notes:
#   - On iOS, Input.vibrate_handheld maps to UIImpactFeedbackGenerator-style
#     taptic feedback. Amplitude is ignored (iOS uses fixed strengths), so
#     "heavier" cues are simulated by layering short pulses.
#   - On Android, amplitude (0..1) is honored.
#   - On desktop (macOS editor, Windows, Linux), every call is a silent no-op
#     so devs hitting Play don't trigger anything.
#
# Throttle: match cascades emit `match_resolved` many times back-to-back; we
# cap to one haptic per MIN_INTERVAL_MS to avoid a buzzing brick.

const MIN_INTERVAL_MS: int = 30

const LIGHT_MS: int = 12
const MEDIUM_MS: int = 22
const HEAVY_MS: int = 40

const LIGHT_AMP: float = 0.35
const MEDIUM_AMP: float = 0.6
const HEAVY_AMP: float = 1.0

var _enabled: bool = true
var _platform: String = ""
var _last_fired_ms: int = 0

func _ready() -> void:
	_platform = OS.get_name()

# Semantic API -----------------------------------------------------------------

func light_tap() -> void:
	# Selection, button presses, tap-select, per-match cascade tick.
	_fire(LIGHT_MS, LIGHT_AMP)

func medium_tap() -> void:
	# Successful swap, emblem added.
	_fire(MEDIUM_MS, MEDIUM_AMP)

func heavy_tap() -> void:
	# Combo, round execute, taking damage.
	_fire(HEAVY_MS, HEAVY_AMP)

func success() -> void:
	# Round won, level cleared. Two-pulse pattern.
	pulse(2, 28, 90)

func warning() -> void:
	# Invalid swap, low HP. Three short staccato pulses.
	pulse(3, 14, 70)

func failure() -> void:
	# Defeat. One long heavy buzz.
	_fire(180, HEAVY_AMP)

func pulse(count: int, ms: int, gap_ms: int) -> void:
	# Generic pattern helper. Schedules N pulses separated by gap_ms each.
	if not _can_fire():
		return
	for i in range(count):
		var delay: float = float(i * (ms + gap_ms)) / 1000.0
		if delay <= 0.0:
			_vibrate(ms, HEAVY_AMP)
		else:
			get_tree().create_timer(delay).timeout.connect(_vibrate.bind(ms, HEAVY_AMP), CONNECT_ONE_SHOT)

# Settings toggle --------------------------------------------------------------

func enabled() -> bool:
	return _enabled

func set_enabled(value: bool) -> void:
	_enabled = value

# Internal ---------------------------------------------------------------------

func _fire(duration_ms: int, amplitude: float) -> void:
	if not _can_fire():
		return
	_vibrate(duration_ms, amplitude)

func _can_fire() -> bool:
	if not _enabled:
		return false
	if _platform != "iOS" and _platform != "Android":
		return false
	var now: int = Time.get_ticks_msec()
	if now - _last_fired_ms < MIN_INTERVAL_MS:
		return false
	_last_fired_ms = now
	return true

func _vibrate(duration_ms: int, amplitude: float) -> void:
	# Stock Godot 4.6 signature: vibrate_handheld(duration_ms: int = 500,
	# amplitude: float = -1.0). amplitude is only honored on Android; iOS uses
	# fixed taptic strengths.
	if _platform == "iOS":
		Input.vibrate_handheld(duration_ms)
	elif _platform == "Android":
		Input.vibrate_handheld(duration_ms, amplitude)
