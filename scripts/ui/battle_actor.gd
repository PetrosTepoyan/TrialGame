class_name BattleActor
extends Node2D

@export var is_player: bool = true
@export var body_color: Color = Color(0.85, 0.78, 0.62)
@export var actor_label: String = "Hero"
@export var sprite_path: String = ""

const W: float = 110.0
const H: float = 170.0
const SPRITE_SCALE: float = 8.0  # Tiny Dungeon 16x16 -> 128x128

var _shake_amount: float = 0.0
var _flash_white: float = 0.0
var _tween: Tween
var _sprite: Sprite2D = null
var _has_sprite: bool = false

func _ready() -> void:
	_sync_sprite()
	queue_redraw()

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

func attack() -> void:
	_kill()
	var dir: float = 1.0 if is_player else -1.0
	var start: Vector2 = position
	_tween = create_tween()
	_tween.tween_property(self, "position", start + Vector2(dir * 24, -6), 0.10).set_trans(Tween.TRANS_QUAD)
	_tween.tween_property(self, "position", start, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func hurt() -> void:
	_flash_white = 1.0
	if _sprite != null:
		_sprite.modulate = Color(1.0, 0.4, 0.4)
	queue_redraw()
	var t := create_tween()
	t.tween_method(_set_flash, 1.0, 0.0, 0.25)
	var origin := position
	var shake := create_tween()
	for i in range(6):
		shake.tween_property(self, "position", origin + Vector2(randf_range(-6.0, 6.0), randf_range(-4.0, 4.0)), 0.04)
	shake.tween_property(self, "position", origin, 0.06)

func _set_flash(v: float) -> void:
	_flash_white = v
	if _sprite != null:
		_sprite.modulate = Color(1, 1, 1).lerp(Color(1.0, 0.4, 0.4), v * 0.7)
	queue_redraw()

func die() -> void:
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.6)
	t.parallel().tween_property(self, "rotation_degrees", -85.0 if is_player else 85.0, 0.6)

func _kill() -> void:
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
