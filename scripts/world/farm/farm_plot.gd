extends TileMapLayer
class_name FarmPlot

const CELL_SIZE: Vector2 = Vector2(16, 16)

var _farm_manager: Node = null
var _highlight_cell: Vector2i = Vector2i(-999, -999)
var _highlight_rect: ColorRect = null
var _current_hotbar_item: String = ""
var _current_hotbar_data: ItemData = null
var _is_hovering: bool = false
var _soil_visuals: Dictionary = {}  # cell_key -> ColorRect

# Farm action zone (world coords where the plot is active)
# Adjusted to match fence boundaries: left=20, right=616, top=270, bottom=576
const FARM_ZONE := Rect2(24, 274, 592, 302)

func _ready() -> void:
	add_to_group("farm_plot")
	_farm_manager = get_tree().get_first_node_in_group("farm_manager")
	print("[FarmPlot] _ready: farm_manager found = ", _farm_manager != null)
	if _farm_manager == null:
		print("[FarmPlot] WARNING: FarmManager not found! Retrying in 0.5s...")
		await get_tree().create_timer(0.5).timeout
		_farm_manager = get_tree().get_first_node_in_group("farm_manager")
		print("[FarmPlot] Retry: farm_manager found = ", _farm_manager != null)

	# Connect to farm_manager signals to update soil visuals
	if _farm_manager != null:
		if _farm_manager.has_signal("crop_planted"):
			_farm_manager.crop_planted.connect(_on_crop_state_changed)
		if _farm_manager.has_signal("crop_growed"):
			_farm_manager.crop_growed.connect(_on_crop_growed_signal)
		if _farm_manager.has_signal("crop_harvested"):
			_farm_manager.crop_harvested.connect(_on_crop_harvested_signal)
		if _farm_manager.has_signal("watered_changed"):
			_farm_manager.watered_changed.connect(_on_watered_changed)
		_refresh_soil_visuals()

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
	# Refresh visuals whenever a new day begins (e.g. after sleep)
	GameState.day_changed.connect(_on_day_changed)
	_update_hotbar_from_hotbar()

func _on_crop_state_changed(_cell: Vector2i) -> void:
	_refresh_soil_visuals()

func _on_crop_growed_signal(_stage: int) -> void:
	_refresh_soil_visuals()

func _on_crop_harvested_signal(_cell: Vector2i, _item_id: String) -> void:
	_refresh_soil_visuals()

func _on_watered_changed(cell: Vector2i) -> void:
	if _farm_manager == null:
		return
	var data: Dictionary = _farm_manager.get_cell_data(cell)
	_update_soil_visual_color(_cell_key(cell), data)

func _on_day_changed(_new_day: int) -> void:
	# Force a full soil visual rebuild so watered=false reflects after sleep
	_refresh_soil_visuals()

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
	var world_pos: Vector2 = player_node.global_position + facing_dir * 16.0
	return _world_to_cell(world_pos)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var mp := get_global_mouse_position()
			print("[DEBUG] Right-click at world: ", mp)
			print("[DEBUG] Farm zone: ", FARM_ZONE)
			print("[DEBUG] In farm zone: ", _is_in_farm_zone(mp))
			if _is_in_farm_zone(mp):
				var cell := _world_to_cell(mp)
				print("[DEBUG] Cell coords: ", cell)
				if not _is_cell_in_reach(cell):
					_play_feedback(cell, "Too far!", Color(0.8, 0.3, 0.3))
					print("[DEBUG] Cell out of reach: ", cell)
					return
				_update_hotbar_from_hotbar()
				print("[DEBUG] Current item: '", _current_hotbar_item, "' type: ", _get_item_type())
				_try_farm_action(cell)

	if event is InputEventMouseMotion:
		var mp := get_global_mouse_position()
		var cell := _world_to_cell(mp)
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

# Convert world position to farm cell coords.
# The farm zone origin is at FARM_ZONE.position (24, 274) and each cell is 16x16.
func _world_to_cell(world_pos: Vector2) -> Vector2i:
	var local := world_pos - FARM_ZONE.position
	return Vector2i(int(floor(local.x / CELL_SIZE.x)), int(floor(local.y / CELL_SIZE.y)))

