extends CanvasLayer

var _sleep_prompt: Node

func _ready() -> void:
	_create_day_info()
	_create_map_label()
	_connect_bed()

func _create_day_info() -> void:
	var panel := PanelContainer.new()
	panel.name = "DayInfo"
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.anchor_left = 1.0
	panel.anchor_top = 0.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 0.0
	panel.offset_left = -66.0
	panel.offset_top = 4.0
	panel.offset_right = -4.0
	panel.offset_bottom = 22.0
	panel.grow_horizontal = Control.GROW_DIRECTION_END
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.05, 0.1, 0.85)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.5, 0.4, 0.3, 0.8)
	style.set_corner_radius_all(3)
	panel.add_theme_stylebox_override("panel", style)

	var lbl := Label.new()
	lbl.name = "DayLabel"
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.5, 1))
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.text = "Day %d" % GameState.current_day

	panel.add_child(lbl)
	add_child(panel)

func _create_map_label() -> void:
	var lbl := Label.new()
	lbl.name = "MapLabel"
	lbl.set_anchors_preset(Control.PRESET_TOP_LEFT)
	lbl.anchor_left = 0.0
	lbl.anchor_top = 0.0
	lbl.anchor_right = 0.0
	lbl.anchor_bottom = 0.0
	lbl.offset_left = 4.0
	lbl.offset_top = 2.0
	lbl.offset_right = 70.0
	lbl.offset_bottom = 12.0
	lbl.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	lbl.grow_vertical = Control.GROW_DIRECTION_BEGIN
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	lbl.add_theme_font_size_override("font_size", 6)
	lbl.text = "INSIDE HOUSE"
	add_child(lbl)

func _connect_bed() -> void:
	var bed := _find_node(get_tree().current_scene, "Bed")
	if bed != null:
		bed.sleep_requested.connect(_on_bed_sleep_requested)

	var sp := _get_sleep_prompt()
	if sp != null:
		sp.sleep_chosen.connect(_on_sleep_chosen)

func _find_node(root: Node, name: String) -> Node:
	if root == null:
		return null
	if root.name == name:
		return root
	for child in root.get_children():
		var found := _find_node(child, name)
		if found != null:
			return found
	return null

func _get_sleep_prompt() -> Node:
	return find_child("SleepPrompt", true, false)

func _process(_delta: float) -> void:
	var lbl: Label = find_child("DayLabel", true, false)
	if lbl != null:
		var new_text := "Day %d" % GameState.current_day
		if lbl.text != new_text:
			lbl.text = new_text

func _on_bed_sleep_requested() -> void:
	var sp := _get_sleep_prompt()
	if sp != null and sp.has_method("show_prompt"):
		sp.show_prompt()

func _on_sleep_chosen() -> void:
	var player := _find_node(get_tree().current_scene, "Player")
	if player != null and player.has_method("set_sleeping"):
		player.set_sleeping(true)
	TimeManager.pause()
	await get_tree().create_timer(0.8).timeout
	GameState.advance_day()
	TimeManager.set_time(6.0)
	TimeManager.resume()
	if player != null and player.has_method("set_sleeping"):
		player.set_sleeping(false)
