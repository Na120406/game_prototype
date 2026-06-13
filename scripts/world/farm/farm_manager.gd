extends Node2D

signal crop_planted(cell: Vector2i)
signal crop_growed(stage: int)
signal crop_harvested(cell: Vector2i, item_id: String)

enum CropState { EMPTY, PLOWED, SEEDED, SPROUTED, GROWING, MATURE, WILTED }
enum CropType { NONE, WHEAT, CORN, TOMATO, POTATO, TURNIP, MYSTERY_PLANT }

const _SEED_TO_CROP: Dictionary = {
	"seed_wheat": CropType.WHEAT,
	"seed_corn": CropType.CORN,
	"seed_tomato": CropType.TOMATO,
	"seed_potato": CropType.POTATO,
	"seed_turnip": CropType.TURNIP,
}
const _CROP_TO_HARVEST: Dictionary = {
	CropType.WHEAT: "wheat",
	CropType.CORN: "corn",
	CropType.TOMATO: "tomato_harvest",
	CropType.POTATO: "potato_harvest",
	CropType.TURNIP: "turnip_harvest",
	CropType.MYSTERY_PLANT: "strange_fruit",
}

var _plot_layer: TileMapLayer = null
var _last_day: int = -1

var grid_size: Vector2i = Vector2i(32, 32)
var cells: Dictionary = {}

@export var default_crop_type: CropType = CropType.WHEAT

func _ready() -> void:
	add_to_group("farm_manager")
	_find_plot_layer()

func _find_plot_layer() -> void:
	_plot_layer = get_tree().get_first_node_in_group("farm_plot")
	if _plot_layer == null:
		var parent := get_parent()
		if parent != null:
			_plot_layer = parent.find_child("FarmPlot", true, false)
	if _plot_layer != null:
		print("[FarmManager] Connected to FarmPlot TileMapLayer.")

func _process(_delta: float) -> void:
	if _last_day < 0:
		_last_day = GameState.current_day
		return
	if GameState.current_day != _last_day:
		_last_day = GameState.current_day
		_update_all_crops()

func _update_all_crops() -> void:
	for cell_key in cells.keys():
		var data: Dictionary = cells[cell_key]
		if data["state"] in [CropState.SEEDED, CropState.SPROUTED, CropState.GROWING]:
			var cell: Vector2i = _parse_cell_key(cell_key)
			_advance_growth(data, cell)

func _advance_growth(data: Dictionary, cell: Vector2i) -> void:
	var grow_days: int = data.get("grow_days", 6)
	var days_elapsed: int = GameState.current_day - data.get("planted_day", GameState.current_day)
	var progress: float = float(days_elapsed) / float(grow_days) if grow_days > 0 else 1.0
	data["growth_progress"] = clampf(progress, 0.0, 1.0)

	var new_stage := CropState.SEEDED
	if progress >= 1.0:
		new_stage = CropState.MATURE
	elif progress >= 0.66:
		new_stage = CropState.GROWING
	elif progress >= 0.33:
		new_stage = CropState.SPROUTED

	if new_stage != data["state"]:
		data["state"] = new_stage
		_update_tile(cell, data)
		crop_growed.emit(new_stage)

	if not data["watered"] and progress > 0.5:
		data["wilting"] = true
		data["state"] = CropState.WILTED
		_update_tile(cell, data)

func plant_crop(cell: Vector2i, crop_type: CropType, grow_days: int) -> bool:
	var cell_key := _cell_key(cell)
	if cells.has(cell_key) and cells[cell_key]["state"] != CropState.EMPTY:
		return false

	cells[cell_key] = {
		"type": crop_type,
		"state": CropState.SEEDED,
		"planted_day": GameState.current_day,
		"planted_time": GameState.current_time,
		"growth_progress": 0.0,
		"watered": false,
		"wilting": false,
		"grow_days": grow_days,
	}

	crop_planted.emit(cell)
	_update_tile(cell, cells[cell_key])
	return true

func plant_from_seed(cell: Vector2i, seed_item_id: String) -> bool:
	var crop_type: CropType = _SEED_TO_CROP.get(seed_item_id, CropType.NONE)
	if crop_type == CropType.NONE:
		print("[FarmManager] Unknown seed: %s" % seed_item_id)
		return false

	var grow_days: int = 6
	var db = get_node("/root/ItemDB")
	if db != null:
		var data: ItemData = db.get_item(seed_item_id)
		if data != null:
			grow_days = data.grow_days if data.grow_days > 0 else 6

	return plant_crop(cell, crop_type, grow_days)

