extends Node2D
# =============================================================================
# FARM MANAGER (Scene-side render layer)
# =============================================================================
# Chỉ làm nhiệm vụ RENDER tiles + routing actions tới FarmTickManager
# (autoload). Toàn bộ state + day-boundary logic đã chuyển sang
# FarmTickManager để chạy được bất kể player ở scene nào.
#
# Truy cập autoload qua helper _ft() (dùng get_node thay vì identifier
# trực tiếp) để tránh parse error khi editor chưa reload project sau khi
# thêm autoload mới vào project.godot.
# =============================================================================

const FarmEnumsRef = preload("res://scripts/autoload/farm_enums.gd")
const CropState = FarmEnumsRef.CropState
const CropType = FarmEnumsRef.CropType

signal crop_planted(cell: Vector2i)
signal crop_growed(stage: int)
signal crop_harvested(cell: Vector2i, item_id: String)
signal watered_changed(cell: Vector2i)

var _plot_layer: TileMapLayer = null
var grid_size: Vector2i = Vector2i(32, 32)
var _ft: Node = null

@export var default_crop_type: CropType = CropType.WHEAT

func _ready() -> void:
	add_to_group("farm_manager")
	_find_plot_layer()
	# Lazy-resolve autoload. Nếu autoload chưa sẵn, gọi lại ở _process lần đầu.
	_ft = _resolve_farm_tick()
	_connect_signals()
	_refresh_all_tiles()
	print("[FarmManager] Ready (delegating state to FarmTickManager).")

func _resolve_farm_tick() -> Node:
	if _ft != null and is_instance_valid(_ft):
		return _ft
	var tree := get_tree()
	if tree == null:
		return null
	var node := tree.root.get_node_or_null("FarmTickManager")
	if node != null:
		_ft = node
	return node

func _connect_signals() -> void:
	if _ft == null:
		return
	if not _ft.crop_planted.is_connected(_on_crop_planted):
		_ft.crop_planted.connect(_on_crop_planted)
	if not _ft.crop_growed.is_connected(_on_crop_growed):
		_ft.crop_growed.connect(_on_crop_growed)
	if not _ft.crop_harvested.is_connected(_on_crop_harvested):
		_ft.crop_harvested.connect(_on_crop_harvested)
	if not _ft.watered_changed.is_connected(_on_watered_changed):
		_ft.watered_changed.connect(_on_watered_changed)

func _process(_delta: float) -> void:
	# Nếu autoload chưa sẵn lúc _ready (do editor chưa reload) → thử lại.
	if _ft == null or not is_instance_valid(_ft):
		_ft = _resolve_farm_tick()
		if _ft != null:
			_connect_signals()
			_refresh_all_tiles()

func _find_plot_layer() -> void:
	_plot_layer = get_tree().get_first_node_in_group("farm_plot")
	if _plot_layer == null:
		var parent := get_parent()
		if parent != null:
			_plot_layer = parent.find_child("FarmPlot", true, false)
	if _plot_layer != null:
		print("[FarmManager] Connected to FarmPlot TileMapLayer.")

func _refresh_all_tiles() -> void:
	if _ft == null:
		return
	var cells_dict: Dictionary = _ft.get("cells")
	if cells_dict == null:
		return
	for cell_key in cells_dict.keys():
		var data: Dictionary = cells_dict[cell_key]
		var cell: Vector2i = _parse_cell_key(cell_key)
		_update_tile(cell, data)

# =============================================================================
# SIGNAL HANDLERS — render visuals khi state đổi
# =============================================================================

func _on_crop_planted(cell: Vector2i) -> void:
	crop_planted.emit(cell)
	_update_tile(cell, _get_cell_data(cell))

func _on_crop_growed(_stage: int) -> void:
	crop_growed.emit(_stage)
	_refresh_all_tiles()

func _on_crop_harvested(cell: Vector2i, item_id: String) -> void:
	crop_harvested.emit(cell, item_id)
	_update_tile(cell, {"type": CropType.NONE, "state": CropState.EMPTY})

func _on_watered_changed(cell: Vector2i) -> void:
	watered_changed.emit(cell)
	_update_tile(cell, _get_cell_data(cell))

func _get_cell_data(cell: Vector2i) -> Dictionary:
	if _ft == null:
		return {}
	if _ft.has_method("get_cell_data"):
		return _ft.get_cell_data(cell)
	return {}

# =============================================================================
# PUBLIC API — delegate tới FarmTickManager, sau đó update visuals
# =============================================================================

func plant_crop(cell: Vector2i, crop_type: CropType, grow_days: int, water_need: int = 1, growth_per_water: float = 0.25) -> bool:
	if _ft == null:
		return false
	var ok: bool = _ft.call("plant_crop", cell, int(crop_type), grow_days, water_need, growth_per_water)
	if ok:
		_update_tile(cell, _get_cell_data(cell))
	return ok

func plant_from_seed(cell: Vector2i, seed_item_id: String) -> bool:
	var crop_type: int = FarmEnumsRef.get_crop_type_from_seed(seed_item_id)
	if crop_type == int(CropType.NONE):
		print("[FarmManager] Unknown seed: %s" % seed_item_id)
		return false
	var profile: Dictionary = FarmEnumsRef.get_water_profile(crop_type)
	var grow_days: int = profile["grow_days"]
	var water_need: int = profile["water_need"]
	var growth_per_water: float = profile["growth_per_water"]
	var db = get_node_or_null("/root/ItemDB")
	if db != null:
		var seed_data: ItemData = db.get_item(seed_item_id)
		if seed_data != null:
			if seed_data.grow_days > 0:
				grow_days = seed_data.grow_days
			if seed_data.water_need > 0:
				water_need = seed_data.water_need
			if seed_data.growth_per_water > 0.0:
				growth_per_water = seed_data.growth_per_water
	return plant_crop(cell, crop_type, grow_days, water_need, growth_per_water)

