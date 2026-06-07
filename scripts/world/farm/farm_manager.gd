extends Node2D

signal crop_planted(cell: Vector2i)
signal crop_growed(stage: int)
signal crop_harvested(cell: Vector2i, item_id: String)

enum CropState { EMPTY, PLOWED, SEEDED, SPROUTED, GROWING, MATURE, WILTED }
enum CropType { NONE, WHEAT, CORN, TOMATO, POTATO, TURNIP, MYSTERY_PLANT }

const _CROP_TO_SEED: Dictionary = {
	CropType.WHEAT: "seed_wheat",
	CropType.CORN: "seed_corn",
	CropType.TOMATO: "seed_tomato",
	CropType.POTATO: "seed_potato",
	CropType.TURNIP: "seed_turnip",
}
const _CROP_TO_HARVEST: Dictionary = {
	CropType.WHEAT: "wheat",
	CropType.CORN: "corn",
	CropType.TOMATO: "tomato",
	CropType.POTATO: "potato",
	CropType.TURNIP: "turnip",
	CropType.MYSTERY_PLANT: "strange_fruit",
}
const _SEED_TO_CROP: Dictionary = {
	"seed_wheat": CropType.WHEAT,
	"seed_corn": CropType.CORN,
	"seed_tomato": CropType.TOMATO,
	"seed_potato": CropType.POTATO,
	"seed_turnip": CropType.TURNIP,
}

var grid_size: Vector2i = Vector2i(32, 32)
var cells: Dictionary = {}

@export var default_crop_type: CropType = CropType.WHEAT
@export var growth_time_hours: float = 24.0

func _ready() -> void:
	add_to_group("farm_manager")
	print("[FarmManager] Ready — grid: %s" % str(grid_size))

func plant_crop(cell: Vector2i, crop_type: CropType = CropType.WHEAT) -> bool:
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
		"wilting": false
	}

	crop_planted.emit(cell)
	_update_tile(cell, cells[cell_key])
	return true

func plant_from_seed(cell: Vector2i, seed_item_id: String) -> bool:
	var crop_type: CropType = _SEED_TO_CROP.get(seed_item_id, CropType.NONE)
	if crop_type == CropType.NONE:
		print("[FarmManager] Unknown seed: %s" % seed_item_id)
		return false
	return plant_crop(cell, crop_type)

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
		"wilting": false
	}

	_update_tile(cell, cells[cell_key])
	return true

func water_cell(cell: Vector2i) -> bool:
	var cell_key := _cell_key(cell)
	if not cells.has(cell_key):
		return false

	cells[cell_key]["watered"] = true
	print("[FarmManager] Watered cell: %s" % str(cell))
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

func get_grow_days_for_seed(seed_id: String) -> int:
	var seed_data: ItemData = null
	var db = get_node("/root/ItemDB")
	if db != null:
		seed_data = db.get_item(seed_id)
	if seed_data != null:
		return seed_data.grow_days
	return 6

const _SEASON_MULTIPLIER := {
	"spring": 1.0,
	"summer": 1.2,
	"autumn": 0.8,
	"winter": 0.3,
}

func _get_season_multiplier() -> float:
	return _SEASON_MULTIPLIER.get(WeatherSystem.current_season, 1.0)

func _get_weather_multiplier() -> float:
	var w := WeatherSystem.current_weather
	if w in ["rain", "heavy_rain", "drizzle"]:
		return 1.3
	if w in ["fog", "mist"]:
		return 0.9
	return 1.0

func _process(_delta: float) -> void:
	_update_crop_growth()

func _update_crop_growth() -> void:
	var season_mult := _get_season_multiplier()
	var weather_mult := _get_weather_multiplier()
	for cell_key in cells.keys():
		var data: Dictionary = cells[cell_key]
		if data["state"] == CropState.SEEDED or data["state"] == CropState.SPROUTED or data["state"] == CropState.GROWING:
			var hours_elapsed := _calculate_hours_elapsed(data)
			var growth_rate := 1.0 if data["watered"] else 0.5
			growth_rate *= season_mult * weather_mult
			data["growth_progress"] = hours_elapsed * growth_rate / growth_time_hours

			var new_stage := CropState.SEEDED
			if data["growth_progress"] >= 1.0:
				new_stage = CropState.MATURE
			elif data["growth_progress"] >= 0.66:
				new_stage = CropState.GROWING
			elif data["growth_progress"] >= 0.33:
				new_stage = CropState.SPROUTED

			if new_stage != data["state"]:
				data["state"] = new_stage
				var cell: Vector2i = _parse_cell_key(cell_key)
				_update_tile(cell, data)
				crop_growed.emit(new_stage)

			if not data["watered"] and data["growth_progress"] > 0.5:
				data["wilting"] = true

func _calculate_hours_elapsed(data: Dictionary) -> float:
	var start_day: float = data.get("planted_day", GameState.current_day)
	var start_time: float = data.get("planted_time", GameState.current_time)
	var current_day: float = GameState.current_day
	var current_time: float = GameState.current_time

	var days_diff := current_day - start_day
	return days_diff * 24.0 + (current_time - start_time)

func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]

func _parse_cell_key(key: String) -> Vector2i:
	var parts: PackedStringArray = key.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))

func _update_tile(_cell: Vector2i, _data: Dictionary) -> void:
	pass

func get_cell_state(cell: Vector2i) -> int:
	var cell_key := _cell_key(cell)
	if not cells.has(cell_key):
		return CropState.EMPTY
	return cells[cell_key]["state"]

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
