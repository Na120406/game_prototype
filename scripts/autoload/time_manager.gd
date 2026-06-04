extends Node

signal time_changed(current_time: float, is_day: bool)
signal day_changed(new_day: int)
signal hour_elapsed(hour: int)

var time_scale: float = 1.0
var paused: bool = false

func _process(delta: float) -> void:
	if paused:
		return

	var previous_time: float = GameState.current_time
	GameState.current_time += delta * time_scale * 0.1

	if GameState.current_time >= 22.0:
		GameState.is_day = false
	elif GameState.current_time >= 6.0:
		GameState.is_day = true

	if GameState.current_time >= 24.0:
		GameState.current_time = 0.0
		GameState.current_day += 1
		GameState.energy = GameState.max_energy
		GameState.is_day = true
		day_changed.emit(GameState.current_day)

	var prev_hour: int = int(previous_time)
	var curr_hour: int = int(GameState.current_time)
	if curr_hour != prev_hour:
		hour_elapsed.emit(curr_hour)

	if absf(GameState.current_time - previous_time) > 0.001:
		time_changed.emit(GameState.current_time, GameState.is_day)

func set_time(new_time: float) -> void:
	GameState.current_time = clampf(new_time, 0.0, 24.0)
	GameState.is_day = GameState.current_time >= 6.0 and GameState.current_time < 22.0
	time_changed.emit(GameState.current_time, GameState.is_day)

func set_day(new_day: int) -> void:
	GameState.current_day = new_day
	day_changed.emit(new_day)

func set_time_scale(scale: float) -> void:
	time_scale = maxf(0.0, scale)

func pause() -> void:
	paused = true

func resume() -> void:
	paused = false

func is_night() -> bool:
	return not GameState.is_day

func is_dawn() -> bool:
	return GameState.current_time >= 5.0 and GameState.current_time < 7.0

func is_dusk() -> bool:
	return GameState.current_time >= 19.0 and GameState.current_time < 22.0

func get_time_of_day_string() -> String:
	var hour: int = int(GameState.current_time)
	var minute: int = int((GameState.current_time - hour) * 60.0)
	return "%02d:%02d" % [hour, minute]
