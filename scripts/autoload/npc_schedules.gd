extends Node

var schedules: Dictionary = {}

func _ready() -> void:
	_build_default_schedules()
	print("[NPCSchedules] Ready — %d schedules loaded." % schedules.size())

func _build_default_schedules() -> void:
	schedules = {
		"shopkeeper_father": [
			{
				"id": "mountain_trip",
				"day_of_week": 5,
				"type": "mountain",
				"departure_time": 7.0,
				"return_time": 18.0,
				"risk_activity": "mountain_trip",
				"description": "Voss climbs the mountain every Saturday.",
				"chain_id": "shopkeeper_mountain",
				"required_quest": "",
			},
		],
		"farmer_mother": [
			{
				"id": "market_day",
				"day_of_week": 2,
				"type": "market",
				"departure_time": 8.0,
				"return_time": 15.0,
				"risk_activity": "river_crossing",
				"description": "Martha goes to the market every Tuesday.",
				"chain_id": "",
				"required_quest": "",
			},
		],
		"hermit": [
			{
				"id": "forest_walk",
				"day_of_week": 3,
				"type": "forest",
				"departure_time": 6.0,
				"return_time": 17.0,
				"risk_activity": "forest_walk",
				"description": "Old Hanz walks into the forest every Wednesday.",
				"chain_id": "",
				"required_quest": "",
			},
		],
		"shopkeeper_son": [
			{
				"id": "night_walk",
				"day_of_week": 4,
				"type": "night",
				"departure_time": 21.0,
				"return_time": 23.0,
				"risk_activity": "night_walk",
				"description": "Young Voss wanders at night.",
				"chain_id": "",
				"required_quest": "",
			},
		],
	}

func get_schedules(npc_id: String) -> Array:
	var raw: Array = schedules.get(npc_id, [])
	return raw

func get_todays_schedule(npc_id: String) -> Array:
	var all_schedules: Array = get_schedules(npc_id)
	var current_day_of_week: int = (GameState.current_day - 1) % 7
	var current_time: float = GameState.current_time

	var todays: Array = []
	for schedule: Dictionary in all_schedules:
		var day_of_week: int = schedule.get("day_of_week", -1)
		var departure_time: float = schedule.get("departure_time", 0.0)
		if day_of_week == current_day_of_week and departure_time > current_time:
			todays.append(schedule)

	return todays

func has_upcoming_schedule(npc_id: String, within_hours: float = 24.0) -> bool:
	return not get_todays_schedule(npc_id).is_empty()

func add_schedule(npc_id: String, schedule: Dictionary) -> void:
	if not schedules.has(npc_id):
		schedules[npc_id] = []
	var existing: Array = schedules[npc_id]
	existing.append(schedule)
	schedules[npc_id] = existing

func remove_schedule(npc_id: String, schedule_id: String) -> void:
	if schedules.has(npc_id):
		var npc_schedules: Array = schedules[npc_id]
		for i: int in range(npc_schedules.size()):
			var sched_id: String = npc_schedules[i].get("id", "")
			if sched_id == schedule_id:
				npc_schedules.remove_at(i)
				return

func get_schedule_description(npc_id: String) -> String:
	var descs: Array = []
	for schedule: Dictionary in get_schedules(npc_id):
		descs.append(schedule.get("description", ""))
	return "\n".join(descs)

func get_all_schedules_for_day(day_of_week: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for npc_id: String in schedules:
		var npc_schedules: Array = schedules[npc_id]
		for schedule: Dictionary in npc_schedules:
			if schedule.get("day_of_week", -1) == day_of_week:
				result.append({
					"npc_id": npc_id,
					"schedule": schedule,
				})
	return result
