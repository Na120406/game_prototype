extends Node

signal weather_changed(new_weather: String, intensity: float)
signal forecast_updated(forecast: Array)
signal season_changed(new_season: String)
signal anomaly_weather_triggered(weather_type: String)

enum Weather {
	CLEAR,
	OVERCAST,
	FOG,
	DRIZZLE,
	RAIN,
	STORM,
	HEAVY_RAIN,
	MIST,
}

const WEATHER_NAMES := {
	Weather.CLEAR: "clear",
	Weather.OVERCAST: "overcast",
	Weather.FOG: "fog",
	Weather.DRIZZLE: "drizzle",
	Weather.RAIN: "rain",
	Weather.STORM: "storm",
	Weather.HEAVY_RAIN: "heavy_rain",
	Weather.MIST: "mist",
}

const WEATHER_RISK := {
	"clear": 0.0,
	"overcast": 0.05,
	"fog": 0.1,
	"drizzle": 0.15,
	"rain": 0.25,
	"storm": 0.45,
	"heavy_rain": 0.6,
	"mist": 0.2,
}

var current_weather: String = "clear"
var weather_intensity: float = 0.0
var weather_duration_hours: float = 8.0
var weather_timer: float = 0.0
var forecast: Array[Dictionary] = []

var current_season: String = "spring"
var season_day_counter: int = 1
var season_lengths := {
	"spring": 30,
	"summer": 30,
	"autumn": 30,
	"winter": 30,
}

var anomaly_weather_active: bool = false
var anomaly_weather_count: int = 0

func _ready() -> void:
	_generate_forecast()
	_roll_daily_weather()
	print("[WeatherSystem] Ready. Season: %s, Weather: %s" % [current_season, current_weather])

func _process(delta: float) -> void:
	weather_timer += delta
	var time_scale: float = TimeManager.time_scale
	var hours_elapsed: float = weather_timer * time_scale
	if hours_elapsed >= weather_duration_hours:
		_roll_daily_weather()
		weather_timer = 0.0

func _roll_daily_weather() -> void:
	var roll: float = randf()
	var weather_type: Weather
	var intensity: float

	if anomaly_weather_active:
		weather_type = Weather.STORM
		intensity = 0.8
		anomaly_weather_count += 1
		if anomaly_weather_count >= 3:
			anomaly_weather_active = false
			anomaly_weather_count = 0
	elif current_season == "winter":
		if roll < 0.25: weather_type = Weather.CLEAR
		elif roll < 0.45: weather_type = Weather.OVERCAST
		elif roll < 0.65: weather_type = Weather.FOG
		elif roll < 0.8: weather_type = Weather.MIST
		elif roll < 0.92: weather_type = Weather.DRIZZLE
		else: weather_type = Weather.HEAVY_RAIN
	elif current_season == "autumn":
		if roll < 0.25: weather_type = Weather.CLEAR
		elif roll < 0.4: weather_type = Weather.OVERCAST
		elif roll < 0.55: weather_type = Weather.FOG
		elif roll < 0.7: weather_type = Weather.DRIZZLE
		elif roll < 0.85: weather_type = Weather.RAIN
		else: weather_type = Weather.STORM
	elif current_season == "summer":
		if roll < 0.45: weather_type = Weather.CLEAR
		elif roll < 0.6: weather_type = Weather.OVERCAST
		elif roll < 0.72: weather_type = Weather.FOG
		elif roll < 0.85: weather_type = Weather.DRIZZLE
		elif roll < 0.95: weather_type = Weather.RAIN
		else: weather_type = Weather.STORM
	else:
		if roll < 0.35: weather_type = Weather.CLEAR
		elif roll < 0.5: weather_type = Weather.OVERCAST
		elif roll < 0.65: weather_type = Weather.FOG
		elif roll < 0.78: weather_type = Weather.DRIZZLE
		elif roll < 0.9: weather_type = Weather.RAIN
		else: weather_type = Weather.STORM

	current_weather = WEATHER_NAMES[weather_type]
	intensity = _roll_intensity(weather_type)
	weather_intensity = intensity
	weather_duration_hours = _roll_duration(weather_type)

	GameState.weather_type = current_weather
	weather_changed.emit(current_weather, intensity)

