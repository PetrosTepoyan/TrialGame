extends Control

## Debug menu UI built programmatically at runtime (no .tscn editing needed
## beyond the wrapper scene).

var _overlay: Node = null
var _tab_container: TabContainer = null

# Cheat state polled in _process.
var _invincible: bool = false
var _always_full_scale: bool = false
var _last_player_hp: int = -1

# Stats labels (rebuilt each frame in the Stats tab).
var _stats_label: Label = null

# Sliders we need to read out for overrides.
var _slider_paths: Dictionary = {}  # Slider/SpinBox -> override path


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()


func setup(overlay: Node) -> void:
	_overlay = overlay


# ---- UI construction -------------------------------------------------------

func _build_ui() -> void:
	# Dim background.
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 16
	panel.offset_right = -16
	panel.offset_top = 64
	panel.offset_bottom = -64
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	# Header row.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	vbox.add_child(header)

	var title := Label.new()
	title.text = "DEBUG"
	title.add_theme_font_size_override("font_size", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(80, 44)
	close_btn.pressed.connect(_on_close_pressed)
	header.add_child(close_btn)

	_tab_container = TabContainer.new()
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_tab_container)

	_tab_container.add_child(_build_stats_tab())
	_tab_container.add_child(_build_combat_tab())
	_tab_container.add_child(_build_board_tab())
	_tab_container.add_child(_build_audio_tab())
	_tab_container.add_child(_build_haptics_tab())
	_tab_container.add_child(_build_progression_tab())
	_tab_container.add_child(_build_cheats_tab())

	# Footer.
	var footer := HBoxContainer.new()
	vbox.add_child(footer)

	var clear_btn := Button.new()
	clear_btn.text = "Clear All Overrides"
	clear_btn.custom_minimum_size = Vector2(0, 44)
	clear_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clear_btn.pressed.connect(_on_clear_overrides_pressed)
	footer.add_child(clear_btn)


func _make_tab(tab_name: String) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.name = tab_name
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var vbox := VBoxContainer.new()
	vbox.name = "Content"
	vbox.add_theme_constant_override("separation", 6)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)
	return scroll


func _tab_content(scroll: ScrollContainer) -> VBoxContainer:
	return scroll.get_node("Content") as VBoxContainer


# ---- Stats tab -------------------------------------------------------------

func _build_stats_tab() -> ScrollContainer:
	var scroll := _make_tab("Stats")
	var vbox := _tab_content(scroll)
	_stats_label = Label.new()
	_stats_label.text = "..."
	_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_stats_label)
	return scroll


# ---- Combat tab ------------------------------------------------------------

func _build_combat_tab() -> ScrollContainer:
	var scroll := _make_tab("Combat")
	var vbox := _tab_content(scroll)

	vbox.add_child(_section_header("Tunables"))

	_add_spin_row(vbox, "Match-3 damage", "combat.damage_match3", 4, 0, 999, 1)
	_add_spin_row(vbox, "Match-4 damage", "combat.damage_match4", 8, 0, 999, 1)
	_add_spin_row(vbox, "Match-5 damage", "combat.damage_match5", 16, 0, 999, 1)
	_add_spin_row(vbox, "Cascade bonus mult", "combat.cascade_mult", 1.0, 0.0, 5.0, 0.1)
	_add_spin_row(vbox, "Player max HP", "combat.player_max_hp", 30, 1, 9999, 1)
	_add_spin_row(vbox, "Enemy max HP", "combat.enemy_max_hp", 30, 1, 9999, 1)
	_add_spin_row(vbox, "Enemy action scale size", "combat.enemy_scale_size", 5, 1, 20, 1)

	vbox.add_child(_section_header("Quick Actions"))

	_add_button(vbox, "Heal player to full", _on_heal_player)
	_add_button(vbox, "Kill enemy", _on_kill_enemy)
	_add_button(vbox, "Stun enemy 99 rounds", _on_stun_enemy)
	_add_button(vbox, "Fill enemy action scale", _on_fill_scale)

	return scroll


# ---- Board tab -------------------------------------------------------------

