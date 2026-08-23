extends TileMapLayer
class_name FarmPlot
# =============================================================================
# FARM PLOT - TileMapLayer quản lý farm grid và tương tác
# =============================================================================
# v3: Sử dụng FarmEnums cho tất cả crop state và type.
# Soil visuals dùng Sprite2D + AtlasTexture từ FieldsTileset.
# =============================================================================

const CELL_SIZE: Vector2 = Vector2(16, 16)
const GROUND_TEX_PATH := "res://Tile Maps/1 Tiles/FieldsTileset.png"

const FARM_ZONE := Rect2(24, 274, 592, 302)

var _farm_manager: Node = null
var _highlight_cell: Vector2i = Vector2i(-999, -999)
var _highlight_rect: ColorRect = null
var _current_hotbar_item: String = ""
var _current_hotbar_data: ItemData = null
var _is_hovering: bool = false
var _soil_visuals: Dictionary = {}
var _ground_atlas: Texture2D = null

# Atlas regions from FieldsTileset.png (16x16 grid)
const _SOIL_REGION_DRY    := [0, 2]
const _SOIL_REGION_PLOWED := [1, 2]
const _SOIL_REGION_WATER  := [2, 2]

# Sử dụng FarmEnums (load trực tiếp để tránh phụ thuộc autoload)
const FarmEnumsRef = preload("res://scripts/autoload/farm_enums.gd")
const CropState = FarmEnumsRef.CropState
const CropType = FarmEnumsRef.CropType

func _ready() -> void:
	add_to_group("farm_plot")
	_farm_manager = get_tree().get_first_node_in_group("farm_manager")
	if _farm_manager == null:
		await get_tree().create_timer(0.5).timeout
		_farm_manager = get_tree().get_first_node_in_group("farm_manager")
		if _farm_manager == null:
			push_error("[FarmPlot] FarmManager not found after retry!")

	_ground_atlas = load(GROUND_TEX_PATH) as Texture2D
	if _ground_atlas == null:
		push_error("[FarmPlot] Cannot load ground atlas: %s" % GROUND_TEX_PATH)

	if _farm_manager != null:
		if _farm_manager.has_signal("crop_planted"):
			_farm_manager.crop_planted.connect(_on_crop_state_changed)
		if _farm_manager.has_signal("crop_growed"):
			_farm_manager.crop_growed.connect(_on_crop_growed_signal)
		if _farm_manager.has_signal("crop_harvested"):
			_farm_manager.crop_harvested.connect(_on_crop_harvested_signal)
		if _farm_manager.has_signal("watered_changed"):
			_farm_manager.watered_changed.connect(_on_watered_changed)
		if _farm_manager.has_signal("cell_removed"):
			_farm_manager.cell_removed.connect(_on_cell_removed)
		refresh_soil_visuals()

	var c := ColorRect.new()
	c.custom_minimum_size = CELL_SIZE
	c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.z_index = 3
	c.visible = false
	add_child(c)
	_highlight_rect = c

	var hotbar := get_tree().get_first_node_in_group("hotbar")
	if hotbar != null and hotbar.has_method("selected_item_changed"):
		hotbar.selected_item_changed.connect(_on_hotbar_selection_changed)
	if GameState.day_changed.is_connected(_on_day_changed):
		GameState.day_changed.disconnect(_on_day_changed)
	GameState.day_changed.connect(_on_day_changed)
	_update_hotbar_from_hotbar()

# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

func _on_crop_state_changed(_cell: Vector2i) -> void:
	refresh_soil_visuals()

func _on_crop_growed_signal(_stage: int) -> void:
	refresh_soil_visuals()

func _on_crop_harvested_signal(_cell: Vector2i, _item_id: String) -> void:
	refresh_soil_visuals()

func _on_watered_changed(cell: Vector2i) -> void:
	if _farm_manager == null:
		return
	var data: Dictionary = _farm_manager.get_cell_data(cell)
	_update_soil_visual_texture(_cell_key(cell), data)

func _on_day_changed(_new_day: int) -> void:
	refresh_soil_visuals()

func _on_cell_removed(cell: Vector2i) -> void:
	# PLOWED cell hết hạn → ô đất phải biến mất hoàn toàn. Xóa ColorRect nâu.
	_hide_soil_visual(cell)

func _on_hotbar_selection_changed(item_id: String, item_data: ItemData) -> void:
	_current_hotbar_item = item_id
	_current_hotbar_data = item_data

