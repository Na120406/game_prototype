extends Node2D
# =============================================================================
# CROP VISUAL MANAGER - Hiển thị crop sprites trên farm
# =============================================================================
# v3: Renders each crop as a colored ColorRect scaled by growth_progress.
# Uses FarmEnums for all shared enum definitions.
# =============================================================================

signal crop_visual_changed(cell: Vector2i)

const CELL_SIZE: Vector2 = Vector2(16, 16)
const FARM_ZONE := Rect2(24, 274, 592, 302)

var _sprites: Dictionary = {}
var _farm_manager: Node = null
var _update_timer: float = 0.0
var _last_day: int = -1

# Sử dụng FarmEnums (load trực tiếp để tránh phụ thuộc autoload)
const FarmEnumsRef = preload("res://scripts/autoload/farm_enums.gd")
const CropState = FarmEnumsRef.CropState
const CropType = FarmEnumsRef.CropType

# Base color per crop type (dùng FarmEnums keys)
const CROP_COLORS: Dictionary = {
	CropType.WHEAT:   Color(0.85, 0.75, 0.35),
	CropType.CORN:    Color(0.95, 0.85, 0.30),
	CropType.TOMATO:  Color(0.85, 0.30, 0.30),
	CropType.POTATO:  Color(0.70, 0.55, 0.35),
	CropType.TURNIP:  Color(0.65, 0.80, 0.45),
	CropType.MYSTERY_PLANT: Color(0.65, 0.45, 0.85),
}

const WILTED_COLOR := Color(0.75, 0.20, 0.20)
const SEEDED_MIN_SIZE := 4.0

func _ready() -> void:
	add_to_group("crop_visual_manager")
	call_deferred("_initialize")
	await get_tree().physics_frame
	if _farm_manager == null:
		_initialize()

func _initialize() -> void:
	if _farm_manager == null:
		_farm_manager = get_tree().get_first_node_in_group("farm_manager")
	if _farm_manager == null:
		push_warning("[CropVisual] No FarmManager found!")
		return
	if not _farm_manager.crop_planted.is_connected(_on_crop_planted):
		_farm_manager.crop_planted.connect(_on_crop_planted)
	if not _farm_manager.crop_growed.is_connected(_on_crop_growed):
		_farm_manager.crop_growed.connect(_on_crop_growed)
	if not _farm_manager.crop_harvested.is_connected(_on_crop_harvested):
		_farm_manager.crop_harvested.connect(_on_crop_harvested)
	if _farm_manager.has_signal("cell_removed") and not _farm_manager.cell_removed.is_connected(_on_cell_removed):
		_farm_manager.cell_removed.connect(_on_cell_removed)
	_refresh_all_visuals()
	if not GameState.day_changed.is_connected(_on_day_changed):
		GameState.day_changed.connect(_on_day_changed)
	print("[CropVisual] Ready, cells=%d" % _sprites.size())

func _process(delta: float) -> void:
	_update_timer += delta
	if _update_timer < 0.5:
		return
	_update_timer = 0.0
	var current_day := GameState.current_day
	if current_day != _last_day:
		_last_day = current_day
		_refresh_all_visuals()
	_refresh_visuals_for_visible_cells()

# =============================================================================
# SPRITE MANAGEMENT
# =============================================================================

func _spawn_sprite(cell: Vector2i, data: Dictionary) -> void:
	var cell_key := _cell_key(cell)
	var state: CropState = data.get("state", CropState.EMPTY)
	# PLOWED (đất đào, chưa trồng) → KHÔNG spawn crop sprite. Mặc định
	# color = green cho crop_type=NONE nên sẽ tạo ra chấm xanh giống hạt
	# giống trong ô đất trống.
	if state <= CropState.PLOWED:
		_remove_sprite(cell)
		return
	if _sprites.has(cell_key):
		_update_sprite_body(cell_key, cell, data)
		return

	var rect := ColorRect.new()
	rect.name = "Crop_" + cell_key
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.z_index = 4
	rect.position = FARM_ZONE.position + Vector2(cell) * CELL_SIZE
	rect.size = CELL_SIZE
	rect.color = _get_crop_color_for_data(data)
	add_child(rect)
	_sprites[cell_key] = rect
	_update_sprite_body(cell_key, cell, data)

