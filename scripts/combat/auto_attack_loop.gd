class_name AutoAttackLoop
extends Node

# Periodic auto-attack timer. Re-randomizes the next interval after each tick
# so the rhythm reads natural rather than metronomic. Pauses while:
#   - the attacker is stunned (still ticks down — handled inside the actor's
#     status timer — but emits no damage)
#   - battle.gd has requested a pause around a spec animation
# The damage path is `target.take_damage(base_damage)` which respects armor.

signal auto_attacked(damage_dealt: int)

@export var interval: float = 2.0
@export var variance: float = 0.4  # +/- fraction of `interval` jittered per tick
@export var base_damage: int = 6

var attacker: CombatActor = null
var target: CombatActor = null

var _timer: Timer = null
var _paused_for_anim: bool = false
var _running: bool = false
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.autostart = false
	add_child(_timer)
	_timer.timeout.connect(_on_tick)

func start() -> void:
	if attacker == null or target == null:
		return
	_running = true
	_schedule_next()

func stop() -> void:
	_running = false
	if _timer != null:
		_timer.stop()

# Called by battle.gd to freeze auto-attacks while a spec animation plays.
func pause_for_anim() -> void:
	_paused_for_anim = true
	if _timer != null:
		_timer.paused = true

func resume_after_anim() -> void:
	_paused_for_anim = false
	if _timer != null:
		_timer.paused = false
	# If the loop was stopped while paused (e.g. we paused after the previous
	# tick completed and never re-scheduled), kick it again.
	if _running and _timer != null and _timer.is_stopped():
		_schedule_next()

func _schedule_next() -> void:
	if not _running or _timer == null:
		return
	var jitter: float = 1.0 + _rng.randf_range(-variance, variance) * 0.5
	var wait: float = max(0.2, interval * jitter)
	_timer.wait_time = wait
	_timer.start()

func _on_tick() -> void:
	if not _running:
		return
	if _paused_for_anim:
		# Re-schedule and let the pause re-fire when resumed.
		_schedule_next()
		return
	if attacker == null or target == null:
		_schedule_next()
		return
	if not attacker.is_alive() or not target.is_alive():
		stop()
		return
	if attacker.is_stunned():
		# Skip this tick; try again on the next scheduled interval.
		_schedule_next()
		return
	var dealt: int = target.take_damage(base_damage, false, 0)
	auto_attacked.emit(dealt)
	attacker.attacked.emit()
	if not target.is_alive():
		stop()
		return
	_schedule_next()
