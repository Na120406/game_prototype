extends TileMapLayer
class_name FarmPlot

const CELL_SIZE: Vector2 = Vector2(16, 16)

var _farm_manager: Node = null
var _highlight_cell: Vector2i = Vector2i(-999, -999)
var _highlight_rect: ColorRect = null
var _current_hotbar_item: String = ""
var _current_hotbar_data: ItemData = null
var _is_hovering: bool = false

# Farm action zone (world coords where the plot is active)
const FARM_ZONE := Rect2(20, 270, 600, 310)

func _ready() -> void:
	add_to_group("farm_plot")
	_farm_manager = get_tree().get_first_node_in_group("farm_manager")

	var c := ColorRect.new()
	c.custom_minimum_size = CELL_SIZE
	c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.visible = false
	add_child(c)
	_highlight_rect = c

	var hotbar := get_tree().get_first_node_in_group("hotbar")
	if hotbar != null and hotbar.has_method("selected_item_changed"):
		hotbar.selected_item_changed.connect(_on_hotbar_selection_changed)
	_update_hotbar_from_hotbar()

func _on_hotbar_selection_changed(item_id: String, item_data: ItemData) -> void:
	_current_hotbar_item = item_id
	_current_hotbar_data = item_data

func _update_hotbar_from_hotbar() -> void:
	var hotbar := get_tree().get_first_node_in_group("hotbar")
	if hotbar != null and hotbar.has_method("get_selected_item_id"):
		_current_hotbar_item = hotbar.get_selected_item_id()
	if hotbar != null and hotbar.has_method("get_selected_item_data"):
		_current_hotbar_data = hotbar.get_selected_item_data()

func get_player_facing_cell(player_node: Node) -> Vector2i:
	var facing_dir: Vector2 = player_node.facing_dir if "facing_dir" in player_node else Vector2.DOWN
	return local_to_map(player_node.global_position + facing_dir * 16.0)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var mp := get_global_mouse_position()
			if _is_in_farm_zone(mp):
				var cell := local_to_map(mp)
				_update_hotbar_from_hotbar()
				_try_farm_action(cell)

	if event is InputEventMouseMotion:
		var mp := get_global_mouse_position()
		var cell := local_to_map(mp)
		var in_zone := _is_in_farm_zone(mp)

		if not _is_hovering and in_zone:
			_is_hovering = true
			_update_hotbar_from_hotbar()

		if in_zone and cell != _highlight_cell:
			_highlight_cell = cell
			_update_highlight(cell)
		elif not in_zone:
			_is_hovering = false
			_highlight_cell = Vector2i(-999, -999)
			if _highlight_rect:
				_highlight_rect.visible = false

func _is_in_farm_zone(world_pos: Vector2) -> bool:
	return FARM_ZONE.has_point(world_pos)

func _update_highlight(cell: Vector2i) -> void:
	if _highlight_rect == null:
		return
	var world_pos := map_to_local(cell)
	_highlight_rect.position = world_pos
	_highlight_rect.custom_minimum_size = CELL_SIZE

	var st: int = _get_cell_state(cell)
	_highlight_rect.color = _get_highlight_color(st)
	_highlight_rect.visible = true

func _get_cell_state(cell: Vector2i) -> int:
	if _farm_manager != null and _farm_manager.has_method("get_cell_state"):
		return _farm_manager.get_cell_state(cell)
	return 0

func _get_highlight_color(state: int) -> Color:
	match state:
		0: return Color(0.6, 0.5, 0.3, 0.4)  # empty — neutral
		1: return Color(0.5, 0.3, 0.15, 0.5) # plowed — brown
		2: return Color(0.3, 0.6, 0.2, 0.4)  # seeded
		3: return Color(0.4, 0.75, 0.3, 0.4) # sprouted
		4: return Color(0.5, 0.85, 0.35, 0.4)# growing
		5: return Color(1.0, 0.9, 0.2, 0.5)   # mature — golden
		6: return Color(0.6, 0.3, 0.1, 0.5)  # wilted
	return Color(0.6, 0.5, 0.3, 0.4)

