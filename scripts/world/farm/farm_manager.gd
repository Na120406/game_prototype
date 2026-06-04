extends Node2D

signal crop_planted(cell: Vector2i)
signal crop_growed(stage: int)
signal crop_harvested(cell: Vector2i, item_id: String)

enum CropState { EMPTY, PLOWED, SEEDED, SPROUTED, GROWING, MATURE, WILTED }
enum CropType { NONE, WHEAT, CORN, TOMATO, POTATO, MYSTERY_PLANT }

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
	var harvest_id := _get_harvest_id(crop_type)

	GameState.add_item(harvest_id, 1)
	cells.erase(cell_key)

	_update_tile(cell, {"type": CropType.NONE, "state": CropState.EMPTY})
	crop_harvested.emit(cell, harvest_id)

	return harvest_id

func _process(_delta: float) -> void:
	_update_crop_growth()

func _update_crop_growth() -> void:
	for cell_key in cells.keys():
		var data: Dictionary = cells[cell_key]
		if data["state"] == CropState.SEEDED or data["state"] == CropState.SPROUTED or data["state"] == CropState.GROWING:
			var hours_elapsed := _calculate_hours_elapsed(data)
			var growth_rate := 1.0 if data["watered"] else 0.5
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

func _get_harvest_id(crop_type: CropType) -> String:
	match crop_type:
		CropType.WHEAT: return "wheat"
		CropType.CORN: return "corn"
		CropType.TOMATO: return "tomato"
		CropType.POTATO: return "potato"
		CropType.MYSTERY_PLANT: return "strange_fruit"
	return ""

func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]

func _parse_cell_key(key: String) -> Vector2i:
	var parts := key.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))

func _update_tile(_cell: Vector2i, _data: Dictionary) -> void:
	pass

func get_cell_state(cell: Vector2i) -> int:
	var cell_key := _cell_key(cell)
	if not cells.has(cell_key):
		return CropState.EMPTY
	return cells[cell_key]["state"]