func _update_hotbar_from_hotbar() -> void:
	var hotbar := get_tree().get_first_node_in_group("hotbar")
	if hotbar == null:
		return
	if hotbar.has_method("get_selected_item_id"):
		_current_hotbar_item = hotbar.get_selected_item_id()
	if hotbar.has_method("get_selected_item_data"):
		_current_hotbar_data = hotbar.get_selected_item_data()

# =============================================================================
# INPUT & INTERACTION
# =============================================================================

func get_player_facing_cell(player_node: Node) -> Vector2i:
	var facing_dir: Vector2 = player_node.facing_dir if "facing_dir" in player_node else Vector2.DOWN
	var world_pos: Vector2 = player_node.global_position + facing_dir * 16.0
	return _world_to_cell(world_pos)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var mp := get_global_mouse_position()
			if _is_in_farm_zone(mp):
				var cell := _world_to_cell(mp)
				if not _is_cell_in_reach(cell):
					_play_feedback(cell, "Too far!", Color(0.8, 0.3, 0.3))
					return
				_update_hotbar_from_hotbar()
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

# =============================================================================
# COORDINATE UTILITIES
# =============================================================================

func _world_to_cell(world_pos: Vector2) -> Vector2i:
	var local := world_pos - FARM_ZONE.position
	return Vector2i(int(floor(local.x / CELL_SIZE.x)), int(floor(local.y / CELL_SIZE.y)))

func _cell_to_world(cell: Vector2i) -> Vector2:
	return FARM_ZONE.position + Vector2(cell) * CELL_SIZE

func _is_in_farm_zone(world_pos: Vector2) -> bool:
	return FARM_ZONE.has_point(world_pos)

func _is_cell_in_reach(cell: Vector2i) -> bool:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return true
	var ppos: Vector2 = (player as Node2D).global_position
	var pcell: Vector2i = Vector2i(
		int((ppos.x - FARM_ZONE.position.x) / CELL_SIZE.x),
		int((ppos.y - FARM_ZONE.position.y) / CELL_SIZE.y)
	)
	var dx: int = abs(cell.x - pcell.x)
	var dy: int = abs(cell.y - pcell.y)
	return dx <= 1 and dy <= 1

# =============================================================================
# HIGHLIGHT
# =============================================================================

func _update_highlight(cell: Vector2i) -> void:
	if _highlight_rect == null:
		return
	var world_pos := _cell_to_world(cell)
	_highlight_rect.position = world_pos
	_highlight_rect.custom_minimum_size = CELL_SIZE
	var state: CropState = _get_cell_state(cell)
	var in_reach: bool = _is_cell_in_reach(cell)
	var col: Color = _get_highlight_color(state)
	if not in_reach:
		col = Color(col.r * 0.5, col.g * 0.5, col.b * 0.5, 0.2)
	_highlight_rect.color = col
	_highlight_rect.visible = true

func _get_cell_state(cell: Vector2i) -> CropState:
	if _farm_manager != null and _farm_manager.has_method("get_cell_state"):
		return _farm_manager.get_cell_state(cell)
	return CropState.EMPTY

func _get_highlight_color(state: CropState) -> Color:
	match state:
		CropState.EMPTY: return Color(0.6, 0.5, 0.3, 0.4)
		CropState.PLOWED: return Color(0.5, 0.3, 0.15, 0.5)
		CropState.SEEDED: return Color(0.3, 0.6, 0.2, 0.4)
		CropState.SPROUTED: return Color(0.4, 0.75, 0.3, 0.4)
		CropState.GROWING: return Color(0.5, 0.85, 0.35, 0.4)
		CropState.MATURE: return Color(1.0, 0.9, 0.2, 0.5)
		CropState.WILTED: return Color(0.6, 0.3, 0.1, 0.5)
	return Color(0.6, 0.5, 0.3, 0.4)

# =============================================================================
# ITEM TYPE DETECTION
# =============================================================================

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
	if item_id == expected:
		return true
	var db := get_node_or_null("/root/ItemDB")
	if db != null:
		var data: ItemData = db.get_item(item_id)
		if data != null and data.item_type == ItemData.Type.TOOL:
			return item_id == expected
	return false

# =============================================================================
# FARMING ACTIONS
# =============================================================================