func _get_item_type() -> String:
	if _current_hotbar_data == null:
		return "none"
	match _current_hotbar_data.item_type:
		ItemData.Type.TOOL: return "tool"
		ItemData.Type.SEED: return "seed"
		ItemData.Type.CONSUMABLE: return "consumable"
	return "other"

func _is_tool_id(expected: String) -> bool:
	var item_id := _current_hotbar_item
	var db := get_node_or_null("/root/ItemDB")
	if db != null:
		var data: ItemData = db.get_item(item_id)
		if data != null and data.item_type == ItemData.Type.TOOL:
			return item_id == expected
	return item_id == expected

func _try_farm_action(cell: Vector2i) -> void:
	if _farm_manager == null:
		return

	var cell_state: int = _get_cell_state(cell)
	var item_type := _get_item_type()
	var item_id := _current_hotbar_item

	match cell_state:
		0: # EMPTY
			if _is_tool_id("hoe"):
				if _farm_manager.plow_cell(cell):
					_play_feedback(cell, "Plowed!", Color(0.6, 0.4, 0.2))
			elif item_type == "seed":
				_try_plant_seed(cell)
		1: # PLOWED
			if _is_tool_id("hoe"):
				_play_feedback(cell, "Already plowed!", Color(0.8, 0.6, 0.3))
			elif item_type == "seed":
				_try_plant_seed(cell)
		2, 3, 4: # SEEDED / SPROUTED / GROWING
			if _is_tool_id("water_can"):
				if _farm_manager.water_cell(cell):
					_play_feedback(cell, "Watered!", Color(0.3, 0.6, 0.9))
			elif item_type == "seed":
				_play_feedback(cell, "Already planted!", Color(0.8, 0.6, 0.3))
			else:
				_show_growth_info(cell)
		5: # MATURE
			_try_harvest(cell)
		6: # WILTED
			if _is_tool_id("hoe"):
				_farm_manager.plow_cell(cell)
				_play_feedback(cell, "Cleared!", Color(0.5, 0.3, 0.2))
			else:
				_play_feedback(cell, "Withered!", Color(0.5, 0.2, 0.1))

func _try_plant_seed(cell: Vector2i) -> void:
	if _farm_manager == null or _current_hotbar_data == null:
		return
	if _current_hotbar_data.item_type != ItemData.Type.SEED:
		return
	if not _current_hotbar_item.begins_with("seed_"):
		return

	if _farm_manager.plant_from_seed(cell, _current_hotbar_item):
		GameState.remove_item(_current_hotbar_item, 1)
		_play_feedback(cell, "Planted!", Color(0.4, 0.8, 0.3))
		GameState.inventory_changed.emit()

func _try_harvest(cell: Vector2i) -> void:
	if _farm_manager == null:
		return
	var harvest_id: String = _farm_manager.harvest_crop(cell)
	if harvest_id != "":
		var db := get_node_or_null("/root/ItemDB")
		var color := Color(1.0, 0.9, 0.3)
		if db != null:
			var data: ItemData = db.get_item(harvest_id)
			if data != null:
				color = data.item_color
		_play_feedback(cell, "+1 " + harvest_id, color)

func _show_growth_info(cell: Vector2i) -> void:
	if _farm_manager == null:
		return
	var data: Dictionary = _farm_manager.get_cell_data(cell)
	if data.is_empty():
		return
	var progress: float = data.get("growth_progress", 0.0) * 100.0
	var watered: bool = data.get("watered", false)
	var w_text := " (watered)" if watered else ""
	_play_feedback(cell, "Growing: %.0f%%%s" % [progress, w_text], Color(0.5, 0.8, 0.4))

func _play_feedback(cell: Vector2i, text: String, color: Color) -> void:
	var world_pos := map_to_local(cell)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 7)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = world_pos + Vector2(-16, -10)
	label.z_index = 200
	add_child(label)

	var tw := create_tween()
	tw.tween_property(label, "position:y", world_pos.y - 16, 0.8)
	tw.tween_callback(label.queue_free)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
