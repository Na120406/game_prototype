extends Node2D

signal crop_planted(cell: Vector2i)
signal crop_growed(stage: int)
signal crop_harvested(cell: Vector2i, item_id: String)
signal watered_changed(cell: Vector2i)

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

# Per-crop water requirements. Keyed by CropType int.
# water_need         : consecutive un-watered days a crop survives before wilting.
#                      1 = must water every day, 3 = can skip up to 3 days.
# growth_per_water   : growth progress added per watering event (0.0 - 1.0).
#                      0.2 = 5 waterings to fully grow.
# stages_per_growth  : labels for visual stage thresholds (kept simple).
const _CROP_WATER_PROFILE: Dictionary = {
	CropType.WHEAT:    {"water_need": 2, "growth_per_water": 0.25},
	CropType.CORN:     {"water_need": 1, "growth_per_water": 0.20},
	CropType.TOMATO:   {"water_need": 1, "growth_per_water": 0.20},
	CropType.POTATO:   {"water_need": 3, "growth_per_water": 0.25},
	CropType.TURNIP:   {"water_need": 2, "growth_per_water": 0.20},
	CropType.MYSTERY_PLANT: {"water_need": 1, "growth_per_water": 0.20},
}

func _get_water_profile(crop_type: int) -> Dictionary:
	if _CROP_WATER_PROFILE.has(crop_type):
		return _CROP_WATER_PROFILE[crop_type]
	return {"water_need": 1, "growth_per_water": 0.25}

func _get_water_profile_from_db(seed_item_id: String) -> Dictionary:
	var db = get_node("/root/ItemDB")
	if db != null:
		var data: ItemData = db.get_item(seed_item_id)
		if data != null:
			return {
				"water_need": data.water_need if data.water_need > 0 else 1,
				"growth_per_water": data.growth_per_water if data.growth_per_water > 0.0 else 0.25,
			}
	return {"water_need": 1, "growth_per_water": 0.25}

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
		# If scene was reloaded with existing cells whose planted_day is in the past,
		# we must run the day-update at least once so watered flags reset.
		_update_all_crops()
		return
	if GameState.current_day != _last_day:
		var old_day: int = _last_day
		_last_day = GameState.current_day
		# Catch up for any missed days (e.g. slept in another scene)
		while old_day < GameState.current_day - 1:
			old_day += 1
		_update_all_crops()

func _update_all_crops() -> void:
	for cell_key in cells.keys():
		var data: Dictionary = cells[cell_key]
		var cell: Vector2i = _parse_cell_key(cell_key)
		var state: int = data.get("state", CropState.EMPTY)

		# PLOWED soil dries overnight — no growth logic.
		if state == CropState.PLOWED:
			if data.get("watered", false):
				data["watered"] = false
				_update_tile(cell, data)
				watered_changed.emit(cell)
			continue

		# MATURE / WILTED: just dry the soil if watered today.
		if state in [CropState.MATURE, CropState.WILTED]:
			if data.get("watered", false):
				data["watered"] = false
				_update_tile(cell, data)
				watered_changed.emit(cell)
			continue

		# Living crops (SEEDED / SPROUTED / GROWING).
		if state in [CropState.SEEDED, CropState.SPROUTED, CropState.GROWING]:
			var profile: Dictionary = _get_water_profile(data.get("type", CropType.NONE))
			var water_need: int = profile["water_need"]
			var watered_today: bool = data.get("watered", false)

			if watered_today:
				# Watered → plant advances one growth step.
				data["unwatered_streak"] = 0
				data["wilting"] = false
				# Soil dries for tomorrow.
				data["watered"] = false
				_advance_growth(data, cell)
			else:
				# Not watered today → increment streak. If it exceeds water_need
				# the plant wilts.
				data["unwatered_streak"] = data.get("unwatered_streak", 0) + 1
				if data["unwatered_streak"] > water_need:
					data["state"] = CropState.WILTED
					data["wilting"] = true
					data["watered"] = false
					_update_tile(cell, data)
					crop_growed.emit(CropState.WILTED)
					continue
			_update_tile(cell, data)

func _advance_growth(data: Dictionary, cell: Vector2i) -> void:
	# Each watering event adds growth_per_water to growth_progress (0..1+).
	var profile: Dictionary = _get_water_profile(data.get("type", CropType.NONE))
	var step: float = profile["growth_per_water"]
	data["growth_progress"] = clampf(data.get("growth_progress", 0.0) + step, 0.0, 1.0)
	var progress: float = data["growth_progress"]

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

