extends Node
# =============================================================================
# CONFIG MANAGER - Load game configuration from JSON files
# =============================================================================
# Chức năng: Load và parse các file JSON config để đọc thông số game
# thay vì hardcode trong code.
#
# Cách sử dụng:
#   ConfigManager.get_game_config()  - lấy game config
#   ConfigManager.get_npc_config()   - lấy NPC config
#   ConfigManager.get_value("game.player.move_speed") - lấy giá trị cụ thể
# =============================================================================

const CONFIG_PATH := "res://resources/config/"

var _game_config: Dictionary = {}
var _npc_config: Dictionary = {}
var _npc_schedule_config: Dictionary = {}
var _ui_text_config: Dictionary = {}
var _quest_text_config: Dictionary = {}
var _money_config: Dictionary = {}
var _localization: Dictionary = {}
var _loaded: bool = false
const LOCALIZATION_PATH := "res://resources/localization/vi.json"

func _ready() -> void:
	load_all_configs()
	print("[ConfigManager] Loaded all configs.")

func load_all_configs() -> void:
	load_game_config()
	load_npc_config()
	load_npc_schedule_config()
	load_ui_text_config()
	load_quest_text_config()
	load_money_config()
	load_localization()
	_loaded = true

func load_localization() -> bool:
	var result := _load_json(LOCALIZATION_PATH)
	if result.is_empty():
		push_error("[ConfigManager] Failed to load Vietnamese localization")
		return false
	_localization = result.get("strings", {})
	return true

func translate_text(key: String, default: String = "") -> String:
	return str(_localization.get(key, default))

func get_localization() -> Dictionary:
	return _localization.duplicate()

func load_game_config() -> bool:
	var path := CONFIG_PATH + "game_config.json"
	var result := _load_json(path)
	if result.size() > 0:
		_game_config = result
		print("[ConfigManager] Loaded game_config.json")
		return true
	push_error("[ConfigManager] Failed to load game_config.json")
	return false

func load_npc_schedule_config() -> bool:
	var result := _load_json(CONFIG_PATH + "npc_schedule_config.json")
	if result.is_empty():
		push_warning("[ConfigManager] NPC schedule config not found; using script schedules")
		return false
	_npc_schedule_config = result
	print("[ConfigManager] Loaded npc_schedule_config.json")
	return true

func load_npc_config() -> bool:
	var path := CONFIG_PATH + "npc_config.json"
	var result := _load_json(path)
	if result.size() > 0:
		_npc_config = result
		print("[ConfigManager] Loaded npc_config.json")
		return true
	push_error("[ConfigManager] Failed to load npc_config.json")
	return false

func load_ui_text_config() -> bool:
	var path := CONFIG_PATH + "ui_text_config.json"
	var result := _load_json(path)
	if result.size() > 0:
		_ui_text_config = result
		print("[ConfigManager] Loaded ui_text_config.json")
		return true
	push_error("[ConfigManager] Failed to load ui_text_config.json")
	return false

func load_money_config() -> bool:
	var result := _load_json(CONFIG_PATH + "money_config.json")
	if result.size() > 0:
		_money_config = result
		print("[ConfigManager] Loaded money_config.json")
		return true
	push_error("[ConfigManager] Failed to load money_config.json")
	return false

func load_quest_text_config() -> bool:
	var path := CONFIG_PATH + "quest_text_config.json"
	var result := _load_json(path)
	if result.size() > 0:
		_quest_text_config = result
		print("[ConfigManager] Loaded quest_text_config.json")
		return true
	push_error("[ConfigManager] Failed to load quest_text_config.json")
	return false

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("[ConfigManager] File not found: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[ConfigManager] Cannot open file: %s" % path)
		return {}
	var json_string := file.get_as_text()
	file.close()
	var json := JSON.new()
	var parse_result := json.parse(json_string)
	if parse_result != OK:
		push_error("[ConfigManager] JSON parse error in %s: %s" % [path, json.get_error_message()])
		return {}
	var data: Variant = json.get_data()
	if data is Dictionary:
		return data as Dictionary
	push_error("[ConfigManager] Root must be Dictionary in %s" % path)
	return {}

# =============================================================================
# GETTERS
# =============================================================================

func get_game_config() -> Dictionary:
	return _game_config.duplicate()

func get_npc_config() -> Dictionary:
	return _npc_config.duplicate()

# Lấy giá trị đệ quy bằng dot notation
# Ví dụ: get_value("game.player.move_speed")
func get_value(path: String, default: Variant = null) -> Variant:
	var keys: Array = path.split(".")
	var current: Variant = null
	
	# Xác định root config
	if keys[0] == "game":
		current = _game_config
	elif keys[0] == "npc":
		current = _npc_config
	elif keys[0] == "money":
		current = _money_config.get("money", {})
	elif keys[0] == "money_config":
		current = _money_config
	else:
		push_warning("[ConfigManager] Unknown root in path: %s" % path)
		return default
	
	# Duyệt qua các keys
	for i in range(1, keys.size()):
		var key: String = keys[i]
		if current is Dictionary:
			if current.has(key):
				current = current[key]
			else:
				return default
		else:
			return default
	
	return current

