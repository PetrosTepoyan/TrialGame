class_name BattleActor
extends Node2D

@export var is_player: bool = true
@export var body_color: Color = Color(0.85, 0.78, 0.62)
@export var actor_label: String = "Hero"
@export var sprite_path: String = ""

const W: float = 110.0
const H: float = 170.0
const SPRITE_SCALE: float = 8.0  # Tiny Dungeon 16x16 -> 128x128

# Idle bob — gentle up/down breathing motion when not in another anim.
const IDLE_AMPLITUDE: float = 3.0
const IDLE_PERIOD: float = 1.5

# Attack — anticipation pull-back then forward lunge.
const ATTACK_PULLBACK_PX: float = 5.0
const ATTACK_LUNGE_PX: float = 30.0
const ATTACK_LIFT_PX: float = 8.0
const ATTACK_PULLBACK_TIME: float = 0.10
const ATTACK_LUNGE_TIME: float = 0.08
const ATTACK_SETTLE_TIME: float = 0.22

# Hurt — knockback away from attacker + flash + wobble.
const HURT_KNOCKBACK_PX: float = 26.0
const HURT_KNOCKBACK_TIME: float = 0.08
const HURT_RETURN_TIME: float = 0.22
const HURT_WOBBLE_DEG: float = 8.0

# Die — fall over and drift down.
const DIE_FALL_DEG: float = 90.0
const DIE_DRIFT_PX: float = 20.0
const DIE_TIME: float = 0.65

var _flash_white: float = 0.0
var _tween: Tween
var _idle_tween: Tween
var _sprite: Sprite2D = null
var _has_sprite: bool = false
var _base_position: Vector2 = Vector2.ZERO
var _is_busy: bool = false
var _is_dead: bool = false

func _ready() -> void:
	_sync_sprite()
	_base_position = position
	idle_bob()
	queue_redraw()

