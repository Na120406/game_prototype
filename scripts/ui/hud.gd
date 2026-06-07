extends Control

signal pause_toggled(is_paused: bool)

@export var show_fps: bool = false
@export var show_coords: bool = true

var is_paused: bool = false

@onready var day_label: Label = $VBox/DayLabel
@onready var time_label: Label = $VBox/TimeLabel
@onready var energy_bar: ProgressBar = $VBox/EnergyBar
@onready var tool_label: Label = $VBox/ToolLabel
@onready var coords_label: Label = $VBox/CoordsLabel
@onready var fps_label: Label = $VBox/FPSLabel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = true

	TimeManager.time_changed.connect(_on_time_changed)
	TimeManager.day_changed.connect(_on_day_changed)

	day_label.text = "Day 1"
	time_label.text = "06:00"
	energy_bar.max_value = GameState.max_energy
	energy_bar.value = GameState.energy
	tool_label.text = "Tool: None"

	if not show_fps:
		fps_label.visible = false
	if not show_coords:
		coords_label.visible = false

	print("[HUD] Ready.")

func _process(_delta: float) -> void:
	_update_hud()

	if show_fps:
		fps_label.text = "FPS: %d" % Engine.get_frames_per_second()

func _update_hud() -> void:
	energy_bar.value = GameState.energy
	tool_label.text = "Tool: %s" % get_node("/root/ToolHandler").get_equipped().to_upper()

	var player := get_tree().get_first_node_in_group("player")
	if player != null and show_coords:
		coords_label.text = "X:%d Y:%d" % [int(player.position.x), int(player.position.y)]

func _on_time_changed(current_time: float, _is_day: bool) -> void:
	var hour := int(current_time)
	var minute := int((current_time - hour) * 60)
	time_label.text = "%02d:%02d" % [hour, minute]

func _on_day_changed(new_day: int) -> void:
	day_label.text = "Day %d" % new_day

func toggle_pause() -> void:
	is_paused = not is_paused
	get_tree().paused = is_paused
	pause_toggled.emit(is_paused)
	print("[HUD] Pause: %s" % str(is_paused))

func show_notification(text: String, duration: float = 2.0) -> void:
	var notification := Label.new()
	notification.text = text
	notification.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notification.position = Vector2(0, 20)
	notification.set_anchors_preset(Control.PRESET_CENTER)
	add_child(notification)

	var tween := create_tween()
	tween.tween_property(notification, "modulate:a", 0.0, duration)
	tween.finished.connect(_on_notification_fade_done.bind(notification))

func _on_notification_fade_done(notification: Label) -> void:
	notification.queue_free()