# Convert farm cell coords to world position (top-left corner of cell).
func _cell_to_world(cell: Vector2i) -> Vector2:
	return FARM_ZONE.position + Vector2(cell) * CELL_SIZE

func _is_in_farm_zone(world_pos: Vector2) -> bool:
	return FARM_ZONE.has_point(world_pos)

## Returns true if `cell` is within the player's reach (default 3x3 around player).
func _is_cell_in_reach(cell: Vector2i) -> bool:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		# If no player in scene (e.g. shop scene), allow all farm actions.
		return true
	var ppos: Vector2 = (player as Node2D).global_position
	var pcell: Vector2i = Vector2i(
		int((ppos.x - FARM_ZONE.position.x) / CELL_SIZE.x),
		int((ppos.y - FARM_ZONE.position.y) / CELL_SIZE.y)
	)
	var dx: int = abs(cell.x - pcell.x)
	var dy: int = abs(cell.y - pcell.y)
	return dx <= 1 and dy <= 1

func _update_highlight(cell: Vector2i) -> void:
	if _highlight_rect == null:
		return
	var world_pos := _cell_to_world(cell)
	_highlight_rect.position = world_pos
	_highlight_rect.custom_minimum_size = CELL_SIZE

	var st: int = _get_cell_state(cell)
	var in_reach: bool = _is_cell_in_reach(cell)
	# Greyed-out for cells out of reach.
	var col: Color = _get_highlight_color(st)
	if not in_reach:
		col = Color(col.r * 0.5, col.g * 0.5, col.b * 0.5, 0.2)
	_highlight_rect.color = col
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
	# Direct string comparison first (most common case)
	if item_id == expected:
		return true
	# Fallback: check ItemDB for type verification
	var db := get_node_or_null("/root/ItemDB")
	if db != null:
		var data: ItemData = db.get_item(item_id)
		if data != null and data.item_type == ItemData.Type.TOOL:
			return item_id == expected
	return false

func _try_farm_action(cell: Vector2i) -> void:
	if _farm_manager == null:
		print("[DEBUG] _try_farm_action: farm_manager is null!")
		return

	var cell_state: int = _get_cell_state(cell)
	var item_type := _get_item_type()
	var item_id := _current_hotbar_item

	print("[DEBUG] _try_farm_action: cell=", cell, " state=", cell_state, " item='", item_id, "' type=", item_type)

	match cell_state:
		0: # EMPTY — must plow first
			if _is_tool_id("hoe"):
				if _farm_manager.plow_cell(cell):
					var data: Dictionary = _farm_manager.get_cell_data(cell)
					_show_soil_visual(cell, data)
					_play_feedback(cell, "Plowed!", Color(0.6, 0.4, 0.2))
			elif _is_tool_id("water_can"):
				_play_feedback(cell, "Plow first!", Color(0.8, 0.3, 0.3))
			elif item_type == "seed":
				_play_feedback(cell, "Plow first!", Color(0.8, 0.3, 0.3))
		1: # PLOWED — can water or plant
			if _is_tool_id("hoe"):
				_play_feedback(cell, "Already plowed!", Color(0.8, 0.6, 0.3))
			elif _is_tool_id("water_can"):
				if _farm_manager.water_cell(cell):
					var data: Dictionary = _farm_manager.get_cell_data(cell)
					_update_soil_visual_color(_cell_key(cell), data)
					_play_feedback(cell, "Watered!", Color(0.3, 0.6, 0.9))
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
				if _farm_manager.clear_wilted_cell(cell):
					var data: Dictionary = _farm_manager.get_cell_data(cell)
					_show_soil_visual(cell, data)
					_play_feedback(cell, "Cleared!", Color(0.5, 0.3, 0.2))
				else:
					_play_feedback(cell, "Can't clear!", Color(0.8, 0.4, 0.3))
			else:
				_play_feedback(cell, "Withered!", Color(0.5, 0.2, 0.1))