func _build_board_tab() -> ScrollContainer:
	var scroll := _make_tab("Board")
	var vbox := _tab_content(scroll)

	vbox.add_child(_section_header("Constants"))

	var board: Node = _find_board()
	var diag_value: Variant = "?"
	var cascade_value: Variant = "?"
	if board:
		var s: Script = board.get_script()
		if s:
			var consts: Dictionary = s.get_script_constant_map()
			if consts.has("DIAGONAL_MIN_LENGTH"):
				diag_value = consts["DIAGONAL_MIN_LENGTH"]
			if consts.has("MAX_CASCADE_DEPTH"):
				cascade_value = consts["MAX_CASCADE_DEPTH"]
	var c_label := Label.new()
	c_label.text = "DIAGONAL_MIN_LENGTH = %s\nMAX_CASCADE_DEPTH = %s" % [str(diag_value), str(cascade_value)]
	vbox.add_child(c_label)

	vbox.add_child(_section_header("Actions"))
	_add_button(vbox, "Force reshuffle", _on_reshuffle)
	_add_button(vbox, "Spawn rainbow at top-left", _on_spawn_rainbow)

	return scroll


# ---- Audio tab -------------------------------------------------------------

func _build_audio_tab() -> ScrollContainer:
	var scroll := _make_tab("Audio")
	var vbox := _tab_content(scroll)

	vbox.add_child(_section_header("Volumes"))

	var audio_bus: Node = get_node_or_null("/root/AudioBus")
	var has_sfx: bool = audio_bus != null and audio_bus.has_method("set_sfx_volume")
	var has_music: bool = audio_bus != null and audio_bus.has_method("set_music_volume")

	if has_sfx:
		_add_audio_slider(vbox, "SFX volume", "set_sfx_volume", "get_sfx_volume", audio_bus)
	else:
		vbox.add_child(_dim_label("AudioBus.set_sfx_volume not present"))

	if has_music:
		_add_audio_slider(vbox, "Music volume", "set_music_volume", "get_music_volume", audio_bus)
	else:
		vbox.add_child(_dim_label("AudioBus.set_music_volume not present"))

	vbox.add_child(_section_header("Play SFX"))
	_add_button(vbox, "Play match", func() -> void: _play_audio("play_match"))
	_add_button(vbox, "Play hit", func() -> void: _play_audio("play_hit"))
	_add_button(vbox, "Play combo L1", func() -> void: _play_audio("play_combo", [1]))
	_add_button(vbox, "Play combo L2", func() -> void: _play_audio("play_combo", [2]))
	_add_button(vbox, "Play combo L3", func() -> void: _play_audio("play_combo", [3]))

	return scroll


# ---- Haptics tab -----------------------------------------------------------

func _build_haptics_tab() -> ScrollContainer:
	var scroll := _make_tab("Haptics")
	var vbox := _tab_content(scroll)
	var haptics: Node = get_node_or_null("/root/Haptics")
	if haptics == null:
		vbox.add_child(_dim_label("Haptics autoload not present"))
		return scroll

	var toggle := CheckBox.new()
	toggle.text = "Enabled"
	toggle.custom_minimum_size = Vector2(0, 44)
	# Best-effort feature detect.
	var enabled: bool = true
	if "enabled" in haptics:
		enabled = bool(haptics.get("enabled"))
	elif haptics.has_method("is_enabled"):
		enabled = bool(haptics.call("is_enabled"))
	toggle.button_pressed = enabled
	toggle.toggled.connect(func(state: bool) -> void:
		if "enabled" in haptics:
			haptics.set("enabled", state)
		elif haptics.has_method("set_enabled"):
			haptics.call("set_enabled", state)
	)
	vbox.add_child(toggle)

	vbox.add_child(_section_header("Trigger"))

	var apis: Array = [
		"light_tap", "medium_tap", "heavy_tap",
		"success", "warning", "failure",
	]
	for api_name in apis:
		var api: String = api_name
		if haptics.has_method(api):
			_add_button(vbox, api, func() -> void: haptics.call(api))
		else:
			vbox.add_child(_dim_label("%s (not present)" % api))
	return scroll


# ---- Progression tab -------------------------------------------------------

func _build_progression_tab() -> ScrollContainer:
	var scroll := _make_tab("Progression")
	var vbox := _tab_content(scroll)
	var gs: Node = get_node_or_null("/root/GameState")
	var info_label := Label.new()
	info_label.text = _progression_text(gs)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(info_label)

	vbox.add_child(_section_header("Actions"))
	_add_button(vbox, "Skip level", _on_skip_level)
	_add_button(vbox, "Reset save", _on_reset_save)
	_add_button(vbox, "Go to victory", _on_goto_victory)
	_add_button(vbox, "Go to game over", _on_goto_gameover)
	return scroll


