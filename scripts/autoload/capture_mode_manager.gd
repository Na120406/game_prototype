extends Node
## Debug-only capture mode (Ctrl + F9).
##
## This manager changes presentation only:
## - Player Sprite2D hidden
## - HUD canvas layers/prompts hidden, except the realtime clock
## - Mouse cursor hidden
##
## Player/NPC nodes keep processing normally, so physics, interactions,
## schedules, clock and camera are never paused or reconfigured.

signal capture_mode_changed(enabled: bool)

const HUD_CANVAS_NAMES: Array[StringName] = [
	&"UI",
	&"HUD",
	&"DialogueLayer",
	&"DialogueUI",
	&"EnergyBarCanvas",
	&"FloatingWarning",
	&"QuestBoardUI",
	&"BackdropLayer",
	&"TooltipLayer",
]

var _capture_enabled: bool = false
var _cursor_hidden_for_capture: bool = false
var _visibility_snapshot: Dictionary = {}
var _tracked_nodes: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not _is_debug_editor_session():
		set_process_input(false)
		set_process(false)
		return
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)


func _exit_tree() -> void:
	if _capture_enabled:
		set_capture_mode(false)
	if get_tree() != null and get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)


func _input(event: InputEvent) -> void:
	if not _is_debug_editor_session() or not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	var is_f9: bool = key_event.keycode == KEY_F9 or key_event.physical_keycode == KEY_F9
	if not key_event.pressed or key_event.echo or not key_event.ctrl_pressed or not is_f9:
		return
	set_capture_mode(not _capture_enabled)
	get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _capture_enabled:
		# Debug-only enforcement keeps HUD spawned during a scene change hidden.
		_apply_capture_visibility()


func is_capture_mode_enabled() -> bool:
	return _capture_enabled


func is_capture_mode_available() -> bool:
	return _is_debug_editor_session()


func is_cursor_hidden_for_capture() -> bool:
	return _cursor_hidden_for_capture


func set_capture_mode(enabled: bool) -> void:
	if not _is_debug_editor_session() or enabled == _capture_enabled:
		return
	_capture_enabled = enabled
	if enabled:
		_visibility_snapshot.clear()
		_tracked_nodes.clear()
		_apply_capture_visibility()
		_cursor_hidden_for_capture = true
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	else:
		_restore_visibility()
		_cursor_hidden_for_capture = false
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	capture_mode_changed.emit(_capture_enabled)
	print("[CaptureMode] %s (debug only)." % ("ON" if _capture_enabled else "OFF"))


func _is_debug_editor_session() -> bool:
	# Debug export templates are still exported player builds. Requiring the
	# editor feature keeps this tool available only while running from Godot.
	return OS.is_debug_build() and OS.has_feature("editor")


func _apply_capture_visibility() -> void:
	if not _capture_enabled or get_tree() == null:
		return
	for player_value: Variant in get_tree().get_nodes_in_group("player"):
		if player_value is Node and is_instance_valid(player_value):
			var player := player_value as Node
			var player_sprite: Node = player.get_node_or_null("Sprite2D")
			if player_sprite is CanvasItem:
				_remember_and_hide(player_sprite)
	for node: Node in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if _is_primary_world_ui_canvas(node):
			_configure_capture_clock(node as CanvasLayer)
		elif _is_hud_canvas(node):
			_remember_and_hide(node)
	for node: Node in get_tree().root.find_children("*", "CanvasItem", true, false):
		if _is_world_hud_item(node):
			_remember_and_hide(node)


func _is_hud_canvas(node: Node) -> bool:
	if not (node is CanvasLayer):
		return false
	return node.name in HUD_CANVAS_NAMES or node.is_in_group("inventory_ui") or node.is_in_group("shop_ui")


func _is_primary_world_ui_canvas(node: Node) -> bool:
	return node is CanvasLayer and node.name == &"UI"


func _configure_capture_clock(ui_canvas: CanvasLayer) -> void:
	# UI phải còn visible để ClockPanel render. Mọi child khác bị ẩn riêng;
	# DayPanel ẩn khiến VBox tự đặt clock vào đúng slot trên cùng trước đây của
	# ô ngày. OFF sẽ restore từng visibility từ snapshot.
	_remember_and_show(ui_canvas)
	for child: Node in ui_canvas.get_children():
		if child.name == &"DayInfo" and child is CanvasItem:
			_remember_and_show(child)
			for info_child: Node in child.get_children():
				if info_child.name == &"ClockPanel" and info_child is CanvasItem:
					_remember_and_show(info_child)
				elif info_child is CanvasItem or info_child is CanvasLayer:
					_remember_and_hide(info_child)
		elif child is CanvasItem or child is CanvasLayer:
			_remember_and_hide(child)


func _is_world_hud_item(node: Node) -> bool:
	if not (node is CanvasItem):
		return false
	# Interaction prompts are world-space HUD. Floating warning labels are
	# parented to Player so they follow the camera and must also be hidden.
	if str(node.name).contains("Prompt"):
		return true
	if node is Label:
		var parent: Node = node.get_parent()
		while parent != null:
			if parent.is_in_group("player"):
				return true
			parent = parent.get_parent()
	return false


func _remember_and_hide(node: Node) -> void:
	_remember_visibility(node)
	if is_instance_valid(node):
		node.set("visible", false)


func _remember_and_show(node: Node) -> void:
	_remember_visibility(node)
	if is_instance_valid(node):
		node.set("visible", true)


func _remember_visibility(node: Node) -> void:
	if not is_instance_valid(node):
		return
	var instance_id: int = node.get_instance_id()
	if not _visibility_snapshot.has(instance_id):
		_visibility_snapshot[instance_id] = bool(node.get("visible"))
		_tracked_nodes[instance_id] = weakref(node)


func _restore_visibility() -> void:
	for instance_id: int in _visibility_snapshot:
		var node_ref: Variant = _tracked_nodes.get(instance_id, null)
		if not (node_ref is WeakRef):
			continue
		var node: Variant = (node_ref as WeakRef).get_ref()
		if node != null and is_instance_valid(node):
			node.set("visible", bool(_visibility_snapshot[instance_id]))
	_visibility_snapshot.clear()
	_tracked_nodes.clear()


func _on_node_added(node: Node) -> void:
	if not _capture_enabled:
		return
	# UI scenes often finish naming/parenting descendants after add_child().
	# Deferred evaluation sees their final role without touching process state.
	call_deferred("_hide_new_node_if_needed", weakref(node))


func _hide_new_node_if_needed(node_ref: WeakRef) -> void:
	if not _capture_enabled:
		return
	var node: Variant = node_ref.get_ref()
	if node == null or not is_instance_valid(node):
		return
	if _is_primary_world_ui_canvas(node):
		_configure_capture_clock(node as CanvasLayer)
	elif _is_hud_canvas(node) or _is_world_hud_item(node):
		_remember_and_hide(node)
	elif node is Sprite2D and node.name == &"Sprite2D" and node.get_parent() != null and node.get_parent().is_in_group("player"):
		_remember_and_hide(node)