func _roll_intensity(wtype: Weather) -> float:
	match wtype:
		Weather.CLEAR: return randf_range(0.0, 0.1)
		Weather.OVERCAST: return randf_range(0.1, 0.3)
		Weather.FOG: return randf_range(0.3, 0.5)
		Weather.DRIZZLE: return randf_range(0.2, 0.4)
		Weather.RAIN: return randf_range(0.4, 0.65)
		Weather.STORM: return randf_range(0.6, 0.8)
		Weather.HEAVY_RAIN: return randf_range(0.7, 1.0)
		Weather.MIST: return randf_range(0.25, 0.5)
	return 0.5

func _roll_duration(wtype: Weather) -> float:
	match wtype:
		Weather.CLEAR: return randf_range(6.0, 12.0)
		Weather.STORM: return randf_range(2.0, 4.0)
		Weather.HEAVY_RAIN: return randf_range(3.0, 6.0)
		Weather.RAIN: return randf_range(4.0, 8.0)
		Weather.FOG: return randf_range(4.0, 10.0)
	return randf_range(4.0, 10.0)

func _generate_forecast() -> void:
	forecast.clear()
	for i: int in range(3):
		var day_ahead: int = i + 1
		var fake_weather: String = _roll_forecast_weather()
		forecast.append({
			"day": GameState.current_day + day_ahead,
			"weather": fake_weather,
			"accurate": i == 0,
		})
	forecast_updated.emit(forecast)

func _roll_forecast_weather() -> String:
	var roll: float = randf()
	if roll < 0.4: return "clear"
	elif roll < 0.6: return "overcast"
	elif roll < 0.75: return "drizzle"
	elif roll < 0.85: return "rain"
	elif roll < 0.92: return "fog"
	elif roll < 0.97: return "storm"
	else: return "heavy_rain"

func get_weather_risk() -> float:
	return WEATHER_RISK.get(current_weather, 0.0)

func get_today_weather() -> String:
	return current_weather

func get_tomorrow_forecast() -> Dictionary:
	return forecast[1] if forecast.size() > 1 else {}

func get_day_after_forecast() -> Dictionary:
	return forecast[2] if forecast.size() > 2 else {}

func trigger_anomaly_weather() -> void:
	anomaly_weather_active = true
	anomaly_weather_count = 0
	anomaly_weather_triggered.emit("anomaly")
	print("[WeatherSystem] ANOMALY WEATHER triggered.")

func advance_season() -> void:
	var seasons: Array[String] = ["spring", "summer", "autumn", "winter"]
	var idx: int = seasons.find(current_season)
	idx = (idx + 1) % seasons.size()
	current_season = seasons[idx]
	season_day_counter = 1
	season_changed.emit(current_season)
	print("[WeatherSystem] Season changed to: %s" % current_season)

func _advance_day() -> void:
	season_day_counter += 1
	var season_len: int = season_lengths.get(current_season, 30)
	if season_day_counter > season_len:
		advance_season()
	_generate_forecast()

func simulate_day(day_number: int) -> Dictionary:
	var old_weather: String = current_weather
	var old_season: String = current_season
	_roll_daily_weather()
	weather_timer = 0.0
	_advance_day()
	return {
		"day": day_number,
		"weather": current_weather,
		"intensity": weather_intensity,
		"season": current_season,
	}

func force_weather(weather_name: String) -> void:
	current_weather = weather_name
	var intensity: float = WEATHER_RISK.get(weather_name, 0.3)
	weather_intensity = intensity
	GameState.weather_type = current_weather
	weather_changed.emit(current_weather, weather_intensity)