func _progression_text(gs: Node) -> String:
	if gs == null:
		return "GameState autoload not present"
	var parts: Array[String] = []
	for key in ["castle", "chapter", "level", "current_castle", "current_chapter", "current_level"]:
		if key in gs:
			parts.append("%s = %s" % [key, str(gs.get(key))])
	if parts.is_empty():
		return "GameState: no recognizable progression keys"
	return "\n".join(parts)


# ---- Cheats tab ------------------------------------------------------------

func _build_cheats_tab() -> ScrollContainer:
	var scroll := _make_tab("Cheats")
	var vbox := _tab_content(scroll)

	var inv_toggle := CheckBox.new()
	inv_toggle.text = "Invincible player"
	inv_toggle.custom_minimum_size = Vector2(0, 44)
	inv_toggle.button_pressed = _invincible
	inv_toggle.toggled.connect(func(state: bool) -> void:
		_invincible = state
		_last_player_hp = -1
		if _overlay:
			_overlay.set_override("cheat.invincible", state)
	)
	vbox.add_child(inv_toggle)

	var scale_toggle := CheckBox.new()
	scale_toggle.text = "Always-full action scale"
	scale_toggle.custom_minimum_size = Vector2(0, 44)
	scale_toggle.button_pressed = _always_full_scale
	scale_toggle.toggled.connect(func(state: bool) -> void:
		_always_full_scale = state
		if _overlay:
			_overlay.set_override("cheat.always_full_scale", state)
	)
	vbox.add_child(scale_toggle)

	_add_button(vbox, "Kill enemy now", _on_kill_enemy)
	return scroll


# ---- Helpers ---------------------------------------------------------------

func _section_header(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 16)
	return lbl


func _dim_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.modulate = Color(1, 1, 1, 0.6)
	return lbl


