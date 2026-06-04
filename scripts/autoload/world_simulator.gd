extends Node

signal world_state_updated(flags: Dictionary)

var simulation_day_count: int = 0
var _simulation_log: Array[Dictionary] = []

func _ready() -> void:
	_connect_world_signals()
	print("[WorldSimulator] Ready — world ticks only while game is running.")

func _connect_world_signals() -> void:
	TimeManager.day_changed.connect(_on_day_changed)

func _on_day_changed(new_day: int) -> void:
	_simulate_day(new_day)

func _simulate_day(day: int) -> void:
	simulation_day_count += 1
	var triggered_events: Array[Dictionary] = []

	var weather_result: Dictionary = WeatherSystem.simulate_day(day)
	triggered_events.append({"type": "weather", "data": weather_result})

	var scheduled_npc_events: Array[Dictionary] = _evaluate_npc_schedules(day)
	for ev: Dictionary in scheduled_npc_events:
		triggered_events.append(ev)

	var world_events: Array[Dictionary] = _evaluate_world_events(day)
	for ev: Dictionary in world_events:
		triggered_events.append(ev)

	var chain_updates: Array[Dictionary] = _update_active_chains()
	for ev: Dictionary in chain_updates:
		triggered_events.append(ev)

	_simulation_log.append({
		"day": day,
		"weather": weather_result.get("weather", "clear"),
		"events": triggered_events,
	})

	world_state_updated.emit(_summarize_flags())
	print("[WorldSimulator] Day %d — %d events." % [day, triggered_events.size()])

func _evaluate_npc_schedules(day: int) -> Array[Dictionary]:
	var triggered: Array[Dictionary] = []

	var families: Array = FamilyRegistry.get_all_families()
	for family_id_raw: Variant in families:
		var family_id: String = family_id_raw
		var members: Array = FamilyRegistry.get_family_members(family_id)
		for member_raw: Variant in members:
			var member: Dictionary = member_raw
			if not member.get("alive", true):
				continue

			var npc_id: String = member.get("id", "")
			var schedules: Array = NPCSchedules.get_schedules(npc_id)
			if schedules.is_empty():
				continue

			for schedule_raw: Variant in schedules:
				var schedule: Dictionary = schedule_raw
				if schedule.get("day_of_week", -1) == (day - 1) % 7:
					if schedule.get("type", "") == "mountain":
						var player_escorted: bool = _check_player_escort(npc_id, day)
						var context: Dictionary = {
							"npc_id": npc_id,
							"family_id": family_id,
							"day": day,
							"player_escorted": player_escorted,
						}
						var risk: float = RiskCalculator.calculate_risk(npc_id, "mountain_trip", context)
						print("[WorldSimulator] NPC '%s' scheduled mountain trip. Risk: %.0f%%" % [npc_id, risk * 100.0])
						triggered.append({
							"type": "npc_scheduled",
							"npc_id": npc_id,
							"family_id": family_id,
							"schedule_type": "mountain",
							"risk": risk,
							"context": context,
						})

						if risk >= 0.3:
							EventChainEngine.trigger_chain("shopkeeper_mountain", context)

	return triggered

func _check_player_escort(npc_id: String, day: int) -> bool:
	return GameState.get_flag("quest_escorted_%s_day_%d" % [npc_id, day])

func _evaluate_world_events(day: int) -> Array[Dictionary]:
	var triggered: Array[Dictionary] = []

	if day % 7 == 0 and day > 1:
		triggered.append({"type": "festival", "day": day})
		EventChainEngine.trigger_chain("festival_day", {"day": day})

	if day % 30 == 0 and day > 30:
		triggered.append({"type": "season_transition", "day": day})
		WeatherSystem.advance_season()
		EventChainEngine.trigger_chain("harvest_blight", {"day": day, "season": WeatherSystem.current_season})

	return triggered

func _update_active_chains() -> Array[Dictionary]:
	var updates: Array[Dictionary] = []
	var chain_ids: Array = EventChainEngine.get_all_active_chains()
	for chain_id_raw: Variant in chain_ids:
		var chain_id: String = chain_id_raw
		updates.append({
			"type": "chain_update",
			"chain_id": chain_id,
			"day": GameState.current_day,
		})
	return updates

func _summarize_flags() -> Dictionary:
	return {
		"shop_open": GameState.get_flag("shop_open", true),
		"new_shopkeeper": GameState.get_flag("new_shopkeeper", false),
		"food_shortage": GameState.get_flag("food_shortage", false),
		"strange_events": GameState.get_flag("strange_events_active", false),
		"anomaly_weather": WeatherSystem.anomaly_weather_active,
	}

func get_simulation_log() -> Array:
	return _simulation_log.duplicate()

func clear_simulation_log() -> void:
	_simulation_log.clear()

func get_events_for_day(day: int) -> Array[Dictionary]:
	for entry_raw: Variant in _simulation_log:
		var entry: Dictionary = entry_raw
		if entry.get("day", 0) == day:
			return entry.get("events", [])
	return []

func force_trigger_event(event_id: String, context: Dictionary = {}) -> void:
	match event_id:
		"shopkeeper_mountain":
			EventChainEngine.trigger_chain("shopkeeper_mountain", context)
		"festival":
			EventChainEngine.trigger_chain("festival_day", context)
		"harvest_blight":
			EventChainEngine.trigger_chain("harvest_blight", context)
