extends Node

const SAVE_PATH := "user://save_game.dat"

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

	var save_data := {
		"version": "1.0",
		"timestamp": Time.get_datetime_string_from_system(),
		"game_state": _capture_game_state(),
		"current_scene": SceneManager.current_scene_path,
		"player_position": _capture_player_position(),
	}

	save_slots[slot] = save_data

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[SaveManager] Cannot open save file for writing.")
		return false

	var json_str := JSON.stringify(save_data, "\t")
	file.store_line(json_str)
	file.close()

	save_completed.emit(slot)
	print("[SaveManager] Saved to slot %d." % slot)
	return true

func load_game(slot: int = 0) -> bool:
	if slot < 0 or slot >= save_slots.size():
		return false

	var save_data := save_slots[slot]
	if save_data.is_empty():
		save_data = _load_from_file(slot)
		if save_data.is_empty():
			push_error("[SaveManager] No save data in slot %d." % slot)
			return false

	_restore_game_state(save_data.get("game_state", {}))

	var scene_path: String = save_data.get("current_scene", "")
	if scene_path != "":
		SceneManager.change_scene(scene_path, false)

	load_completed.emit(slot)
	print("[SaveManager] Loaded from slot %d." % slot)
	return true

func _load_from_file(slot: int) -> Dictionary:
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}

	var json_str := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(json_str) != OK:
		return {}

	save_slots[slot] = json.get_data()
	return save_slots[slot]

func _capture_game_state() -> Dictionary:
	return {
		"player_name": GameState.player_name,
		"current_day": GameState.current_day,
		"current_time": GameState.current_time,
		"energy": GameState.energy,
		"max_energy": GameState.max_energy,
		"inventory": GameState.inventory,
		"world_flags": GameState.world_flags,
		"discovered_areas": GameState.discovered_areas,
		"lore_fragments_found": GameState.lore_fragments_found,
		"weather_type": GameState.weather_type,
		"is_day": GameState.is_day,
	}

func _restore_game_state(state: Dictionary) -> void:
	GameState.player_name = state.get("player_name", "Player")
	GameState.current_day = state.get("current_day", 1)
	GameState.current_time = state.get("current_time", 6.0)
	GameState.energy = state.get("energy", 100.0)
	GameState.max_energy = state.get("max_energy", 100.0)
	GameState.inventory = state.get("inventory", [])
	GameState.world_flags = state.get("world_flags", {})
	GameState.discovered_areas = state.get("discovered_areas", [])
	GameState.lore_fragments_found = state.get("lore_fragments_found", 0)
	GameState.weather_type = state.get("weather_type", "clear")
	GameState.is_day = state.get("is_day", true)

func _capture_player_position() -> Dictionary:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return {"x": 0, "y": 0}
	return {"x": player.global_position.x, "y": player.global_position.y}

func has_save_in_slot(slot: int) -> bool:
	if slot < 0 or slot >= save_slots.size():
		return false
	return not save_slots[slot].is_empty()

func delete_save(slot: int) -> void:
	if slot < 0 or slot >= save_slots.size():
		return
	save_slots[slot] = {}
	print("[SaveManager] Save slot %d deleted." % slot)

func get_save_info(slot: int) -> Dictionary:
	var data: Dictionary = save_slots[slot]
	if data.is_empty():
		return {"exists": false}
	return {
		"exists": true,
		"version": data.get("version", "?"),
		"timestamp": data.get("timestamp", "?"),
		"day": data.get("game_state", {}).get("current_day", 1),
		"scene": data.get("current_scene", "?"),
	}