func _add_button(parent: Node, text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(callback)
	parent.add_child(b)
	return b


func _add_spin_row(parent: Node, label: String, override_path: String, default_value: float, min_v: float, max_v: float, step_v: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var lbl := Label.new()
	lbl.text = label
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	var spin := SpinBox.new()
	spin.min_value = min_v
	spin.max_value = max_v
	spin.step = step_v
	spin.custom_minimum_size = Vector2(120, 44)
	var current: Variant = default_value
	if _overlay:
		current = _overlay.get_override(override_path, default_value)
	spin.value = float(current)
	spin.value_changed.connect(func(v: float) -> void:
		if _overlay:
			_overlay.set_override(override_path, v)
	)
	row.add_child(spin)
	_slider_paths[spin] = override_path


func _add_audio_slider(parent: Node, label: String, setter: String, getter: String, audio_bus: Node) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var lbl := Label.new()
	lbl.text = label
	lbl.custom_minimum_size = Vector2(120, 0)
	row.add_child(lbl)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(0, 44)
	var current: float = 1.0
	if audio_bus.has_method(getter):
		current = float(audio_bus.call(getter))
	slider.value = current
	slider.value_changed.connect(func(v: float) -> void:
		if audio_bus.has_method(setter):
			audio_bus.call(setter, v)
	)
	row.add_child(slider)


# ---- Frame work ------------------------------------------------------------

func _process(_delta: float) -> void:
	if not visible:
		# Still apply cheats even when menu is closed.
		_apply_cheats()
		return
	_apply_cheats()
	if _stats_label:
		_stats_label.text = _build_stats_text()


func _build_stats_text() -> String:
	var lines: Array[String] = []
	lines.append("FPS: %d" % Engine.get_frames_per_second())
	var draw_calls: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	lines.append("Draw calls: %d" % draw_calls)
	var objects: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	lines.append("Nodes: %d" % objects)
	var scene_name: String = "?"
	var current := get_tree().current_scene
	if current:
		scene_name = current.name
	lines.append("Scene: %s" % scene_name)
	var cc: Node = _find_combat_controller()
	if cc:
		var player := _get_actor_from_cc(cc, "player")
		var enemy := _get_actor_from_cc(cc, "enemy")
		if player:
			lines.append("Player HP: %s / %s" % [str(_get_actor_hp(player)), str(_get_actor_max_hp(player))])
			lines.append("Player scale size: %s" % str(_get_actor_scale_size(player)))
		if enemy:
			lines.append("Enemy HP: %s / %s" % [str(_get_actor_hp(enemy)), str(_get_actor_max_hp(enemy))])
			lines.append("Enemy scale size: %s" % str(_get_actor_scale_size(enemy)))
		if "round" in cc:
			lines.append("Round: %s" % str(cc.get("round")))
		elif "round_count" in cc:
			lines.append("Round: %s" % str(cc.get("round_count")))
	return "\n".join(lines)


func _apply_cheats() -> void:
	if not _invincible and not _always_full_scale:
		return
	var cc: Node = _find_combat_controller()
	if cc == null:
		return
	if _invincible:
		var player := _get_actor_from_cc(cc, "player")
		if player:
			var hp: int = _get_actor_hp(player)
			var max_hp: int = _get_actor_max_hp(player)
			if _last_player_hp < 0:
				_last_player_hp = max_hp
			if hp < _last_player_hp:
				# Try to restore via direct field write.
				if "hp" in player:
					player.set("hp", _last_player_hp)
				elif "health" in player:
					player.set("health", _last_player_hp)
				elif "current_hp" in player:
					player.set("current_hp", _last_player_hp)
			else:
				_last_player_hp = hp
	if _always_full_scale:
		var player := _get_actor_from_cc(cc, "player")
		if player:
			_fill_actor_scale(player)


# ---- Combat lookup helpers -------------------------------------------------

func _find_combat_controller() -> Node:
	var group: Array = get_tree().get_nodes_in_group("combat_controllers")
	if group.size() > 0:
		return group[0]
	# Fallback: walk the tree.
	var root := get_tree().get_root()
	return _scan_for_combat_controller(root)


func _scan_for_combat_controller(n: Node) -> Node:
	if n == null:
		return null
	var s: Script = n.get_script()
	if s and s.resource_path.ends_with("combat_controller.gd"):
		return n
	for child in n.get_children():
		var found := _scan_for_combat_controller(child)
		if found:
			return found
	return null


func _find_board() -> Node:
	var root := get_tree().get_root()
	return _scan_for_script(root, "board.gd")


func _scan_for_script(n: Node, suffix: String) -> Node:
	if n == null:
		return null
	var s: Script = n.get_script()
	if s and s.resource_path.ends_with(suffix):
		return n
	for child in n.get_children():
		var found := _scan_for_script(child, suffix)
		if found:
			return found
	return null


func _get_actor_from_cc(cc: Node, side: String) -> Node:
	var keys: Array[String]
	if side == "player":
		keys = ["player", "player_actor", "_player"]
	else:
		keys = ["enemy", "enemy_actor", "_enemy"]
	for k in keys:
		if k in cc:
			var v: Variant = cc.get(k)
			if v is Node:
				return v
	return null


func _get_actor_hp(actor: Node) -> int:
	for k in ["hp", "health", "current_hp"]:
		if k in actor:
			return int(actor.get(k))
	return -1


func _get_actor_max_hp(actor: Node) -> int:
	for k in ["max_hp", "max_health"]:
		if k in actor:
			return int(actor.get(k))
	return -1


func _get_actor_scale_size(actor: Node) -> int:
	for k in ["action_scale_size", "scale_size", "action_scale_max"]:
		if k in actor:
			return int(actor.get(k))
	if "action_scale" in actor:
		var v: Variant = actor.get("action_scale")
		if v is Array:
			return (v as Array).size()
	return -1


func _fill_actor_scale(actor: Node) -> void:
	if "action_scale" in actor:
		var arr_v: Variant = actor.get("action_scale")
		if arr_v is Array:
			var arr: Array = arr_v
			var target: int = _get_actor_scale_size(actor)
			if target <= 0:
				target = 5
			while arr.size() < target:
				arr.append(0)
			actor.set("action_scale", arr)
			if actor.has_signal("emblem_added"):
				actor.emit_signal("emblem_added")


# ---- Button callbacks ------------------------------------------------------

func _on_close_pressed() -> void:
	if _overlay:
		_overlay.close_menu()


func _on_clear_overrides_pressed() -> void:
	if _overlay:
		_overlay.clear_overrides()


func _on_heal_player() -> void:
	var cc := _find_combat_controller()
	if cc == null:
		return
	var p := _get_actor_from_cc(cc, "player")
	if p == null:
		return
	var max_hp := _get_actor_max_hp(p)
	if max_hp > 0:
		for k in ["hp", "health", "current_hp"]:
			if k in p:
				p.set(k, max_hp)
				break


func _on_kill_enemy() -> void:
	var cc := _find_combat_controller()
	if cc == null:
		return
	var e := _get_actor_from_cc(cc, "enemy")
	if e == null:
		return
	for k in ["hp", "health", "current_hp"]:
		if k in e:
			e.set(k, 0)
			break
	if e.has_method("take_damage"):
		e.call("take_damage", 99999)
	elif cc.has_method("apply_damage_to_enemy"):
		cc.call("apply_damage_to_enemy", 99999)


func _on_stun_enemy() -> void:
	var cc := _find_combat_controller()
	if cc == null:
		return
	var e := _get_actor_from_cc(cc, "enemy")
	if e == null:
		return
	if e.has_method("apply_stun"):
		e.call("apply_stun", 99)
	elif "stun_rounds" in e:
		e.set("stun_rounds", 99)
	elif "stunned_for" in e:
		e.set("stunned_for", 99)


func _on_fill_scale() -> void:
	var cc := _find_combat_controller()
	if cc == null:
		return
	var e := _get_actor_from_cc(cc, "enemy")
	if e:
		_fill_actor_scale(e)


func _on_reshuffle() -> void:
	var board := _find_board()
	if board == null:
		return
	for m in ["reshuffle", "force_reshuffle", "shuffle"]:
		if board.has_method(m):
			board.call(m)
			return


func _on_spawn_rainbow() -> void:
	var board := _find_board()
	if board == null:
		return
	# Detect RAINBOW kind via PieceType.Kind.
	var PieceTypeScript: Script = load("res://scripts/resources/piece_type.gd")
	if PieceTypeScript == null:
		return
	var consts: Dictionary = PieceTypeScript.get_script_constant_map()
	var kind_enum: Variant = consts.get("Kind", null)
	var rainbow_kind: Variant = null
	if typeof(kind_enum) == TYPE_DICTIONARY:
		var kdict: Dictionary = kind_enum
		if kdict.has("RAINBOW"):
			rainbow_kind = kdict["RAINBOW"]
	if rainbow_kind == null:
		push_warning("Debug: RAINBOW kind not present on PieceType")
		return
	for m in ["spawn_special_at", "spawn_rainbow_at", "force_spawn_at"]:
		if board.has_method(m):
			board.call(m, 0, 0, rainbow_kind)
			return
	push_warning("Debug: board has no spawn_special_at-style API")


func _play_audio(method: String, args: Array = []) -> void:
	var audio_bus: Node = get_node_or_null("/root/AudioBus")
	if audio_bus and audio_bus.has_method(method):
		audio_bus.callv(method, args)


func _on_skip_level() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs and gs.has_method("skip_level"):
		gs.call("skip_level")
		return
	var router: Node = get_node_or_null("/root/SceneRouter")
	if router and router.has_method("go_to_victory"):
		router.call("go_to_victory")


func _on_reset_save() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null:
		return
	for m in ["reset", "reset_save", "reset_progress", "clear_save"]:
		if gs.has_method(m):
			gs.call(m)
			return


func _on_goto_victory() -> void:
	var router: Node = get_node_or_null("/root/SceneRouter")
	if router == null:
		return
	for m in ["go_to_victory", "to_victory", "goto_victory"]:
		if router.has_method(m):
			router.call(m)
			return
	if router.has_method("change_scene"):
		router.call("change_scene", "res://scenes/ui/victory.tscn")


func _on_goto_gameover() -> void:
	var router: Node = get_node_or_null("/root/SceneRouter")
	if router == null:
		return
	for m in ["go_to_game_over", "to_game_over", "goto_game_over"]:
		if router.has_method(m):
			router.call(m)
			return
	if router.has_method("change_scene"):
		router.call("change_scene", "res://scenes/ui/game_over.tscn")