func _update_sprite(cell: Vector2i, data: Dictionary) -> void:
	var cell_key := _cell_key(cell)
	var state: CropState = data.get("state", CropState.EMPTY)
	# PLOWED/EMPTY → đảm bảo sprite cũ bị ẩn/xóa (không có chấm xanh).
	if state <= CropState.PLOWED:
		_remove_sprite(cell)
		return
	if not _sprites.has(cell_key):
		_spawn_sprite(cell, data)
		return
	_update_sprite_body(cell_key, cell, data)

func _update_sprite_body(cell_key: String, cell: Vector2i, data: Dictionary) -> void:
	if not _sprites.has(cell_key):
		return
	var rect: ColorRect = _sprites[cell_key]
	if not is_instance_valid(rect):
		return

	var state: CropState = data.get("state", CropState.EMPTY)

	# Ẩn sprite cho EMPTY / PLOWED (đất đào chưa trồng → KHÔNG có chấm xanh)
	if state <= CropState.PLOWED:
		rect.visible = false
		return

	# Tính size dựa trên growth_progress
	var progress: float
	if state == CropState.WILTED:
		progress = data.get("wilted_scale", 0.0)
	else:
		progress = data.get("growth_progress", 0.0)

	var max_size: float = CELL_SIZE.x
	var size: float = lerp(SEEDED_MIN_SIZE, max_size, clampf(progress, 0.0, 1.0))
	if state == CropState.SEEDED:
		size = SEEDED_MIN_SIZE

	var cell_origin: Vector2 = FARM_ZONE.position + Vector2(cell) * CELL_SIZE
	rect.size = Vector2(size, size)
	rect.position = cell_origin + (CELL_SIZE - rect.size) * 0.5
	rect.color = _get_crop_color_for_data(data)
	rect.visible = true
	crop_visual_changed.emit(cell)

func _get_crop_color_for_data(data: Dictionary) -> Color:
	var state: CropState = data.get("state", CropState.EMPTY)
	if state == CropState.WILTED or data.get("wilting", false):
		return WILTED_COLOR
	var crop_type: CropType = data.get("type", CropType.NONE)
	return CROP_COLORS.get(crop_type, Color(0.4, 0.7, 0.3))

# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

func _on_crop_planted(cell: Vector2i) -> void:
	if _farm_manager == null:
		return
	var cell_data: Dictionary = _farm_manager.get_cell_data(cell)
	_spawn_sprite(cell, cell_data)

func _on_crop_growed(_stage: int) -> void:
	pass

func _on_crop_harvested(cell: Vector2i, _item_id: String) -> void:
	_remove_sprite(cell)

func _on_cell_removed(cell: Vector2i) -> void:
	# PLOWED expire / harvest / etc → xóa crop sprite.
	_remove_sprite(cell)

func on_farm_data_loaded() -> void:
	_refresh_all_visuals()

func _on_day_changed(_new_day: int) -> void:
	_refresh_visuals_for_visible_cells()

# =============================================================================
# DATA REFRESH
# =============================================================================

func _refresh_all_visuals() -> void:
	if _farm_manager == null or not _farm_manager.has_method("serialize"):
		return
	var data: Dictionary = _farm_manager.serialize()
	if not data.has("cells"):
		return
	for entry: Dictionary in data["cells"]:
		var cell := Vector2i(int(entry["x"]), int(entry["y"]))
		_spawn_sprite(cell, entry["data"])

func _refresh_visuals_for_visible_cells() -> void:
	if _farm_manager == null or not _farm_manager.has_method("serialize"):
		return
	var data: Dictionary = _farm_manager.serialize()
	if not data.has("cells"):
		return
	for entry: Dictionary in data["cells"]:
		var cell := Vector2i(int(entry["x"]), int(entry["y"]))
		_update_sprite(cell, entry["data"])

func _remove_sprite(cell: Vector2i) -> void:
	var cell_key := _cell_key(cell)
	if _sprites.has(cell_key):
		_sprites[cell_key].queue_free()
		_sprites.erase(cell_key)

func rebuild_all() -> void:
	for s in _sprites.values():
		if is_instance_valid(s):
			s.queue_free()
	_sprites.clear()
	_refresh_all_visuals()

func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]
