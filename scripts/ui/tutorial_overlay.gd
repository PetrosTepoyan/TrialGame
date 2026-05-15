class_name TutorialOverlay
extends Control

signal dismissed

@onready var _continue_btn: Button = $Center/Panel/VBox/Continue

func _ready() -> void:
	visible = false
	# z_index above Piece's 5 and above the ShieldChoicePopup's 100 so the
	# overlay's Continue button actually receives taps; without this, board
	# pieces drew above and ate every touch, so mark_tutorial_seen() never
	# fired and the overlay reappeared on every battle.
	z_index = 200
	# Tutorial keeps running while the rest of the tree is paused — otherwise
	# the Continue button stops responding the moment we pause combat below.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_continue_btn.pressed.connect(_on_dismiss)
	mouse_filter = Control.MOUSE_FILTER_STOP

func show_once() -> void:
	if GameState.has_seen_tutorial():
		visible = false
		return
	visible = true
	AudioBus.play_panel_open()
	# Freeze the battle — player input, the enemy tick timer, tweens, etc. —
	# until the user dismisses the tutorial. The overlay itself runs because
	# its process_mode is ALWAYS.
	get_tree().paused = true

func _on_dismiss() -> void:
	# Unpause first so AudioBus (an autoload that inherits the tree's pause
	# state) can actually play the click/close stingers.
	visible = false
	get_tree().paused = false
	AudioBus.play_ui_click()
	AudioBus.play_panel_close()
	Haptics.light_tap()
	GameState.mark_tutorial_seen()
	emit_signal("dismissed")
