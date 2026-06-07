extends Node

const _save_data_version: int = 1

func _ready() -> void:
	print("[CatchUpSystem] Ready — passive metadata storage only.")

func prepare_save_data() -> Dictionary:
	var player_pos: Dictionary = {"x": 0.0, "y": 0.0}
	if get_tree().has_group("player"):
		var player: Node = get_tree().get_first_node_in_group("player")
		if player != null:
			var pos: Vector2 = player.global_position
			player_pos = {"x": pos.x, "y": pos.y}

	var scene: String = ""
	var current: Node = get_tree().current_scene
	if current != null:
		scene = current.scene_file_path

	return {
		"version": _save_data_version,
		"timestamp": Time.get_datetime_string_from_system(),
		"last_played_day": GameState.current_day,
		"world_flags": GameState.world_flags.duplicate(true),
		"family_data": FamilyRegistry.serialize_families(),
		"weather": WeatherSystem.get_today_weather(),
		"season": WeatherSystem.current_season,
		"discovered_areas": GameState.discovered_areas.duplicate(true),
		"lore_fragments": GameState.lore_fragments_found,
		"current_scene": scene,
		"player_position": player_pos,
		"game_state": {
			"player_name": GameState.player_name,
			"current_day": GameState.current_day,
			"current_time": GameState.current_time,
			"energy": GameState.energy,
			"max_energy": GameState.max_energy,
			"inventory": GameState.inventory.duplicate(true),
			"weather_type": GameState.weather_type,
			"is_day": GameState.is_day,
			"lore_fragments_found": GameState.lore_fragments_found,
			"world_flags": GameState.world_flags.duplicate(true),
			"discovered_areas": GameState.discovered_areas.duplicate(true),
		},
		"farm_cells": _get_farm_cells_data(),
	}

func apply_save_data(data: Dictionary) -> void:
	var data_version: int = data.get("version", 1)
	if data_version < _save_data_version:
		_migrate_save_data(data, data_version)

	GameState.world_flags = data.get("world_flags", {}).duplicate(true)
	GameState.discovered_areas = data.get("discovered_areas", [])
	GameState.lore_fragments_found = data.get("lore_fragments", 0)
	FamilyRegistry.load_families(data.get("family_data", {}))
	WeatherSystem.force_weather(data.get("weather", "clear"))
	WeatherSystem.current_season = data.get("season", "spring")
	_apply_farm_cells_data(data.get("farm_cells", {}))

func _migrate_save_data(_data: Dictionary, _from_version: int) -> void:
	print("[CatchUpSystem] Migrating save data from v%d to v%d" % [_from_version, _save_data_version])

func _get_farm_cells_data() -> Dictionary:
	var farm: Node = get_tree().get_first_node_in_group("farm_manager")
	if farm != null and farm.has_method("serialize"):
		return farm.serialize()
	return {}

func _apply_farm_cells_data(data: Dictionary) -> void:
	var farm: Node = get_tree().get_first_node_in_group("farm_manager")
	if farm != null and farm.has_method("deserialize"):
		farm.deserialize(data)
		print("[CatchUpSystem] Farm cells restored.")
