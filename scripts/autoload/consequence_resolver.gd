extends Node

var scene_overrides: Dictionary = {}
var scheduled_flag_changes: Array[Dictionary] = []
var scheduled_family_successions: Dictionary = {}
var dialogue_replacements: Dictionary = {}
var npc_replacements: Dictionary = {}

var consequence_log: Array[Dictionary] = []

func _ready() -> void:
	print("[ConsequenceResolver] Ready — consequence system active.")

func _process(_delta: float) -> void:
	_process_scheduled_changes()

func _process_scheduled_changes() -> void:
	var to_remove_flags: Array[int] = []
	for i: int in range(scheduled_flag_changes.size()):
		var item: Dictionary = scheduled_flag_changes[i]
		item["remaining"] -= 1
		if item["remaining"] <= 0:
			_apply_flag_change(item)
			to_remove_flags.append(i)

	for i: int in range(to_remove_flags.size() - 1, -1, -1):
		scheduled_flag_changes.remove_at(to_remove_flags[i])

	var to_remove_succ: Array[String] = []
	for family_id: String in scheduled_family_successions:
		var item: Dictionary = scheduled_family_successions[family_id]
		item["remaining"] -= 1
		if item["remaining"] <= 0:
			_apply_family_succession(family_id, item)
			to_remove_succ.append(family_id)

	for fid: String in to_remove_succ:
		scheduled_family_successions.erase(fid)

func _apply_flag_change(item: Dictionary) -> void:
	var flag: String = item.get("flag", "")
	var value: Variant = item.get("value", true)
	var flag_key: String = "flag_%s" % flag

	match item.get("type", ""):
		"shop_reopen":
			GameState.set_flag("shop_open", value)
			GameState.set_flag("shop_closed_days", -1)
		_:
			GameState.set_flag(flag, value)

	var scheduled_day: int = item.get("scheduled_day", -1)
	_log_consequence("flag_change", {"flag": flag, "value": value, "scheduled_day": scheduled_day})
	print("[ConsequenceResolver] Flag '%s' set to %s" % [flag, str(value)])

func _apply_family_succession(family_id: String, item: Dictionary) -> void:
	var old_member_id: String = item.get("old_member_id", "")
	var new_member_id: String = item.get("new_member_id", "")

	FamilyRegistry.replace_family_member(family_id, old_member_id, new_member_id)
	_register_npc_replacement(old_member_id, new_member_id)

	_log_consequence("family_succession", {
		"family_id": family_id,
		"old_member": old_member_id,
		"new_member": new_member_id,
	})
	print("[ConsequenceResolver] Family '%s' succession: %s → %s" % [family_id, old_member_id, new_member_id])

func schedule_flag_change(flag: String, value: Variant, days_from_now: int) -> void:
	scheduled_flag_changes.append({
		"type": flag,
		"flag": flag,
		"value": value,
		"remaining": days_from_now,
		"scheduled_day": GameState.current_day + days_from_now,
	})

func apply_scene_change(scene_path: String, method: String, param: Variant) -> void:
	if not scene_overrides.has(scene_path):
		scene_overrides[scene_path] = {}
	scene_overrides[scene_path][method] = param

	var current_scene: Node = SceneManager.get_current_scene()
	if current_scene != null and current_scene.scene_file_path == scene_path:
		if current_scene.has_method(method):
			current_scene.call(method, param)

func schedule_scene_change(scene_path: String, method: String, param: Variant, days_from_now: int) -> void:
	scheduled_flag_changes.append({
		"type": "scene_change",
		"scene_path": scene_path,
		"method": method,
		"param": param,
		"remaining": days_from_now,
		"scheduled_day": GameState.current_day + days_from_now,
	})

func _register_npc_replacement(old_npc_id: String, new_npc_id: String) -> void:
	npc_replacements[old_npc_id] = new_npc_id

func register_dialogue_replacement(old_dialogue: String, new_dialogue: String, condition_flag: String) -> void:
	dialogue_replacements[condition_flag] = {
		"old": old_dialogue,
		"new": new_dialogue,
	}

func resolve_dialogue(dialogue_id: String) -> String:
	for condition_flag: String in dialogue_replacements:
		if GameState.get_flag(condition_flag):
			var replacement: Dictionary = dialogue_replacements[condition_flag]
			return replacement.get("new", dialogue_id)
	return dialogue_id

func get_active_scene_override(scene_path: String, method: String) -> Variant:
	if scene_overrides.has(scene_path):
		return scene_overrides[scene_path].get(method, null)
	return null

func schedule_family_succession(family_id: String, new_member_id: String, days_from_now: int, old_member_id: String = "") -> void:
	var current_head: String = FamilyRegistry.get_current_family_head(family_id)
	scheduled_family_successions[family_id] = {
		"old_member_id": old_member_id if old_member_id != "" else current_head,
		"new_member_id": new_member_id,
		"remaining": days_from_now,
	}

func schedule_event(event_name: String, days_from_now: int) -> void:
	scheduled_flag_changes.append({
		"type": "event",
		"event": event_name,
		"remaining": days_from_now,
		"scheduled_day": GameState.current_day + days_from_now,
	})
	print("[ConsequenceResolver] Event '%s' scheduled for day %d" % [event_name, GameState.current_day + days_from_now])

func apply_consequence_set(consequences: Array[String], chain_id: String, context: Dictionary) -> void:
	for consequence_id: String in consequences:
		match consequence_id:
			"shop_closed":
				apply_scene_change("res://scenes/world/shop.tscn", "set_shop_state", "closed")
				GameState.set_flag("shop_open", false)
			"shop_reopen":
				schedule_flag_change("shop_open", true, 5)
			"npc_flees":
				var npc_id: String = context.get("npc_id", "")
				var family_id: String = context.get("family_id", "")
				FamilyRegistry.mark_family_member_dead(npc_id, family_id)

	_log_consequence("consequence_set", {"chain_id": chain_id, "consequences": consequences, "context": context})

func get_npc_replacement(npc_id: String) -> String:
	return npc_replacements.get(npc_id, npc_id)

func get_consequence_log() -> Array:
	return consequence_log.duplicate()

func _log_consequence(consequence_type: String, data: Dictionary) -> void:
	consequence_log.append({
		"type": consequence_type,
		"data": data,
		"day": GameState.current_day,
		"time": GameState.current_time,
	})

func clear_overrides() -> void:
	scene_overrides.clear()
	dialogue_replacements.clear()
	npc_replacements.clear()
	print("[ConsequenceResolver] All overrides cleared.")

func apply_world_state_summary(summary: Dictionary) -> void:
	var flags: Dictionary = summary.get("final_flags", {})
	for flag_key: String in flags:
		GameState.set_flag(flag_key, flags[flag_key])
	weather_overrides_applied(summary)

func weather_overrides_applied(summary: Dictionary) -> void:
	var weather: String = summary.get("weather", "clear")
	WeatherSystem.force_weather(weather)

	var season: String = summary.get("season", "spring")
	WeatherSystem.current_season = season