func _try_farm_action(cell: Vector2i) -> void:
	if _farm_manager == null:
		_play_feedback(cell, "No FarmManager!", Color(0.8, 0.3, 0.3))
		return

	var state: CropState = _get_cell_state(cell)
	var item_type := _get_item_type()

	# Chỉ tiêu hao năng lượng khi dùng hoe hoặc water_can
	var is_hoe_or_water: bool = _is_tool_id("hoe") or _is_tool_id("water_can")

	if is_hoe_or_water:
		if not _consume_action_energy(cell):
			return

	match state:
		CropState.EMPTY:
			if _is_tool_id("hoe"):
				if _farm_manager.plow_cell(cell):
					var data: Dictionary = _farm_manager.get_cell_data(cell)
					_show_soil_visual(cell, data)
					_play_feedback(cell, "Plowed!", Color(0.6, 0.4, 0.2))
			elif _is_tool_id("water_can"):
				_play_feedback(cell, "Plow first!", Color(0.8, 0.3, 0.3))
			elif item_type == "seed":
				_play_feedback(cell, "Plow first!", Color(0.8, 0.3, 0.3))

		CropState.PLOWED:
			if _is_tool_id("hoe"):
				_play_feedback(cell, "Already plowed!", Color(0.8, 0.6, 0.3))
			elif _is_tool_id("water_can"):
				if _farm_manager.water_cell(cell):
					var data: Dictionary = _farm_manager.get_cell_data(cell)
					_update_soil_visual_texture(_cell_key(cell), data)
					_play_feedback(cell, "Watered!", Color(0.3, 0.6, 0.9))
			elif item_type == "seed":
				_try_plant_seed(cell)

		CropState.SEEDED, CropState.SPROUTED, CropState.GROWING:
			if _is_tool_id("water_can"):
				if _farm_manager.water_cell(cell):
					_play_feedback(cell, "Watered!", Color(0.3, 0.6, 0.9))
			elif item_type == "seed":
				_play_feedback(cell, "Already planted!", Color(0.8, 0.6, 0.3))
			else:
				_show_growth_info(cell)

		CropState.MATURE:
			_try_harvest(cell)

		CropState.WILTED:
			if _is_tool_id("hoe"):
				if _farm_manager.clear_wilted_cell(cell):
					var data: Dictionary = _farm_manager.get_cell_data(cell)
					_show_soil_visual(cell, data)
					_play_feedback(cell, "Cleared!", Color(0.5, 0.3, 0.2))
				else:
					_play_feedback(cell, "Can't clear!", Color(0.8, 0.4, 0.3))
			else:
				_play_feedback(cell, "Withered!", Color(0.5, 0.2, 0.1))

func _consume_action_energy(_cell: Vector2i) -> bool:
	var em := get_node_or_null("/root/EnergyManager")
	if em == null:
		return true
	return em.spend_energy(1)

# =============================================================================
# SEED PLANTING
# =============================================================================

func _try_plant_seed(cell: Vector2i) -> void:
	if _farm_manager == null or _current_hotbar_data == null:
		return
	if _current_hotbar_data.item_type != ItemData.Type.SEED:
		return
	if not _current_hotbar_item.begins_with("seed_"):
		return
	var data: Dictionary = _farm_manager.get_cell_data(cell)
	if data.is_empty() or data.get("state", -1) != CropState.PLOWED:
		_play_feedback(cell, "Plow first!", Color(0.8, 0.3, 0.3))
		return
	if _farm_manager.plant_from_seed(cell, _current_hotbar_item):
		# Trừ seed từ nguồn đang chọn (toolbar hoặc inventory).
		# Nếu toolbar slot active đang giữ đúng item_id này → trừ từ toolbar.
		var from_toolbar := _consume_seed_from_active_toolbar(_current_hotbar_item)
		if not from_toolbar:
			GameState.remove_item(_current_hotbar_item, 1)
			GameState.inventory_changed.emit()
		_play_feedback(cell, "Planted!", Color(0.4, 0.8, 0.3))

func _consume_seed_from_active_toolbar(item_id: String) -> bool:
	var hotbar: Node = get_tree().get_first_node_in_group("hotbar")
	if hotbar == null:
		return false
	var active_slot: int = 0
	if hotbar.has_method("get_active_slot"):
		active_slot = hotbar.get_active_slot()
	if active_slot < 0 or active_slot >= GameState.toolbar.size():
		return false
	var slot: Dictionary = GameState.toolbar[active_slot]
	if slot.get("id", "") != item_id:
		return false
	return GameState.consume_toolbar_slot(active_slot, 1)

