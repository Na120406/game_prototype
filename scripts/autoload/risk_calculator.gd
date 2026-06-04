extends Node

const BASE_RISK: Dictionary = {
	"mountain_trip": 0.20,
	"forest_walk": 0.10,
	"river_crossing": 0.15,
	"night_walk": 0.25,
	"work_field": 0.05,
}

const WEATHER_MODIFIER: Dictionary = {
	"clear": 0.0,
	"overcast": 0.05,
	"fog": 0.10,
	"drizzle": 0.08,
	"rain": 0.15,
	"storm": 0.35,
	"heavy_rain": 0.45,
	"mist": 0.12,
}

const TIME_MODIFIER: Dictionary = {
	"morning": 0.0,
	"noon": 0.0,
	"afternoon": 0.02,
	"evening": 0.10,
	"night": 0.20,
}

const PERSONALITY_MODIFIER: Dictionary = {
	"cautious": -0.10,
	"normal": 0.0,
	"reckless": 0.15,
	"old": 0.10,
	"young": 0.05,
}

func _ready() -> void:
	print("[RiskCalculator] Ready.")

func calculate_risk(npc_id: String, activity: String, context: Dictionary = {}) -> float:
	var base: float = BASE_RISK.get(activity, 0.15)

	var weather_mod: float = _get_weather_modifier(context)
	var time_mod: float = _get_time_modifier(context)
	var personality_mod: float = _get_personality_modifier(npc_id, context)
	var escort_mod: float = _get_escort_modifier(context)
	var season_mod: float = _get_season_modifier()

	var total: float = base + weather_mod + time_mod + personality_mod + escort_mod + season_mod
	total = clampf(total, 0.0, 1.0)

	return total

func _get_weather_modifier(context: Dictionary) -> float:
	var weather: String = context.get("weather", WeatherSystem.get_today_weather())
	return WEATHER_MODIFIER.get(weather, 0.0)

func _get_time_modifier(context: Dictionary) -> float:
	var time: float = context.get("time", GameState.current_time)
	var hour: int = int(time)
	if hour >= 6 and hour < 12:
		return TIME_MODIFIER["morning"]
	elif hour >= 12 and hour < 14:
		return TIME_MODIFIER["noon"]
	elif hour >= 14 and hour < 18:
		return TIME_MODIFIER["afternoon"]
	elif hour >= 18 and hour < 21:
		return TIME_MODIFIER["evening"]
	return TIME_MODIFIER["night"]

func _get_personality_modifier(npc_id: String, context: Dictionary) -> float:
	var personality: String = context.get("personality", "normal")
	return PERSONALITY_MODIFIER.get(personality, 0.0)

func _get_escort_modifier(context: Dictionary) -> float:
	if context.get("player_escorted", false):
		return -0.20
	if context.get("has_escort", false):
		return -0.10
	return 0.0

func _get_season_modifier() -> float:
	match WeatherSystem.current_season:
		"winter": return 0.15
		"autumn": return 0.08
		"summer": return -0.02
		"spring": return 0.0
	return 0.0

func get_outcome_rolls(risk: float) -> Dictionary:
	var roll: float = randf()

	if roll < risk * 0.4:
		return {"outcome": "dead", "roll": roll, "description": "Worst outcome."}
	elif roll < risk * 0.8:
		return {"outcome": "injured", "roll": roll, "description": "Something went wrong."}
	elif roll < risk:
		return {"outcome": "delayed", "roll": roll, "description": "Minor complication."}
	else:
		return {"outcome": "safe", "roll": roll, "description": "No incident."}

func get_activity_risk_description(activity: String) -> String:
	match activity:
		"mountain_trip": return "Mountain paths become dangerous in bad weather."
		"forest_walk": return "The forest has uneven terrain."
		"river_crossing": return "Water levels rise quickly."
		"night_walk": return "Darkness hides many dangers."
		"work_field": return "Physical labor has its hazards."
	return "An ordinary activity."