func _try_plant_seed(cell: Vector2i) -> void:
	if _farm_manager == null or _current_hotbar_data == null:
		return
	if _current_hotbar_data.item_type != ItemData.Type.SEED:
		return
	if not _current_hotbar_item.begins_with("seed_"):
		return

	var data: Dictionary = _farm_manager.get_cell_data(cell)
	if data.is_empty() or data.get("state", -1) != 1: # not PLOWED
		_play_feedback(cell, "Plow first!", Color(0.8, 0.3, 0.3))
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
	var streak: int = data.get("unwatered_streak", 0)
	var need: int = data.get("water_need", 1)
	var w_text := " (watered)" if watered else " (%d/%d days without water)" % [streak, need]
	_play_feedback(cell, "Growing: %.0f%%%s" % [progress, w_text], Color(0.5, 0.8, 0.4))

func _play_feedback(cell: Vector2i, text: String, color: Color) -> void:
	var world_pos := _cell_to_world(cell)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 7)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.z_index = 200
	label.modulate = color
	# Anchor centered horizontally on the cell; start slightly above cell top.
	label.position = world_pos + Vector2(-CELL_SIZE.x * 0.5, -CELL_SIZE.y - 4)
	add_child(label)

	# Fade-in (fast) → drift up + fade-out (slow).
	var tw := create_tween()
	tw.set_parallel(false)
	# Pop in quickly with a slight scale-up bounce.
	# Initial scale = 0.6 (set before add_child); grow to 1.0 over 0.15s.
	tw.tween_property(label, "scale", Vector2(1.0, 1.0), 0.15)\
		.from(Vector2(0.6, 0.6))\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
	# Hold & drift upward smoothly.
	tw.tween_property(label, "position:y",
		world_pos.y - CELL_SIZE.y - 22, 1.2)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 1.2)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN)
	tw.tween_callback(label.queue_free)

func _show_soil_visual(cell: Vector2i, data: Dictionary = {}) -> void:
	var cell_key := _cell_key(cell)
	if _soil_visuals.has(cell_key):
		_update_soil_visual_color(cell_key, data)
		return

	var world_pos := _cell_to_world(cell)
	var rect := ColorRect.new()
	rect.name = "Soil_" + cell_key
	rect.color = _get_soil_color(data)
	rect.position = world_pos
	rect.size = CELL_SIZE
	rect.z_index = 1
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	_soil_visuals[cell_key] = rect

func _get_soil_color(data: Dictionary) -> Color:
	if data.get("watered", false):
		return Color(0.35, 0.22, 0.08, 0.85)
	return Color(0.55, 0.42, 0.25, 0.65)

func _update_soil_visual_color(cell_key: String, data: Dictionary) -> void:
	if not _soil_visuals.has(cell_key):
		return
	var rect: ColorRect = _soil_visuals[cell_key]
	if not is_instance_valid(rect):
		return
	rect.color = _get_soil_color(data)

func _hide_soil_visual(cell: Vector2i) -> void:
	var cell_key := _cell_key(cell)
	if not _soil_visuals.has(cell_key):
		return
	var rect: ColorRect = _soil_visuals[cell_key]
	if is_instance_valid(rect):
		rect.queue_free()
	_soil_visuals.erase(cell_key)

func _clear_all_soil_visuals() -> void:
	for cell_key in _soil_visuals.keys():
		var rect: ColorRect = _soil_visuals[cell_key]
		if is_instance_valid(rect):
			rect.queue_free()
	_soil_visuals.clear()

func _refresh_soil_visuals() -> void:
	if _farm_manager == null:
		return
	_clear_all_soil_visuals()
	var data: Dictionary = _farm_manager.serialize()
	if not data.has("cells"):
		return
	for entry: Dictionary in data["cells"]:
		var cell := Vector2i(int(entry["x"]), int(entry["y"]))
		var cell_data: Dictionary = entry["data"]
		var state: int = cell_data.get("state", 0)
		# Show soil visual for PLOWED, SEEDED, SPROUTED, GROWING, MATURE, WILTED
		if state >= 1:
			_show_soil_visual(cell, cell_data)

func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]