# =============================================================================
# HARVESTING
# =============================================================================

func _try_harvest(cell: Vector2i) -> void:
	if _farm_manager == null:
		return
	var harvest_id: String = _farm_manager.harvest_crop(cell)
	if harvest_id != "":
		var db := get_node_or_null("/root/ItemDB")
		var color := Color(1.0, 0.9, 0.3)
		var name_str: String = harvest_id
		if db != null:
			var item_data: ItemData = db.get_item(harvest_id)
			if item_data != null:
				color = item_data.item_color
				name_str = item_data.get_display_name()
		_play_feedback(cell, "+2 " + name_str, color)

# =============================================================================
# GROWTH INFO
# =============================================================================

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
	var info_color: Color = Color(0.5, 0.8, 0.4)
	var w_text := " (watered today)" if watered else " (%d/%d days without water)" % [streak, need]
	if not watered and streak >= need - 1:
		w_text = " (%d/%d days without water — will wilt tomorrow!)" % [streak, need]
		info_color = Color(0.85, 0.35, 0.25)
	_play_feedback(cell, "Growing: %.0f%%%s" % [progress, w_text], info_color)

# =============================================================================
# FEEDBACK ANIMATION
# =============================================================================

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
	label.position = world_pos + Vector2(-CELL_SIZE.x * 0.5, -CELL_SIZE.y - 4)
	add_child(label)
	var tw := create_tween()
	tw.set_parallel(false)
	tw.tween_property(label, "scale", Vector2(1.0, 1.0), 0.15)\
		.from(Vector2(0.6, 0.6))\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "position:y",
		world_pos.y - CELL_SIZE.y - 22, 1.2)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 1.2)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN)
	tw.tween_callback(label.queue_free)

# =============================================================================
# SOIL VISUALS (Sprite2D + AtlasTexture)
# =============================================================================

func _show_soil_visual(cell: Vector2i, data: Dictionary = {}) -> void:
	var cell_key := _cell_key(cell)

	# PLOWED (đất đào, chưa trồng cây) → vẽ ColorRect nâu ĐƠN SẮC (không dùng
	# atlas). Atlas FieldsTileset chứa sẵn 3 chấm xanh trong mọi tile đất —
	# nếu vẽ sẽ trông như đã gieo hạt. ColorRect nâu sạch báo "đã đào".
	if data.get("state", CropState.PLOWED) == CropState.PLOWED:
		if _soil_visuals.has(cell_key):
			var existing = _soil_visuals[cell_key]
			if is_instance_valid(existing):
				existing.queue_free()
			_soil_visuals.erase(cell_key)
		var rect := ColorRect.new()
		rect.name = "Soil_" + cell_key
		rect.color = Color(0.55, 0.42, 0.25, 1.0)
		rect.position = _cell_to_world(cell)
		rect.size = CELL_SIZE
		rect.z_index = 2
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(rect)
		_soil_visuals[cell_key] = rect
		return

	if _soil_visuals.has(cell_key):
		_update_soil_visual_texture(cell_key, data)
		return

	if _ground_atlas == null:
		_show_soil_color_fallback(cell, data)
		return

	var world_pos := _cell_to_world(cell)
	var sprite := Sprite2D.new()
	sprite.name = "Soil_" + cell_key
	sprite.centered = false
	sprite.position = world_pos
	sprite.z_index = 2
	sprite.texture = _make_soil_texture(data)
	add_child(sprite)
	_soil_visuals[cell_key] = sprite

func _update_soil_visual_texture(cell_key: String, data: Dictionary) -> void:
	var state: CropState = data.get("state", CropState.PLOWED)
	# PLOWED: phải là ColorRect nâu đơn sắc (không có chấm xanh). Nếu sprite
	# hiện tại là Sprite2D (do trước đó là cây thật) → xóa và vẽ lại ColorRect.
	if state == CropState.PLOWED:
		if _soil_visuals.has(cell_key):
			var n = _soil_visuals[cell_key]
			if is_instance_valid(n):
				n.queue_free()
			_soil_visuals.erase(cell_key)
		# Tạo ColorRect nâu trực tiếp từ cell_key (parse lại Vector2i).
		var parts: PackedStringArray = cell_key.split(",")
		if parts.size() == 2:
			var cell := Vector2i(int(parts[0]), int(parts[1]))
			var rect := ColorRect.new()
			rect.name = "Soil_" + cell_key
			rect.color = Color(0.55, 0.42, 0.25, 1.0)
			rect.position = _cell_to_world(cell)
			rect.size = CELL_SIZE
			rect.z_index = 2
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(rect)
			_soil_visuals[cell_key] = rect
		return
	if not _soil_visuals.has(cell_key):
		return
	var n = _soil_visuals[cell_key]
	if not is_instance_valid(n):
		return
	if n is Sprite2D and _ground_atlas != null:
		(n as Sprite2D).texture = _make_soil_texture(data)
	elif n is ColorRect:
		(n as ColorRect).color = _get_soil_color_fallback(data)