# Continuous subtle up/down idle motion. Starts on _ready and resumes after
# attack/hurt finish via _resume_idle.
func idle_bob() -> void:
	if _is_busy or _is_dead:
		return
	if _idle_tween != null and _idle_tween.is_running():
		_idle_tween.kill()
	_idle_tween = create_tween().set_loops()
	var half: float = IDLE_PERIOD * 0.5
	var up: Vector2 = _base_position + Vector2(0, -IDLE_AMPLITUDE)
	_idle_tween.tween_property(self, "position", up, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle_tween.tween_property(self, "position", _base_position, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _stop_idle() -> void:
	if _idle_tween != null and _idle_tween.is_running():
		_idle_tween.kill()

func override_sprite(path: String) -> void:
	if path == "" or not ResourceLoader.exists(path):
		return
	if _sprite != null:
		_sprite.queue_free()
		_sprite = null
		_has_sprite = false
	sprite_path = path
	_sync_sprite()

func _sync_sprite() -> void:
	var path: String = sprite_path
	if path == "":
		path = "res://assets/characters/hero.png" if is_player else "res://assets/characters/enemy.png"
	if not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path)
	if tex == null:
		return
	_sprite = Sprite2D.new()
	_sprite.texture = tex
	_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	if not is_player:
		_sprite.flip_h = true
	add_child(_sprite)
	_has_sprite = true

# Attack: small anticipation backward → forward lunge → settle home.
func attack() -> void:
	if _is_dead:
		return
	_kill_tween()
	_stop_idle()
	_is_busy = true
	var dir: float = 1.0 if is_player else -1.0
	var pull_back: Vector2 = _base_position + Vector2(-dir * ATTACK_PULLBACK_PX, 0)
	var lunge: Vector2 = _base_position + Vector2(dir * ATTACK_LUNGE_PX, -ATTACK_LIFT_PX)
	_tween = create_tween()
	# Anticipation — drift slightly away from target.
	_tween.tween_property(self, "position", pull_back, ATTACK_PULLBACK_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Lunge — snap forward with TRANS_BACK for crunchy overshoot.
	_tween.tween_property(self, "position", lunge, ATTACK_LUNGE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Settle — ease back home with a small bounce.
	_tween.tween_property(self, "position", _base_position, ATTACK_SETTLE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(_resume_idle)

# Hurt: knockback away from attacker, red flash, small angular wobble.
func hurt() -> void:
	if _is_dead:
		return
	_kill_tween()
	_stop_idle()
	_is_busy = true
	_flash_white = 1.0
	# Knockback direction: away from the opposing actor.
	var dir: float = -1.0 if is_player else 1.0
	var knock_to: Vector2 = _base_position + Vector2(dir * HURT_KNOCKBACK_PX, -4.0)
	# Position knockback and return.
	_tween = create_tween()
	_tween.tween_property(self, "position", knock_to, HURT_KNOCKBACK_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position", _base_position, HURT_RETURN_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(_resume_idle)
	# Flash fade.
	var flash := create_tween()
	flash.tween_method(_set_flash, 1.0, 0.0, 0.32)
	# Wobble — quick rotation flicker that ends at 0.
	var wob := create_tween()
	var wob_dir: float = 1.0 if (randi() & 1) == 0 else -1.0
	wob.tween_property(self, "rotation_degrees", wob_dir * HURT_WOBBLE_DEG, 0.05).set_trans(Tween.TRANS_SINE)
	wob.tween_property(self, "rotation_degrees", -wob_dir * (HURT_WOBBLE_DEG * 0.5), 0.07).set_trans(Tween.TRANS_SINE)
	wob.tween_property(self, "rotation_degrees", 0.0, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _resume_idle() -> void:
	if _is_dead:
		return
	_is_busy = false
	position = _base_position
	rotation_degrees = 0.0
	idle_bob()

func _set_flash(v: float) -> void:
	_flash_white = v
	if _sprite != null:
		_sprite.modulate = Color(1, 1, 1).lerp(Color(1.0, 0.4, 0.4), v * 0.7)
	queue_redraw()

# Die: rotate sideways, fade alpha, slight downward drift.
func die() -> void:
	_kill_tween()
	_stop_idle()
	_is_busy = true
	_is_dead = true
	var fall_dir: float = -1.0 if is_player else 1.0
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(self, "modulate:a", 0.0, DIE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_property(self, "rotation_degrees", fall_dir * DIE_FALL_DEG, DIE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_property(self, "position", _base_position + Vector2(0, DIE_DRIFT_PX), DIE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _kill_tween() -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()

func _draw() -> void:
	if _has_sprite:
		# Pixel-art sprite draws via the Sprite2D child. We still paint a small
		# shadow + faction tag underneath for depth.
		var shadow := Rect2(-W * 0.45, H * 0.42, W * 0.9, 12)
		draw_rect(shadow, Color(0, 0, 0, 0.35), true)
		return
	# Programmatic fallback if no sprite is loaded.
	var col := body_color.lerp(Color.WHITE, _flash_white * 0.7)
	var head_r: float = 28.0
	var head_center := Vector2(0, -H * 0.5 + head_r + 6)
	draw_circle(head_center, head_r, col)
	var torso_top: float = head_center.y + head_r * 0.6
	var torso_bot: float = H * 0.5 - 8
	var torso_rect := Rect2(-W * 0.32, torso_top, W * 0.64, torso_bot - torso_top)
	draw_rect(torso_rect, col, true)
	var belt := Rect2(torso_rect.position.x, torso_rect.position.y + torso_rect.size.y * 0.55, torso_rect.size.x, 8.0)
	draw_rect(belt, col.darkened(0.35), true)
	draw_circle(head_center + Vector2(-9, -3), 3, Color.BLACK)
	draw_circle(head_center + Vector2(9, -3), 3, Color.BLACK)
	if is_player:
		draw_line(Vector2(W * 0.3, -H * 0.10), Vector2(W * 0.46, -H * 0.42), Color(0.85, 0.85, 0.92), 5)
		draw_line(Vector2(W * 0.22, -H * 0.10), Vector2(W * 0.38, -H * 0.10), Color(0.55, 0.40, 0.20), 4)
	else:
		draw_line(Vector2(-W * 0.3, -H * 0.10), Vector2(-W * 0.40, -H * 0.45), Color(0.55, 0.40, 0.20), 5)
		var axe_head := PackedVector2Array([
			Vector2(-W * 0.40, -H * 0.45),
			Vector2(-W * 0.55, -H * 0.40),
			Vector2(-W * 0.48, -H * 0.32),
		])
		draw_colored_polygon(axe_head, Color(0.80, 0.82, 0.88))
	if _flash_white > 0.0:
		draw_rect(Rect2(-W * 0.5, -H * 0.5, W, H), Color(1, 1, 1, _flash_white * 0.35), true)
