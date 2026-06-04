extends Node

signal scene_changed(scene_path: String)
signal scene_load_progress(progress: float)

const TRANSITION_DURATION: float = 0.5

var current_scene_path: String = ""
var previous_scene_path: String = ""
var _transition_overlay: ColorRect

func _ready() -> void:
	print("[SceneManager] Ready — scene transition system active.")

func change_scene(scene_path: String, use_transition: bool = true) -> void:
	if not ResourceLoader.exists(scene_path):
		push_error("[SceneManager] Scene not found: %s" % scene_path)
		return

	previous_scene_path = current_scene_path
	current_scene_path = scene_path

	if use_transition:
		_fade_to_black_and_load(scene_path)
	else:
		_load_scene(scene_path)

func _fade_to_black_and_load(scene_path: String) -> void:
	var vp := get_viewport()
	_transition_overlay = ColorRect.new()
	_transition_overlay.color = Color.TRANSPARENT
	_transition_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_transition_overlay.z_index = 9999

	var canvas := CanvasLayer.new()
	canvas.add_child(_transition_overlay)
	get_tree().root.add_child(canvas)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_transition_overlay, "color", Color.BLACK, TRANSITION_DURATION)

	await tween.finished
	_load_scene(scene_path)

	tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(_transition_overlay, "color", Color.TRANSPARENT, TRANSITION_DURATION)
	tween.tween_callback(_transition_overlay.queue_free).set_delay(TRANSITION_DURATION)

	scene_changed.emit(scene_path)

func _load_scene(scene_path: String) -> void:
	var packed := load(scene_path)
	if packed == null:
		push_error("[SceneManager] Failed to load: %s" % scene_path)
		return

	var new_scene: Node = packed.instantiate()
	var root := get_tree().root

	var current := get_tree().current_scene
	if current != null:
		root.remove_child(current)
		current.queue_free()

	root.add_child(new_scene)
	get_tree().current_scene = new_scene

func reload_current_scene() -> void:
	if current_scene_path != "":
		change_scene(current_scene_path, false)

func get_current_scene() -> Node:
	return get_tree().current_scene