func plant_crop(cell: Vector2i, crop_type: CropType, grow_days: int, water_need: int = 1, growth_per_water: float = 0.25) -> bool:
	var cell_key := _cell_key(cell)
	# Only allow planting on a PLOWED cell. EMPTY soil must be plowed with hoe first.
	if not cells.has(cell_key):
		print("[FarmManager] plant_crop: cell %s not in cells dict (must plow first)" % str(cell))
		return false
	var existing: Dictionary = cells[cell_key]
	if existing["state"] != CropState.PLOWED:
		print("[FarmManager] plant_crop: cell %s state=%d (must be PLOWED=1)" % [str(cell), existing["state"]])
		return false

	# Preserve watered status if the soil was already watered before planting.
	var was_watered: bool = existing.get("watered", false)

	cells[cell_key] = {
		"type": crop_type,
		"state": CropState.SEEDED,
		"planted_day": GameState.current_day,
		"planted_time": GameState.current_time,
		"growth_progress": 0.0,
		"watered": was_watered,
		"unwatered_streak": existing.get("unwatered_streak", 0),
		"wilting": existing.get("wilting", false),
		"grow_days": grow_days,
		"water_need": water_need,
		"growth_per_water": growth_per_water,
	}

	crop_planted.emit(cell)
	_update_tile(cell, cells[cell_key])
	return true

func plant_from_seed(cell: Vector2i, seed_item_id: String) -> bool:
	var crop_type: CropType = _SEED_TO_CROP.get(seed_item_id, CropType.NONE)
	if crop_type == CropType.NONE:
		print("[FarmManager] Unknown seed: %s" % seed_item_id)
		return false

	var db = get_node("/root/ItemDB")
	var grow_days: int = 6
	var water_need: int = 1
	var growth_per_water: float = 0.25
	if db != null:
		var data: ItemData = db.get_item(seed_item_id)
		if data != null:
			grow_days = data.grow_days if data.grow_days > 0 else 6
			water_need = data.water_need if data.water_need > 0 else 1
			growth_per_water = data.growth_per_water if data.growth_per_water > 0.0 else 0.25

	# Fall back to built-in profile if ItemDB left values at defaults.
	var profile: Dictionary = _get_water_profile(crop_type)
	if db == null or db.get_item(seed_item_id) == null:
		water_need = profile["water_need"]
		growth_per_water = profile["growth_per_water"]

	return plant_crop(cell, crop_type, grow_days, water_need, growth_per_water)

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
		"unwatered_streak": 0,
		"wilting": false,
		"grow_days": 0,
		"water_need": 1,
		"growth_per_water": 0.25,
	}

	_update_tile(cell, cells[cell_key])
	return true

## Used by the hoe to remove a wilted crop and return the cell to PLOWED
## so a new seed can be planted.
func clear_wilted_cell(cell: Vector2i) -> bool:
	var cell_key := _cell_key(cell)
	if not cells.has(cell_key):
		return false
	if cells[cell_key]["state"] != CropState.WILTED:
		return false

	cells[cell_key] = {
		"type": CropType.NONE,
		"state": CropState.PLOWED,
		"planted_day": -1,
		"planted_time": -1.0,
		"growth_progress": 0.0,
		"watered": false,
		"unwatered_streak": 0,
		"wilting": false,
		"grow_days": 0,
		"water_need": 1,
		"growth_per_water": 0.25,
	}
	_update_tile(cell, cells[cell_key])
	crop_harvested.emit(cell, "") # notify visuals to drop the wilted sprite
	print("[FarmManager] Cleared wilted crop at %s" % str(cell))
	return true

func water_cell(cell: Vector2i) -> bool:
	var cell_key := _cell_key(cell)
	if not cells.has(cell_key):
		return false

	var data: Dictionary = cells[cell_key]
	if data["state"] in [CropState.PLOWED, CropState.SEEDED, CropState.SPROUTED, CropState.GROWING, CropState.MATURE]:
		# If watered already today, do nothing.
		if data.get("watered", false):
			return false
		data["watered"] = true
		data["wilting"] = false
		data["unwatered_streak"] = 0

		# Watering marks the cell as watered but growth happens at end-of-day,
		# not instantly. Visual feedback still works via modulate / soil color.
		_update_tile(cell, data)
		watered_changed.emit(cell)
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
	print("[FarmManager] Deserialized %d cells, current_day=%d" % [cells.size(), GameState.current_day])
	# Apply day-boundary update so watered flags reflect the current day
	# (handles the case where the player slept in another scene).
	_last_day = GameState.current_day
	_update_all_crops()
