class_name TutorialOverlay
extends Control

signal dismissed

@onready var _continue_btn: Button = $Center/Panel/VBox/Continue

func _ready() -> void:
	visible = false
	_continue_btn.pressed.connect(_on_dismiss)
	mouse_filter = Control.MOUSE_FILTER_STOP

func show_once() -> void:
	if GameState.has_seen_tutorial():
		visible = false
		return
	visible = true

func _on_dismiss() -> void:
	GameState.mark_tutorial_seen()
	visible = false
	emit_signal("dismissed")
