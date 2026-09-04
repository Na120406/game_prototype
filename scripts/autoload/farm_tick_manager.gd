extends Node
# =============================================================================
# FarmTickManager (Autoload)
# =============================================================================
# Lưu trữ toàn bộ state farm (cells dict) và chạy day-boundary logic khi
# GameState.day_changed được emit — BẤT KỂ player đang ở scene nào.
#
# Lý do tồn tại: trước đây logic này nằm trong node FarmManager chỉ tồn tại
# trong farm_map.tscn → khi player knock-out ở scene nhà hoặc đang ở town,
# signal day_changed không ai nghe → cây không phát triển, nước không mất.
#
# FarmTickManager là autoload → luôn sống → luôn lắng nghe day_changed →
# state luôn đồng bộ.
#
# Scene FarmManager chỉ đóng vai trò RENDER (đọc state từ đây để vẽ tile).
# =============================================================================

const FarmEnumsRef = preload("res://scripts/autoload/farm_enums.gd")

# State chính: key "x,y" → Dictionary {type, state, growth_progress, watered,
# unwatered_streak, grow_days, water_need, growth_per_water, plowed_day, ...}
var cells: Dictionary = {}

# Ngày đã tick lần cuối — dùng để catch-up nếu signal bị miss (scene reload...)
var _last_day: int = -1

signal crop_planted(cell: Vector2i)
signal crop_growed(stage: int)
signal crop_harvested(cell: Vector2i, item_id: String)
signal watered_changed(cell: Vector2i)
signal cell_removed(cell: Vector2i)  # Emit khi cell bị xóa (plowed expire, v.v.)

func _ready() -> void:
	add_to_group("farm_tick_manager")
	# Farm day tick chỉ chạy lúc 6:00 (GameState.farm_day_changed). KHÔNG
	# listen day_changed vì calendar day có thể đổi lúc 00:00 (qua midnight)
	# mà farm cycle vẫn phải chờ tới 6:00.
	if not GameState.farm_day_changed.is_connected(_on_day_changed):
		GameState.farm_day_changed.connect(_on_day_changed)
	_restore_from_snapshot()
	print("[FarmTickManager] Ready. cells=%d day=%d" % [cells.size(), GameState.current_day])

func _on_day_changed(_new_day: int) -> void:
	_day_boundary_update(true)
	_last_day = GameState.current_day
	_persist_snapshot()

func _process(_delta: float) -> void:
	# Catch-up: nếu farm_day_changed bị miss (scene reload, signal connection
	# race), tự check dựa trên _last_day.
	if _last_day < 0:
		_last_day = GameState.current_day
		return
	if GameState.current_day != _last_day:
		var old_day: int = _last_day
		_last_day = GameState.current_day
		var missed: int = GameState.current_day - old_day
		for i in range(missed):
			_day_boundary_update(true)
		_persist_snapshot()

# =============================================================================
# CORE DAY-BOUNDARY LOGIC
# =============================================================================

