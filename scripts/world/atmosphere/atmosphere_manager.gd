extends CanvasModulate

@export var enable_time_based_lighting: bool = true
@export var enable_weather_effects: bool = true

var base_color: Color = Color.WHITE
var _current_modulate := Color.WHITE

@onready var vignette: ColorRect = $Vignette if has_node("Vignette") else null
@onready var grain: ColorRect = $Grain if has_node("Grain") else null

func _ready() -> void:
	_add_overlay_effects()
	_connect_time_signals()
	print("[AtmosphereManager] Ready.")

func _connect_time_signals() -> void:
	TimeManager.time_changed.connect(_on_time_changed)
	TimeManager.day_changed.connect(_on_day_changed)

func _on_time_changed(_current_time: float, is_day: bool) -> void:
	if not enable_time_based_lighting:
		return

	if not is_day:
		_apply_night_lighting()
	else:
		_apply_day_lighting()

func _on_day_changed(new_day: int) -> void:
	print("[AtmosphereManager] Day %d — atmosphere shifts." % new_day)
	if new_day % 7 == 0 and enable_weather_effects:
		_trigger_random_weather()

func _apply_day_lighting() -> void:
	var hour := GameState.current_time

	if hour >= 6.0 and hour < 7.0:
		color = Color(1.0, 0.85, 0.7, 1.0)
	elif hour >= 7.0 and hour < 17.0:
		color = Color.WHITE
	elif hour >= 17.0 and hour < 19.0:
		color = Color(1.0, 0.75, 0.6, 1.0)
	elif hour >= 19.0 and hour < 20.0:
		color = Color(0.7, 0.6, 0.8, 1.0)
	else:
		color = Color(0.3, 0.3, 0.5, 1.0)

	_current_modulate = color

func _apply_night_lighting() -> void:
	var hour := GameState.current_time

	if hour >= 20.0 and hour < 22.0:
		color = Color(0.3, 0.3, 0.5, 1.0)
	elif hour >= 22.0 and hour < 24.0:
		color = Color(0.15, 0.15, 0.3, 1.0)
	elif hour >= 0.0 and hour < 5.0:
		color = Color(0.1, 0.1, 0.25, 1.0)
	elif hour >= 5.0 and hour < 6.0:
		color = Color(0.25, 0.2, 0.4, 1.0)

	_current_modulate = color

func _trigger_random_weather() -> void:
	var weathers := ["clear", "overcast", "fog", "drizzle"]
	var chosen: String = weathers[randi() % weathers.size()]
	GameState.weather_type = chosen
	print("[AtmosphereManager] Weather changed to: %s" % chosen)

func set_custom_modulation(color: Color, duration: float = 1.0) -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "color", color, duration)
	_current_modulate = color

func trigger_uncanny_shift(intensity: float = 0.15) -> void:
	var uncanny_color := Color(
		0.85 - intensity,
		0.85 - intensity,
		1.0,
		1.0
	)
	set_custom_modulation(uncanny_color, 2.0)
	await get_tree().create_timer(3.0).timeout
	set_custom_modulation(_current_modulate, 2.0)
	print("[AtmosphereManager] Uncanny shift triggered.")

func _add_overlay_effects() -> void:
	var root := get_parent()
	if root == null:
		return

	if vignette == null:
		vignette = ColorRect.new()
		vignette.name = "Vignette"
		vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
		vignette.color = Color(0, 0, 0, 0)
		add_child(vignette)

	if grain == null:
		grain = ColorRect.new()
		grain.name = "Grain"
		grain.set_anchors_preset(Control.PRESET_FULL_RECT)
		grain.color = Color(0, 0, 0, 0)
		grain.z_index = 10
		add_child(grain)

func enable_vignette(intensity: float = 0.5) -> void:
	if vignette != null:
		vignette.color = Color(0, 0, 0, intensity)

func disable_vignette() -> void:
	if vignette != null:
		vignette.color = Color(0, 0, 0, 0)
