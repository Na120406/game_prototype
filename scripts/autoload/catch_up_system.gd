extends Node

const _save_data_version: int = 3

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
			"max_health": GameState.max_health,
			"health": GameState.health,
			"gold": GameState.gold,
			"inventory": GameState.inventory.duplicate(true),
			"toolbar": GameState.toolbar.duplicate(true),
			"npc_relationships": GameState.npc_relationships.duplicate(true),
			"weather_type": GameState.weather_type,
			"is_day": GameState.is_day,
			"lore_fragments_found": GameState.lore_fragments_found,
			"world_flags": GameState.world_flags.duplicate(true),
			"discovered_areas": GameState.discovered_areas.duplicate(true),
		},
		"farm_cells": _get_farm_cells_data(),
		"npc_runtime": _get_npc_runtime_data(),
	}

func apply_save_data(data: Dictionary) -> void:
	var data_version: int = data.get("version", 1)
	if data_version < _save_data_version:
		_migrate_save_data(data, data_version)

	var saved_state: Dictionary = data.get("game_state", {})
	GameState.player_name = saved_state.get("player_name", GameState.player_name)
	GameState.current_day = maxi(1, int(saved_state.get("current_day", data.get("last_played_day", GameState.current_day))))
	GameState.current_time = fposmod(float(saved_state.get("current_time", GameState.current_time)), 24.0)
	GameState.max_energy = maxf(0.0, float(saved_state.get("max_energy", GameState.max_energy)))
	GameState.energy = clampf(float(saved_state.get("energy", GameState.energy)), 0.0, GameState.max_energy)
	GameState.max_health = maxf(0.0, float(saved_state.get("max_health", GameState.max_health)))
	GameState.health = clampf(float(saved_state.get("health", GameState.health)), 0.0, GameState.max_health)
	GameState.gold = maxi(0, int(saved_state.get("gold", GameState.gold)))
	GameState.inventory = saved_state.get("inventory", GameState.inventory).duplicate(true)
	GameState.toolbar = saved_state.get("toolbar", GameState.toolbar).duplicate(true)
	GameState.npc_relationships = saved_state.get("npc_relationships", GameState.npc_relationships).duplicate(true)
	GameState.farm_cells_data = data.get("farm_cells", {}).duplicate(true)
	GameState.world_flags = saved_state.get("world_flags", data.get("world_flags", {})).duplicate(true)
	GameState.discovered_areas = saved_state.get("discovered_areas", data.get("discovered_areas", [])).duplicate()
	GameState.lore_fragments_found = int(saved_state.get("lore_fragments_found", data.get("lore_fragments", 0)))
	GameState.weather_type = saved_state.get("weather_type", data.get("weather", "clear"))
	GameState.is_day = bool(saved_state.get("is_day", GameState.is_day))
	GameState._ensure_inventory_slots()
	while GameState.toolbar.size() < GameState.TOOLBAR_SIZE:
		GameState.toolbar.append({"id": "", "amount": 0})
	if GameState.toolbar.size() > GameState.TOOLBAR_SIZE:
		GameState.toolbar.resize(GameState.TOOLBAR_SIZE)
	GameState.inventory_changed.emit()
	GameState.toolbar_changed.emit()
	GameState.energy_changed.emit(GameState.energy)
	FamilyRegistry.load_families(data.get("family_data", {}))
	WeatherSystem.force_weather(data.get("weather", GameState.weather_type))
	WeatherSystem.current_season = data.get("season", "spring")
	_apply_farm_cells_data(data.get("farm_cells", {}))
	var npc_runtime: Variant = data.get("npc_runtime", {})
	if npc_runtime is Dictionary:
		var npc_manager: Node = get_node_or_null("/root/NPCManager")
		if npc_manager != null and npc_manager.has_method("import_runtime_state"):
			npc_manager.call("import_runtime_state", npc_runtime)

func _get_npc_runtime_data() -> Dictionary:
	var npc_manager: Node = get_node_or_null("/root/NPCManager")
	if npc_manager != null and npc_manager.has_method("export_runtime_state"):
		return npc_manager.call("export_runtime_state")
	return {}

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