func _day_boundary_update(reset_watered: bool) -> void:
	for cell_key in cells.keys():
		var data: Dictionary = cells[cell_key]
		var cell: Vector2i = _parse_cell_key(cell_key)
		var state: int = data.get("state", FarmEnumsRef.CropState.EMPTY)

		if state == FarmEnumsRef.CropState.EMPTY:
			continue

		# PLOWED soil — đất đào không trồng cây. Tự biến mất sau 1-2 ngày
		# (lifetime random chọn khi plow). Trước khi expire, reset watered mỗi ngày.
		if state == FarmEnumsRef.CropState.PLOWED:
			if data.get("watered", false):
				data["watered"] = false
				watered_changed.emit(cell)
			if _is_plowed_expired(data):
				cells.erase(cell_key)
				cell_removed.emit(cell)
			continue

		# MATURE / WILTED: reset watered
		if state in [FarmEnumsRef.CropState.MATURE, FarmEnumsRef.CropState.WILTED]:
			if reset_watered and data.get("watered", false):
				data["watered"] = false
				watered_changed.emit(cell)
			continue

		# Living crops (SEEDED / SPROUTED / GROWING)
		if FarmEnumsRef.is_living_state(state):
			var profile: Dictionary = FarmEnumsRef.get_water_profile(data.get("type", FarmEnumsRef.CropType.NONE))
			var water_need: int = profile["water_need"]
			var watered_today: bool = data.get("watered", false)

			_advance_growth_daily(data, cell)

			if watered_today:
				data["unwatered_streak"] = 0
				data["wilting"] = false
			else:
				data["unwatered_streak"] = data.get("unwatered_streak", 0) + 1
				if data["unwatered_streak"] >= water_need:
					data["state"] = FarmEnumsRef.CropState.WILTED
					data["wilting"] = true
					crop_growed.emit(FarmEnumsRef.CropState.WILTED)
					continue

			if reset_watered and watered_today:
				data["watered"] = false
				watered_changed.emit(cell)

func _is_plowed_expired(data: Dictionary) -> bool:
	# Lifetime được random 1-2 ngày lúc plow_cell(). Mặc định fallback 1 nếu
	# snapshot cũ thiếu trường này.
	var plowed_day: int = data.get("plowed_day", -1)
	if plowed_day < 0:
		return false
	var lifetime: int = int(data.get("plowed_lifetime", 1))
	if lifetime < 1:
		lifetime = 1
	var age: int = GameState.current_day - plowed_day
	return age >= lifetime

func _advance_growth_daily(data: Dictionary, cell: Vector2i) -> void:
	var grow_days: int = int(data.get("grow_days", 0))
	if grow_days <= 0:
		grow_days = 6
	var step: float = 1.0 / float(grow_days)
	data["growth_progress"] = clampf(data.get("growth_progress", 0.0) + step, 0.0, 1.0)
	# Tránh sai số số thực khiến cây hiển thị 100% nhưng vẫn còn state GROWING.
	if data["growth_progress"] >= 0.999:
		data["growth_progress"] = 1.0
	var progress: float = data["growth_progress"]

	var new_stage := FarmEnumsRef.CropState.SEEDED
	if progress >= 1.0:
		new_stage = FarmEnumsRef.CropState.MATURE
		data["mature_day"] = GameState.current_day
	elif progress >= 0.66:
		new_stage = FarmEnumsRef.CropState.GROWING
	elif progress >= 0.33:
		new_stage = FarmEnumsRef.CropState.SPROUTED

	if new_stage != data["state"]:
		data["state"] = new_stage
		print("[FarmTick] Cell %s advanced to stage %s (progress=%.2f)" % [
			str(cell), FarmEnumsRef.get_state_name(new_stage), progress
		])
		crop_growed.emit(new_stage)

# =============================================================================
# PUBLIC API — được gọi từ scene FarmManager và từ tool/UI scripts
# =============================================================================