# =============================================================================
# GAME CONFIG HELPERS
# =============================================================================

func get_start_day() -> int:
	return int(get_value("game.start_day", 1))

func get_start_time() -> float:
	return float(get_value("game.start_time", 6.0))

func get_max_energy() -> float:
	return float(get_value("game.max_energy", 20.0))

func get_max_health() -> float:
	return float(get_value("game.max_health", 100.0))

func get_sleep_deadline_hour() -> float:
	return float(get_value("game.sleep_deadline_hour", 24.0))

func get_sleep_warning_hour() -> float:
	return float(get_value("game.sleep_warning_hour", 22.0))

func get_base_quest_chance() -> float:
	return float(get_value("quest.base_quest_chance", 0.5))

func get_quest_bonus_per_day() -> float:
	return float(get_value("quest.bonus_per_day_no_quest", 0.1))

func get_inventory_slots() -> int:
	return int(get_value("inventory.slots", 21))

func get_toolbar_size() -> int:
	return int(get_value("inventory.toolbar_size", 5))

func get_scene_transition_duration() -> float:
	return float(get_value("scene.transition_duration", 0.5))

func get_player_move_speed() -> float:
	return float(get_value("player.move_speed", 100.0))

func get_player_run_speed() -> float:
	return float(get_value("player.run_speed", 180.0))

func get_player_sprint_speed() -> float:
	return float(get_value("player.sprint_speed", 250.0))

func get_player_acceleration() -> float:
	return float(get_value("player.acceleration", 800.0))

func get_player_friction() -> float:
	return float(get_value("player.friction", 1200.0))

func get_player_interaction_range() -> float:
	return float(get_value("player.interaction_range", 80.0))

func get_cinematic_delay() -> float:
	return float(get_value("cinematic_intro.delay_before_walk_seconds", 1.5))

func get_cinematic_player_offset() -> Vector2:
	var x := float(get_value("cinematic_intro.player_offset_from_npc.x", -50))
	var y := float(get_value("cinematic_intro.player_offset_from_npc.y", 0))
	return Vector2(x, y)

# =============================================================================
# NPC CONFIG HELPERS
# =============================================================================

func get_scene_path(scene_key: String) -> String:
	return str(get_value("scenes." + scene_key, ""))

func get_npc_entry(npc_id: String) -> Dictionary:
	return get_value("npc.npcs." + npc_id, {})

func get_npc_dialogue_path(dialogue_key: String) -> String:
	return str(get_value("dialogues." + dialogue_key, ""))

func get_npc_schedule_legacy(npc_id: String, schedule_name: String) -> Array:
	return get_value("npc.npcs." + npc_id + ".schedule_" + schedule_name, [])

func get_npc_daily_schedule(npc_id: String, schedule_name: String = "daily_from_house") -> Array:
	var schedules: Variant = _npc_schedule_config.get("schedules", {})
	if schedules is Dictionary and schedules.has(npc_id):
		var npc_schedules: Variant = schedules[npc_id]
		if npc_schedules is Dictionary and npc_schedules.has(schedule_name):
			var target_schedule: Variant = npc_schedules[schedule_name]
			if target_schedule is Array:
				return target_schedule.duplicate(true)
	return []

func get_npc_position(npc_id: String, position_key: String) -> Vector2:
	var pos_dict: Dictionary = get_value("npc.npcs." + npc_id + "." + position_key, {})
	if pos_dict.is_empty():
		return Vector2.ZERO
	return Vector2(
		float(pos_dict.get("x", 0)),
		float(pos_dict.get("y", 0))
	)

func get_intro_deadline_hour() -> float:
	return float(get_value("npc.npcs.neighbor.intro_deadline_hour", 11.0))

# =============================================================================
# UI TEXT CONFIG HELPERS
# =============================================================================

func get_ui_text(path: String, default: String = "") -> String:
	var value: Variant = _get_nested_value(_ui_text_config, path)
	if value is String:
		return value
	return default

func get_ui_text_value(path: String, default: Variant = null) -> Variant:
	return _get_nested_value(_ui_text_config, path, default)

func _get_nested_value(dict: Dictionary, dot_path: String, default: Variant = null) -> Variant:
	var keys: Array = dot_path.split(".")
	var current: Variant = dict
	for key in keys:
		if current is Dictionary and current.has(key):
			current = current[key]
		else:
			return default
	return current

# =============================================================================
# QUEST TEXT CONFIG HELPERS
# =============================================================================

func get_quest_text(path: String, default: String = "") -> String:
	var value: Variant = _get_nested_value(_quest_text_config, path)
	if value is String:
		return value
	return default

func get_quest_text_value(path: String, default: Variant = null) -> Variant:
	return _get_nested_value(_quest_text_config, path, default)

func get_ui_text_config() -> Dictionary:
	return _ui_text_config.duplicate()

func get_quest_text_config() -> Dictionary:
	return _quest_text_config.duplicate()
