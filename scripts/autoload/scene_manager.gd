extends Node

signal scene_changed(scene_path: String)

const TRANSITION_DURATION: float = 0.5

var current_scene_path: String = ""
var _transition_overlay: ColorRect
var _transition_canvas: CanvasLayer
var _pending_portal_id: String = ""
var _transition_tween: Tween

func _ready() -> void:
	print("[SceneManager] Ready — portal transition system active.")

func change_scene(scene_path: String, portal_id: String = "", use_transition: bool = true) -> void:
	if not ResourceLoader.exists(scene_path):
		push_error("[SceneManager] Scene not found: %s" % scene_path)
		return

	current_scene_path = scene_path
	_pending_portal_id = portal_id

	if use_transition:
		_start_fade_to_black(scene_path)
	else:
		_load_scene(scene_path)

func _start_fade_to_black(scene_path: String) -> void:
	if _transition_tween != null and _transition_tween.is_valid():
		return
	_transition_canvas = CanvasLayer.new()
	_transition_canvas.layer = 9999
	_transition_overlay = ColorRect.new()
	_transition_overlay.color = Color.TRANSPARENT
	_transition_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_transition_canvas.add_child(_transition_overlay)
	get_tree().root.add_child(_transition_canvas)

	_transition_tween = create_tween()
	_transition_tween.tween_property(_transition_overlay, "color", Color.BLACK, TRANSITION_DURATION)
	_transition_tween.finished.connect(_on_fade_to_black_complete.bind(scene_path))

func _on_fade_to_black_complete(scene_path: String) -> void:
	_load_scene(scene_path)

	var delay_timer := get_tree().create_timer(TRANSITION_DURATION)
	delay_timer.timeout.connect(_on_fade_in.bind(scene_path))

func _on_fade_in(scene_path: String) -> void:
	if _transition_overlay == null:
		return

	_transition_overlay.color = Color.BLACK
	_transition_tween = create_tween()
	_transition_tween.tween_property(_transition_overlay, "color", Color.TRANSPARENT, TRANSITION_DURATION)
	_transition_tween.finished.connect(_cleanup_transition)
	scene_changed.emit(scene_path)

func _cleanup_transition() -> void:
	if _transition_canvas != null:
		_transition_canvas.queue_free()
		_transition_canvas = null
	_transition_overlay = null

func _load_scene(scene_path: String) -> void:
	var packed := load(scene_path)
	if packed == null:
		push_error("[SceneManager] Failed to load: %s" % scene_path)
		return

	var new_scene: Node = packed.instantiate()
	var root := get_tree().root

	var current: Node = get_tree().current_scene
	if current != null:
		root.remove_child(current)
		current.queue_free()

	root.add_child(new_scene)
	get_tree().current_scene = new_scene

	if _pending_portal_id != "":
		var portal := _find_portal_in_scene(new_scene, _pending_portal_id)
		if portal != null:
			var player: Node = get_tree().get_first_node_in_group("player")
			if player != null and player.has_method("force_position"):
				player.force_position(portal.global_position)
				print("[SceneManager] Spawned at portal '%s': %s" % [_pending_portal_id, str(portal.global_position)])
		else:
			push_warning("[SceneManager] Portal '%s' not found in %s" % [_pending_portal_id, scene_path])
	else:
		print("[SceneManager] No portal_id — using scene default spawn")

	_pending_portal_id = ""

func _find_portal_in_scene(scene: Node, portal_id: String) -> Node:
	for area in scene.find_children("*", "Area2D", false, false):
		if area.has_method("get_portal_id") and area.get_portal_id() == portal_id:
			return area
		if area.get("portal_id") != null and area.get("portal_id") == portal_id:
			return area
	return null

func reload_current_scene() -> void:
	if current_scene_path != "":
		change_scene(current_scene_path, "", false)

func get_current_scene() -> Node:
	return get_tree().current_scene