func plant_crop(cell: Vector2i, crop_type: int, grow_days: int, water_need: int = 1, growth_per_water: float = 0.25) -> bool:
	var cell_key := _cell_key(cell)
	if not cells.has(cell_key):
		return false
	var existing: Dictionary = cells[cell_key]
	if existing["state"] != FarmEnumsRef.CropState.PLOWED:
		return false

	var was_watered: bool = existing.get("watered", false)
	cells[cell_key] = {
		"type": crop_type,
		"state": FarmEnumsRef.CropState.SEEDED,
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
	_persist_snapshot()
	return true

func plow_cell(cell: Vector2i) -> bool:
	var cell_key := _cell_key(cell)
	if cells.has(cell_key):
		return false
	# Lifetime ngẫu nhiên 1-2 ngày cho đất đào không trồng cây. Sau khoảng
	# này ô sẽ tự biến mất trong _day_boundary_update().
	var lifetime: int = 1 + (randi() % 2)
	cells[cell_key] = {
		"type": FarmEnumsRef.CropType.NONE,
		"state": FarmEnumsRef.CropState.PLOWED,
		"planted_day": -1,
		"planted_time": -1.0,
		"growth_progress": 0.0,
		"watered": false,
		"unwatered_streak": 0,
		"wilting": false,
		"grow_days": 0,
		"water_need": 1,
		"growth_per_water": 0.25,
		"plowed_day": GameState.current_day,
		"plowed_lifetime": lifetime,
	}
	_persist_snapshot()
	return true

func clear_wilted_cell(cell: Vector2i) -> bool:
	var cell_key := _cell_key(cell)
	if not cells.has(cell_key):
		return false
	if cells[cell_key]["state"] != FarmEnumsRef.CropState.WILTED:
		return false
	# Lifetime ngẫu nhiên 1-2 ngày giống plow_cell() — sau đó tự biến mất.
	var lifetime: int = 1 + (randi() % 2)
	cells[cell_key] = {
		"type": FarmEnumsRef.CropType.NONE,
		"state": FarmEnumsRef.CropState.PLOWED,
		"planted_day": -1,
		"planted_time": -1.0,
		"growth_progress": 0.0,
		"watered": false,
		"unwatered_streak": 0,
		"wilting": false,
		"grow_days": 0,
		"water_need": 1,
		"growth_per_water": 0.25,
		"plowed_day": GameState.current_day,
		"plowed_lifetime": lifetime,
	}
	_persist_snapshot()
	return true

func water_cell(cell: Vector2i) -> bool:
	var cell_key := _cell_key(cell)
	if not cells.has(cell_key):
		return false
	var state: int = cells[cell_key].get("state", FarmEnumsRef.CropState.EMPTY)
	if not FarmEnumsRef.can_water_state(state):
		return false
	cells[cell_key]["watered"] = true
	cells[cell_key]["unwatered_streak"] = 0
	cells[cell_key]["wilting"] = false
	watered_changed.emit(cell)
	return true

func harvest_crop(cell: Vector2i) -> String:
	var cell_key := _cell_key(cell)
	if not cells.has(cell_key):
		return ""
	var state: int = cells[cell_key].get("state", FarmEnumsRef.CropState.EMPTY)
	var progress: float = float(cells[cell_key].get("growth_progress", 0.0))
	# Cho phép thu hoạch ngay khi tiến độ đã đạt 100%, kể cả khi state chưa
	# kịp cập nhật trong cùng frame/ngày.
	if state != FarmEnumsRef.CropState.MATURE and progress < 1.0:
		return ""
	if state != FarmEnumsRef.CropState.MATURE:
		cells[cell_key]["state"] = FarmEnumsRef.CropState.MATURE
	cells[cell_key]["mature_day"] = GameState.current_day
	var crop_type: int = cells[cell_key].get("type", FarmEnumsRef.CropType.NONE)
	var item_id: String = FarmEnumsRef.get_harvest_id(crop_type)
	cells.erase(cell_key)
	crop_harvested.emit(cell, item_id)
	_persist_snapshot()
	return item_id

func get_cell_state(cell: Vector2i) -> int:
	var cell_key := _cell_key(cell)
	if not cells.has(cell_key):
		return FarmEnumsRef.CropState.EMPTY
	return cells[cell_key].get("state", FarmEnumsRef.CropState.EMPTY)

func get_cell_data(cell: Vector2i) -> Dictionary:
	var cell_key := _cell_key(cell)
	if not cells.has(cell_key):
		return {}
	return cells[cell_key]

func has_valid_crop(cell: Vector2i) -> bool:
	return FarmEnumsRef.is_living_state(get_cell_state(cell))

func get_harvest_id_for_seed(seed_id: String) -> String:
	var crop_type: int = FarmEnumsRef.get_crop_type_from_seed(seed_id)
	return FarmEnumsRef.get_harvest_id(crop_type)

# =============================================================================
# SERIALIZATION
# =============================================================================

func serialize() -> Dictionary:
	var out: Dictionary = {}
	for key in cells.keys():
		out[key] = cells[key].duplicate(true)
	return out

func deserialize(data: Dictionary) -> void:
	cells.clear()
	for key in data.keys():
		cells[key] = data[key].duplicate(true) if data[key] is Dictionary else data[key]


## Adapter save ổn định dùng trực tiếp source-of-truth FarmTickManager.
## Giữ format legacy {"cells": [{x, y, data}]} để save v3 vẫn tương thích.
func export_save_data() -> Dictionary:
	var cells_array: Array = []
	for cell_key: String in cells.keys():
		var parts: PackedStringArray = cell_key.split(",")
		if parts.size() != 2:
			continue
		cells_array.append({
			"x": int(parts[0]),
			"y": int(parts[1]),
			"data": cells[cell_key].duplicate(true),
		})
	return {"cells": cells_array}


## Restore trực tiếp vào autoload nên hoạt động ở mọi scene, kể cả Forest/Town.
func import_save_data(data: Dictionary) -> void:
	var restored: Dictionary = {}
	var entries: Variant = data.get("cells", [])
	if entries is Array:
		for entry: Variant in entries:
			if entry is Dictionary:
				var key := "%d,%d" % [int(entry.get("x", 0)), int(entry.get("y", 0))]
				restored[key] = entry.get("data", {}).duplicate(true)
	deserialize(restored)
	_sanitize_plowed_cells()
	_last_day = GameState.current_day
	_persist_snapshot()

func _save_to_snapshot() -> void:
	if cells.is_empty():
		GameState.set_flag("farm_cells_snapshot", null)
		return
	var snap: Dictionary = {
		"current_day": GameState.current_day,
		"cells": serialize(),
	}
	GameState.set_flag("farm_cells_snapshot", snap)

func _restore_from_snapshot() -> void:
	var snap = GameState.get_flag("farm_cells_snapshot", null)
	if snap == null:
		return
	if not (snap is Dictionary):
		return
	if not snap.has("cells"):
		GameState.set_flag("farm_cells_snapshot", null)
		return
	var saved_day: int = int(snap.get("current_day", -1))
	if saved_day < GameState.current_day:
		deserialize(snap["cells"])
		_sanitize_plowed_cells()
		var missed: int = GameState.current_day - saved_day
		for i in range(missed):
			_day_boundary_update(true)
		_last_day = GameState.current_day
		_persist_snapshot()
		print("[FarmTick] Restored %d cells, replayed %d days" % [cells.size(), missed])
	else:
		deserialize(snap["cells"])
		_sanitize_plowed_cells()
		_last_day = GameState.current_day
		print("[FarmTick] Restored %d cells (same day)" % cells.size())
	GameState.set_flag("farm_cells_snapshot", null)

func _sanitize_plowed_cells() -> void:
	# PLOWED (đất đào, chưa trồng) phải có watered=false. Snapshot cũ có thể
	# carry watered=true do bug trước đây → chuyển sang dùng WATER atlas có
	# chấm xanh trông như hạt giống. Ép lại về false.
	for cell_key in cells.keys():
		var data: Dictionary = cells[cell_key]
		var state: int = data.get("state", FarmEnumsRef.CropState.EMPTY)
		if state == FarmEnumsRef.CropState.PLOWED and data.get("watered", false):
			data["watered"] = false

func _persist_snapshot() -> void:
	_save_to_snapshot()

# =============================================================================
# HELPERS
# =============================================================================

func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]

func _parse_cell_key(key) -> Vector2i:
	if key is String:
		var parts: PackedStringArray = key.split(",")
		if parts.size() == 2:
			return Vector2i(int(parts[0]), int(parts[1]))
		return Vector2i.ZERO
	elif key is Vector2i:
		return key
	return Vector2i.ZERO