func plow_cell(cell: Vector2i) -> bool:
	var cell_key := _cell_key(cell)
	if cells.has(cell_key):
		return false

	cells[cell_key] = {
		"type": CropType.NONE,
		"state": CropState.PLOWED,
		"planted_day": -1,
		"planted_time": -1.0,
		"growth_progress": 0.0,
		"watered": false,
		"wilting": false,
		"grow_days": 0,
	}

	_update_tile(cell, cells[cell_key])
	return true

func water_cell(cell: Vector2i) -> bool:
	var cell_key := _cell_key(cell)
	if not cells.has(cell_key):
		return false

	var data: Dictionary = cells[cell_key]
	if data["state"] in [CropState.SEEDED, CropState.SPROUTED, CropState.GROWING]:
		data["watered"] = true
		data["wilting"] = false
		var days_elapsed: int = GameState.current_day - data.get("planted_day", GameState.current_day)
		var grow_days: int = data.get("grow_days", 6)
		var progress: float = (float(days_elapsed) * 1.5) / float(grow_days) if grow_days > 0 else 1.0
		progress = clampf(progress, 0.0, 1.5)
		if progress > 1.0:
			_advance_growth(data, cell)
		else:
			data["growth_progress"] = progress
			var new_stage := CropState.SEEDED
			if progress >= 0.66:
				new_stage = CropState.GROWING
			elif progress >= 0.33:
				new_stage = CropState.SPROUTED
			if new_stage != data["state"]:
				data["state"] = new_stage
				crop_growed.emit(new_stage)
		_update_tile(cell, data)
		print("[FarmManager] Watered cell: %s (progress: %.1f%%)" % [str(cell), progress * 100])

	return true

func harvest_crop(cell: Vector2i) -> String:
	var cell_key := _cell_key(cell)
	if not cells.has(cell_key):
		return ""

	var cell_data: Dictionary = cells[cell_key]
	if cell_data["state"] != CropState.MATURE:
		return ""

	var crop_type: CropType = cell_data["type"]
	var harvest_id: String = _CROP_TO_HARVEST.get(crop_type, "")

	if harvest_id == "":
		return ""

	var item_data: ItemData = null
	var db = get_node("/root/ItemDB")
	if db != null:
		item_data = db.get_item(harvest_id)
	if item_data == null:
		print("[FarmManager] No ItemData for harvest: %s" % harvest_id)
		return ""

	GameState.add_item(harvest_id, 1)
	cells.erase(cell_key)

	_update_tile(cell, {"type": CropType.NONE, "state": CropState.EMPTY})
	crop_harvested.emit(cell, harvest_id)

	return harvest_id

func get_harvest_id_for_seed(seed_id: String) -> String:
	var crop_type: CropType = _SEED_TO_CROP.get(seed_id, CropType.NONE)
	return _CROP_TO_HARVEST.get(crop_type, "")

func get_cell_state(cell: Vector2i) -> int:
	var cell_key := _cell_key(cell)
	if not cells.has(cell_key):
		return CropState.EMPTY
	return cells[cell_key]["state"]

func get_cell_data(cell: Vector2i) -> Dictionary:
	var cell_key := _cell_key(cell)
	return cells.get(cell_key, {})

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
	var wilted: bool = data.get("wilting", false)

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

	_plot_layer.set_cell(cell, 0, Vector2i(tile_id % 4, tile_id / 4))

func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]

func _parse_cell_key(key: String) -> Vector2i:
	var parts: PackedStringArray = key.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))

func serialize() -> Dictionary:
	var cells_array: Array = []
	for cell_key in cells.keys():
		var data: Dictionary = cells[cell_key].duplicate()
		var parts: PackedStringArray = cell_key.split(",")
		cells_array.append({
			"x": int(parts[0]),
			"y": int(parts[1]),
			"data": data,
		})
	return {
		"cells": cells_array,
		"grid_size": {"x": grid_size.x, "y": grid_size.y},
	}

func deserialize(data: Dictionary) -> void:
	cells.clear()
	if data.has("grid_size"):
		var gs: Dictionary = data["grid_size"]
		grid_size = Vector2i(int(gs.get("x", 32)), int(gs.get("y", 32)))
	if data.has("cells"):
		for entry: Dictionary in data["cells"]:
			var cell := Vector2i(int(entry["x"]), int(entry["y"]))
			var cell_data: Dictionary = entry["data"]
			cells[_cell_key(cell)] = cell_data
			_update_tile(cell, cell_data)
	print("[FarmManager] Deserialized %d cells." % cells.size())