func _make_soil_texture(data: Dictionary) -> AtlasTexture:
	# PLOWED không bao giờ được gọi đến đây — _show_soil_visual /
	# _show_soil_color_fallback / _update_soil_visual_texture đều skip PLOWED
	# để tránh hiển thị chấm xanh từ atlas. Đoạn dưới chỉ xử lý cây thật.
	var region: Array
	var state: CropState = data.get("state", CropState.PLOWED)
	if data.get("watered", false):
		region = _SOIL_REGION_WATER
	else:
		if state >= CropState.PLOWED:
			region = _SOIL_REGION_PLOWED
		else:
			region = _SOIL_REGION_DRY
	var at := AtlasTexture.new()
	at.atlas = _ground_atlas
	at.region = Rect2(region[0] * 16, region[1] * 16, 16, 16)
	return at

func _show_soil_color_fallback(cell: Vector2i, data: Dictionary) -> void:
	var cell_key := _cell_key(cell)
	# PLOWED: không vẽ ColorRect fallback — để lớp Ground bên dưới hiện ra.
	if data.get("state", CropState.PLOWED) == CropState.PLOWED:
		if _soil_visuals.has(cell_key):
			var n = _soil_visuals[cell_key]
			if is_instance_valid(n):
				n.queue_free()
			_soil_visuals.erase(cell_key)
		return
	var rect := ColorRect.new()
	rect.name = "Soil_" + cell_key
	rect.color = _get_soil_color_fallback(data)
	rect.position = _cell_to_world(cell)
	rect.size = CELL_SIZE
	rect.z_index = 2
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	_soil_visuals[cell_key] = rect

func _get_soil_color_fallback(data: Dictionary) -> Color:
	# PLOWED không bao giờ chạm tới hàm này (đã bị skip ở _show_soil_visual /
	# _show_soil_color_fallback / _update_soil_visual_texture). Chỉ xử lý
	# cây thật (SEEDED → MATURE / WILTED).
	if data.get("watered", false):
		return Color(0.35, 0.22, 0.08, 0.85)
	return Color(0.55, 0.42, 0.25, 0.65)

func _hide_soil_visual(cell: Vector2i) -> void:
	var cell_key := _cell_key(cell)
	if not _soil_visuals.has(cell_key):
		return
	var n = _soil_visuals[cell_key]
	if is_instance_valid(n):
		n.queue_free()
	_soil_visuals.erase(cell_key)

func _clear_all_soil_visuals() -> void:
	for cell_key in _soil_visuals.keys():
		var n = _soil_visuals[cell_key]
		if is_instance_valid(n):
			n.queue_free()
	_soil_visuals.clear()

# =============================================================================
# PUBLIC API - REFRESH
# =============================================================================

func refresh_soil_visuals() -> void:
	if _farm_manager == null:
		return
	_clear_all_soil_visuals()
	if not _farm_manager.has_method("serialize"):
		return
	var data: Dictionary = _farm_manager.serialize()
	if not data.has("cells"):
		return
	for entry: Dictionary in data["cells"]:
		var cell := Vector2i(int(entry["x"]), int(entry["y"]))
		var cell_data: Dictionary = entry["data"]
		var state: CropState = cell_data.get("state", CropState.EMPTY)
		# PLOWED (đã đào, chưa trồng) → gọi _show_soil_visual để vẽ ColorRect
		# nâu đơn sắc (KHÔNG dùng atlas để tránh 3 chấm xanh baked-in).
		# SEEDED → MATURE / WILTED → dùng atlas (có sprite cây phù hợp).
		if state == CropState.PLOWED:
			_show_soil_visual(cell, cell_data)
			continue
		if state >= CropState.SEEDED:
			_show_soil_visual(cell, cell_data)

# =============================================================================
# UTILITIES
# =============================================================================

func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]
