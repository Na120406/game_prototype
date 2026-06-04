extends Node

signal screen_shake_requested(intensity: float, duration: float)

var _shake_intensity: float = 0.0
var _shake_duration: float = 0.0
var _shake_timer: float = 0.0
var _camera: Camera2D

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	print("[CameraManager] Ready.")

func _on_node_added(node: Node) -> void:
	if node is Camera2D:
		_camera = node

func request_shake(intensity: float = 8.0, duration: float = 0.3) -> void:
	if _camera == null:
		_camera = get_viewport().get_camera_2d()
	if _camera == null:
		return

	_shake_intensity = intensity
	_shake_duration = duration
	_shake_timer = duration
	screen_shake_requested.emit(intensity, duration)

func _process(delta: float) -> void:
	if _shake_timer > 0.0 and _camera != null:
		_shake_timer -= delta
		var progress := _shake_timer / _shake_duration
		var current_intensity := _shake_intensity * progress
		var offset := Vector2(
			randf_range(-current_intensity, current_intensity),
			randf_range(-current_intensity, current_intensity)
		)
		_camera.offset = offset
	else:
		if _camera != null:
			_camera.offset = Vector2.ZERO

func set_zoom_level(level: float) -> void:
	if _camera != null:
		_camera.zoom = Vector2(level, level)

func get_zoom_level() -> float:
	if _camera != null:
		return _camera.zoom.x
	return 1.0

func set_camera_limits(left: int, top: int, right: int, bottom: int) -> void:
	if _camera != null:
		_camera.limit_left = left
		_camera.limit_top = top
		_camera.limit_right = right
		_camera.limit_bottom = bottom