func plow_cell(cell: Vector2i) -> bool:
	if _ft == null:
		return false
	var ok: bool = _ft.call("plow_cell", cell)
	if ok:
		_update_tile(cell, _get_cell_data(cell))
	return ok

func clear_wilted_cell(cell: Vector2i) -> bool:
	if _ft == null:
		return false
	var ok: bool = _ft.call("clear_wilted_cell", cell)
	if ok:
		_update_tile(cell, _get_cell_data(cell))
	return ok

func water_cell(cell: Vector2i) -> bool:
	if _ft == null:
		return false
	var ok: bool = _ft.call("water_cell", cell)
	if ok:
		_update_tile(cell, _get_cell_data(cell))
	return ok

func harvest_crop(cell: Vector2i) -> String:
	if _ft == null:
		return ""
	var harvest_id: String = _ft.call("harvest_crop", cell)
	if harvest_id != "":
		GameState.add_item(harvest_id, 2)
		_update_tile(cell, {"type": CropType.NONE, "state": CropState.EMPTY})
	return harvest_id

# =============================================================================
# GETTERS — delegate
# =============================================================================

func get_harvest_id_for_seed(seed_id: String) -> String:
	if _ft == null:
		return ""
	return _ft.call("get_harvest_id_for_seed", seed_id)

func get_cell_state(cell: Vector2i) -> CropState:
	if _ft == null:
		return CropState.EMPTY
	return _ft.call("get_cell_state", cell) as CropState

func get_cell_data(cell: Vector2i) -> Dictionary:
	return _get_cell_data(cell)

func has_valid_crop(cell: Vector2i) -> bool:
	if _ft == null:
		return false
	return _ft.call("has_valid_crop", cell)

func serialize() -> Dictionary:
	if _ft == null:
		return {"cells": []}
	var cells_dict: Dictionary = _ft.get("cells")
	var cells_array: Array = []
	for cell_key in cells_dict.keys():
		var data: Dictionary = cells_dict[cell_key]
		var cell: Vector2i = _parse_cell_key(cell_key)
		cells_array.append({
			"x": cell.x,
			"y": cell.y,
			"data": data.duplicate(true),
		})
	return {"cells": cells_array}

func get_cells() -> Dictionary:
	if _ft == null:
		return {}
	return _ft.get("cells")

func deserialize(data: Dictionary) -> void:
	# Compatibility shim — CatchUpSystem và scene_manager cũ vẫn gọi trên
	# farm_manager. Trong kiến trúc mới, state đã được chuyển sang
	# FarmTickManager nên ta chỉ cần load snapshot nếu cần.
	if _ft == null:
		return
	if data == null:
		return
	if data.has("cells") and data["cells"] is Array:
		var cells_dict: Dictionary = {}
		for cell_entry in data["cells"]:
			if cell_entry is Dictionary:
				var key_str := "%d,%d" % [int(cell_entry.get("x", 0)), int(cell_entry.get("y", 0))]
				cells_dict[key_str] = cell_entry.get("data", {})
		_ft.set("cells", cells_dict)
		_ft.call("_persist_snapshot")

# =============================================================================
# TILE RENDERING
# =============================================================================

const _TILE_EMPTY: int = 0
const _TILE_SOIL: int = 1
const _TILE_PLOWED: int = 2
const _TILE_WATERED: int = 3
const _TILE_SEEDED: int = 4
const _TILE_SPROUTED: int = 5
const _TILE_GROWING: int = 6
const _TILE_MATURE: int = 7
const _TILE_WILTED: int = 8

func _update_tile(cell: Vector2i, data: Dictionary) -> void:
	if _plot_layer == null:
		_find_plot_layer()
	if _plot_layer == null:
		return

	var state: int = data.get("state", CropState.EMPTY)
	var watered: bool = data.get("watered", false)

	var tile_id: int
	match state:
		CropState.EMPTY: tile_id = _TILE_EMPTY
		CropState.PLOWED: tile_id = _TILE_WATERED if watered else _TILE_PLOWED
		CropState.SEEDED: tile_id = _TILE_SEEDED
		CropState.SPROUTED: tile_id = _TILE_SPROUTED
		CropState.GROWING: tile_id = _TILE_GROWING
		CropState.MATURE: tile_id = _TILE_MATURE
		CropState.WILTED: tile_id = _TILE_WILTED
		_: tile_id = _TILE_EMPTY

	if state in [CropState.SEEDED, CropState.SPROUTED, CropState.GROWING] and watered:
		tile_id = _TILE_WATERED

	# Visuals render via Sprite2D in farm_plot.gd (refresh_soil_visuals); set_cell
	# on the FarmPlot TileMapLayer's icon-based atlas keeps failing because the
	# tileset only has 1 tile. Skip tile writes to avoid runtime errors.
	# Uncomment the line below only after replacing farm_tileset.tres with a
	# tileset that has at least 9 atlas tiles (3 columns x 3 rows of crop states).
	# _plot_layer.set_cell(cell, 0, Vector2i(tile_id % 4, tile_id / 4))

func _parse_cell_key(key) -> Vector2i:
	if key is String:
		var parts: PackedStringArray = key.split(",")
		if parts.size() == 2:
			return Vector2i(int(parts[0]), int(parts[1]))
		return Vector2i.ZERO
	elif key is Vector2i:
		return key
	return Vector2i.ZERO
