extends Node

const SAVE_PATH := "user://save_game_%d.dat"

var save_slots: Array[Dictionary] = [
	{},
	{},
	{},
]

var current_slot: int = 0

signal save_completed(slot: int)
signal load_completed(slot: int)

func _ready() -> void:
	print("[SaveManager] Ready — save path: %s" % SAVE_PATH)

func save_game(slot: int = 0) -> bool:
	if slot < 0 or slot >= save_slots.size():
		return false

	var save_data: Dictionary = CatchUpSystem.prepare_save_data()
	save_slots[slot] = save_data

	var file: FileAccess = FileAccess.open(SAVE_PATH % slot, FileAccess.WRITE)
	if file == null:
		push_error("[SaveManager] Cannot open save file for writing.")
		return false

	var json_str: String = JSON.stringify(save_data, "\t")
	file.store_line(json_str)
	file.close()

	save_completed.emit(slot)
	print("[SaveManager] Saved to slot %d." % slot)
	return true

func load_game(slot: int = 0) -> bool:
	if slot < 0 or slot >= save_slots.size():
		return false

	var save_data: Dictionary = save_slots[slot]
	if save_data.is_empty():
		save_data = _load_from_file(slot)
		if save_data.is_empty():
			push_error("[SaveManager] No save data in slot %d." % slot)
			return false

	CatchUpSystem.apply_save_data(save_data)

	var scene_path: String = save_data.get("current_scene", "")
	if scene_path != "":
		SceneManager.change_scene(scene_path, "", false)

	load_completed.emit(slot)
	print("[SaveManager] Loaded from slot %d." % slot)
	return true

func _load_from_file(slot: int) -> Dictionary:
	var file: FileAccess = FileAccess.open(SAVE_PATH % slot, FileAccess.READ)
	if file == null:
		return {}

	var json_str: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	if json.parse(json_str) != OK:
		return {}

	save_slots[slot] = json.get_data()
	return save_slots[slot]

func has_save_in_slot(slot: int) -> bool:
	if slot < 0 or slot >= save_slots.size():
		return false
	return not save_slots[slot].is_empty()

func delete_save(slot: int) -> void:
	if slot < 0 or slot >= save_slots.size():
		return
	save_slots[slot] = {}
	var path := SAVE_PATH % slot
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	print("[SaveManager] Save slot %d deleted." % slot)

func get_save_info(slot: int) -> Dictionary:
	var data: Dictionary = save_slots[slot]
	if data.is_empty():
		return {"exists": false}
	var shop_status: String = "open"
	var world_flags_inner: Dictionary = data.get("game_state", {}).get("world_flags", {})
	if not world_flags_inner.get("shop_open", true):
		shop_status = "closed"
	var day: int = data.get("last_played_day", data.get("game_state", {}).get("current_day", 1))
	return {
		"exists": true,
		"timestamp": data.get("timestamp", "?"),
		"day": day,
		"scene": data.get("current_scene", "?"),
		"shop_status": shop_status,
	}
