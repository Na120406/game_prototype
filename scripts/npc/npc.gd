extends CharacterBody2D

signal npc_state_changed(new_state: String)
signal npc_dialogue_started()
signal npc_dialogue_finished()

enum NPCState { IDLE, WALKING, WORKING, RESTING, SPECIAL, SLEEPING, WAKING }

@export var npc_name: String = "Villager"
@export var npc_id: String = "villager_01"
@export var dialogue_id: String = "generic_greeting"
@export var schedule_enabled: bool = true

var current_state: NPCState = NPCState.IDLE
var current_schedule_step: int = 0
var schedule: Array[Dictionary] = []
var is_interacting: bool = false
var talk_count: int = 0
var relationship_value: int = 0
var _player_nearby: bool = false

var sprite: Sprite2D = null
var animation_player: AnimationPlayer = null
var interaction_area: Area2D = null
var navigation_agent: NavigationAgent2D = null
var prompt_label: Label = null

# Vị trí đích mà NPC đang di chuyển tới theo schedule step hiện tại.
# Khi schedule chuyển step (current_time đạt ngưỡng) → _target_pos được cập nhật.
# NPC script con có thể đọc/override giá trị này để điều khiển pathfinding.
# Trong Milestone 1 chỉ là placeholder — logic movement thật sẽ thêm ở bước sau.
var _target_pos: Vector2 = Vector2.ZERO

# Tốc độ di chuyển của NPC (px/giây). Override trong scene/script con nếu cần.
# 85 px/s tương đương 1 ô tile/giây cho viewport 480x270 với tile 32x32.
@export var move_speed: float = 80.0
@export var acceleration: float = 800.0
@export var friction: float = 1200.0
@export var avoid_radius: float = 28.0
@export var avoid_strength: float = 1.4
@export var waypoint_reach_distance: float = 5.0
@export var reroute_cooldown: float = 0.35

# Khoảng cách lệch NPC ra khỏi vị trí cửa/cổng ngay sau khi handoff (px), để
# NPC không chiếm chỗ ngay trước cửa và Player không bị chặn lối đi.
const PORTAL_ARRIVAL_OFFSET: float = 14.0

var _avoid_timer: float = 0.0
var _last_schedule_time: float = -1.0
var _schedule_target_scene: String = ""
# Prevents the just-finished transit step from being reapplied while the NPC
# waits in the destination map for the next clock schedule step.
var _arrived_schedule_scene: String = ""
var _arrived_schedule_time: float = -1.0
var _arrived_route_id: String = ""
var _completed_route_id: String = ""
var _last_schedule_day: int = -1
var active_route_id: String = ""
var active_route_index: int = -1
var active_route: Array[Dictionary] = []
var route_progress: Dictionary = {}

@export var prompt_offset_y: float = -32.0

func _ready() -> void:
	add_to_group("npc")
	add_to_group("npc_" + npc_id)
	_resolve_node_refs()
	_ensure_prompt_label()
	_build_default_schedule()
	_connect_signals()
	print("[NPC] %s (%s) ready." % [npc_name, npc_id])


func _resolve_node_refs() -> void:
	if has_node("Sprite2D"):
		sprite = $Sprite2D
	if has_node("AnimationPlayer"):
		animation_player = $AnimationPlayer
	if has_node("InteractionArea"):
		interaction_area = $InteractionArea
	if has_node("NavigationAgent2D"):
		navigation_agent = $NavigationAgent2D


func _ensure_prompt_label() -> void:
	if has_node("Prompt"):
		prompt_label = $Prompt
	else:
		prompt_label = Label.new()
		prompt_label.name = "Prompt"
		add_child(prompt_label)

	# Thuần text trắng cỡ nhỏ
	prompt_label.anchor_left = 0.0
	prompt_label.anchor_top = 0.0
	prompt_label.anchor_right = 0.0
	prompt_label.anchor_bottom = 0.0
	prompt_label.offset_left = -12.0
	prompt_label.offset_top = prompt_offset_y
	prompt_label.offset_right = 12.0
	prompt_label.offset_bottom = prompt_offset_y + 8.0

	prompt_label.text = "[E]"
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 6)
	prompt_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	prompt_label.z_index = 20
	prompt_label.visible = false

func _connect_signals() -> void:
	if interaction_area != null:
		interaction_area.body_entered.connect(_on_player_entered_area)
		interaction_area.body_exited.connect(_on_player_exited_area)

func _on_player_entered_area(body: Node) -> void:
	if body.is_in_group("player"):
		_player_nearby = true
		_on_player_nearby(body)

func _on_player_exited_area(body: Node) -> void:
	if body.is_in_group("player"):
		_player_nearby = false
		_on_player_left(body)

func is_player_nearby() -> bool:
	return _player_nearby

func _build_default_schedule() -> void:
	schedule = [
		{"time": 6.0, "state": NPCState.WAKING, "action": "wake_up", "pos": Vector2(0, 0)},
		{"time": 7.0, "state": NPCState.WORKING, "action": "start_work", "pos": Vector2(0, 0)},
		{"time": 12.0, "state": NPCState.IDLE, "action": "lunch_break", "pos": Vector2(0, 0)},
		{"time": 13.0, "state": NPCState.WORKING, "action": "resume_work", "pos": Vector2(0, 0)},
		{"time": 18.0, "state": NPCState.IDLE, "action": "go_home", "pos": Vector2(0, 0)},
		{"time": 20.0, "state": NPCState.SLEEPING, "action": "sleep", "pos": Vector2(0, 0)},
	]

func _physics_process(delta: float) -> void:
	if not is_inside_tree():
		return
	if is_interacting or not schedule_enabled:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		move_and_slide()
		return
	# Trạng thái IDLE chỉ có hiệu lực sau khi đã tới đúng vị trí lịch trình.
	# Khi còn cách target, luôn cho phép route/schedule tiếp tục di chuyển.
	if global_position.distance_to(_target_pos) > waypoint_reach_distance:
		if current_state != NPCState.WALKING:
			_change_state(NPCState.WALKING)
	_move_along_schedule(delta)

func _move_along_schedule(delta: float) -> void:
	if active_route_index >= 0 and not active_route.is_empty():
		if _advance_route_if_reached():
			return
	if _target_pos == Vector2.ZERO:
		# Tọa độ zero chỉ là target hợp lệ khi NPC đã thật sự tới đó;
		# không được dùng nó làm lý do đứng im khi route đang chạy.
		if active_route_index >= 0 and not active_route.is_empty():
			_target_pos = active_route[active_route_index].get("position", global_position)
		else:
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
			move_and_slide()
			return
	if global_position.distance_to(_target_pos) <= waypoint_reach_distance:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		if current_state == NPCState.WALKING:
			_change_state(NPCState.IDLE)
		move_and_slide()
		return
	var to_target := global_position.direction_to(_target_pos)
	# Không cho steering né Player làm lệch toàn bộ hướng lịch trình khi
	# Marcus vừa ra khỏi cutscene và Player đang đứng gần portal.
	var steering: Vector2 = _get_player_avoidance()
	if active_route_index >= 0 or current_state == NPCState.WALKING:
		steering = steering.limit_length(0.15)
	var desired: Vector2 = (to_target + steering * avoid_strength).normalized() * move_speed
	velocity = velocity.move_toward(desired, acceleration * delta)
	move_and_slide()

func _advance_route_if_reached() -> bool:
	if active_route_index < 0 or active_route_index >= active_route.size():
		return false
	var waypoint: Dictionary = active_route[active_route_index]
	var waypoint_scene: String = str(waypoint.get("scene", ""))
	# Không tự nhảy waypoint khi scene chưa đổi: chỉ SceneManager handoff sau
	# khi chạm portal mới được phép chuyển sang waypoint scene kế tiếp.
	if waypoint_scene != "" and _get_host_scene_path() != waypoint_scene:
		velocity = Vector2.ZERO
		return true
	var raw_waypoint_pos: Variant = waypoint.get("position", global_position)
	var waypoint_pos: Vector2 = raw_waypoint_pos as Vector2 if raw_waypoint_pos is Vector2 else global_position
	if global_position.distance_to(waypoint_pos) > waypoint_reach_distance:
		_target_pos = waypoint_pos
		return false
	var portal_id: String = str(waypoint.get("portal_id", ""))
	var next_index: int = active_route_index + 1
	if next_index < active_route.size() and str(active_route[next_index].get("scene", "")) != waypoint_scene and portal_id != "":
		var next_scene: String = str(active_route[next_index].get("scene", ""))
		var target_waypoint: Dictionary = active_route[next_index]
		var target_portal_id: String = str(target_waypoint.get("portal_id", portal_id))
		var target_position: Variant = target_waypoint.get("position", global_position)
		set_meta("route_arrival_position", target_position)
		set_meta("route_arrival_portal_id", target_portal_id)
		print("[NPC %s] Requesting handoff to %s with portal_id='%s' at waypoint pos %s" % [npc_id, next_scene, target_portal_id, target_position])
		var scene_manager := get_node_or_null("/root/SceneManager")
		if scene_manager != null and scene_manager.has_method("handoff_persistent_npc"):
			if scene_manager.call("handoff_persistent_npc", self, next_scene, target_portal_id):
				active_route_index = next_index
				route_progress = {"route_id": active_route_id, "waypoint_index": active_route_index}
				return true
	active_route_index = next_index
	if active_route_index >= active_route.size():
		_completed_route_id = active_route_id
		_arrived_route_id = active_route_id
		active_route_index = -1
		active_route = []
		route_progress = {"route_id": _completed_route_id, "waypoint_index": -1}
		_target_pos = global_position
		velocity = Vector2.ZERO
		_change_state(NPCState.IDLE)
		return true
	var next_waypoint: Dictionary = active_route[active_route_index]
	var raw_next_position: Variant = next_waypoint.get("position", global_position)
	_target_pos = raw_next_position as Vector2 if raw_next_position is Vector2 else global_position
	route_progress = {"route_id": active_route_id, "waypoint_index": active_route_index}
	return true

func _find_route_start_index(waypoints: Array[Dictionary]) -> int:
	var scene_path: String = _get_host_scene_path()
	for index: int in range(waypoints.size()):
		if str(waypoints[index].get("scene", "")) == scene_path:
			return index
	return 0

func set_route(route_id: String, waypoints: Array[Dictionary], start_index: int = 0) -> void:
	if route_id == active_route_id and not active_route.is_empty():
		return
	active_route_id = route_id
	active_route = waypoints.duplicate(true)
	active_route_index = clampi(start_index, 0, active_route.size() - 1) if not active_route.is_empty() else -1
	route_progress = {"route_id": active_route_id, "waypoint_index": active_route_index}
	if active_route_index >= 0:
		var raw_position: Variant = active_route[active_route_index].get("position", global_position)
		_target_pos = raw_position as Vector2 if raw_position is Vector2 else global_position

func clear_route() -> void:
	active_route_id = ""
	active_route_index = -1
	active_route.clear()
	route_progress.clear()

# Called after a route crosses into a new map. The route is a transit plan,
# not the NPC's next movement target. Once the destination is reached, select
# the first schedule step belonging to that map and stop driving toward the
# previous map's position.
func on_route_arrived(arrived_scene_path: String) -> void:
	# Crossing a portal completes the transit route. Never leave its source
	# waypoint active: doing so makes the NPC repeatedly steer back toward the
	# previous portal (the observed endless leftward movement in Town).
	_arrived_schedule_scene = ""
	_arrived_schedule_time = -1.0
	_arrived_route_id = active_route_id
	_completed_route_id = active_route_id
	clear_route()
	# Sau handoff phải chọn target của scene ĐÍCH, không gọi tick_schedule()
	# trước: tick_schedule có thể chọn step nguồn khi giờ vẫn thuộc bước cũ rồi
	# kéo NPC quay lại cửa. Chọn step gần nhất đã có hiệu lực thuộc đúng scene.
	var arrival_pos: Vector2 = global_position
	var step_index: int = _find_arrival_step_index(arrived_scene_path)
	if step_index < 0:
		_target_pos = global_position
		velocity = Vector2.ZERO
		_change_state(NPCState.IDLE)
		return
	# Nếu step chọn có vị trí ngay tại cửa/cổng (NPC sẽ đứng chặn cửa bị delay),
	# nhảy sang step kế tiếp trong cùng scene để NPC đi tiếp theo lịch trình
	# thay vì đứng nguyên tại cửa chờ step tiếp theo.
	var guard: int = 0
	while guard < schedule.size():
		guard += 1
		var step: Dictionary = schedule[step_index]
		var step_pos_value: Variant = step.get("pos", global_position)
		var step_pos: Vector2 = step_pos_value as Vector2 if step_pos_value is Vector2 else global_position
		if step_pos.distance_to(arrival_pos) > waypoint_reach_distance:
			break
		var next_index: int = _next_step_index_in_scene(step_index, arrived_scene_path)
		if next_index < 0 or next_index == step_index:
			break
		step_index = next_index
	var selected_step: Dictionary = schedule[step_index]
	var selected_pos_value: Variant = selected_step.get("pos", global_position)
	var selected_pos: Vector2 = selected_pos_value as Vector2 if selected_pos_value is Vector2 else global_position
	current_schedule_step = step_index
	_last_schedule_time = float(selected_step.get("time", _last_schedule_time))
	_schedule_target_scene = arrived_scene_path
	_target_pos = selected_pos
	var state_value: int = int(selected_step.get("state", NPCState.IDLE))
	_change_state(state_value as NPCState)
	# Xuất hiện ngay lập tức nhưng lệch hẳn ra khỏi cửa theo hướng đi tới vị
	# trí lịch trình — không chiếm chỗ ngay trước cửa/cổng. Physics tick tiếp
	# theo sẽ tiếp tục di chuyển NPC tới _target_pos.
	var to_target: Vector2 = arrival_pos.direction_to(_target_pos)
	if to_target != Vector2.ZERO and arrival_pos.distance_to(_target_pos) > waypoint_reach_distance:
		global_position = arrival_pos + to_target * PORTAL_ARRIVAL_OFFSET
	velocity = Vector2.ZERO


# Tìm step đang hiệu lực của scene vừa tới: step cuối có time <= current_time
# trong scene đó; nếu chưa có step nào, trả về step đầu tiên của scene.
func _find_arrival_step_index(arrived_scene_path: String) -> int:
	for index: int in range(schedule.size() - 1, -1, -1):
		var active_step: Dictionary = schedule[index]
		if float(active_step.get("time", 0.0)) <= GameState.current_time and str(active_step.get("scene", "")) == arrived_scene_path:
			return index
	for index: int in range(schedule.size()):
		var step: Dictionary = schedule[index]
		if str(step.get("scene", "")) == arrived_scene_path:
			return index
	return -1


# Step kế tiếp (theo vòng, cùng scene) sau from_index; -1 nếu không có.
func _next_step_index_in_scene(from_index: int, scene_path: String) -> int:
	for offset: int in range(1, schedule.size() + 1):
		var index: int = (from_index + offset) % schedule.size()
		if str(schedule[index].get("scene", "")) == scene_path:
			return index
	return -1

func _get_host_scene_path() -> String:
	# Parent scene is authoritative while attached; NPC metadata is only a
	# fallback during handoff, otherwise Farm metadata makes it appear in Town
	# before it actually crosses the portal.
	var current: Node = self
	while current.get_parent() != null:
		current = current.get_parent()
		if current.has_meta("world_scene_path"):
			return str(current.get_meta("world_scene_path"))
		if current.scene_file_path != "" and not current.name.begins_with("NPCWorld_"):
			return current.scene_file_path
	if has_meta("world_scene_path"):
		return str(get_meta("world_scene_path"))
	return ""

func get_route_progress() -> Dictionary:
	return {"route_id": active_route_id, "waypoint_index": active_route_index, "scene": _get_host_scene_path(), "position": {"x": global_position.x, "y": global_position.y}}

func get_destination_portal_id() -> String:
	if active_route_index >= 0 and active_route_index + 1 < active_route.size():
		return str(active_route[active_route_index + 1].get("portal_id", ""))
	return ""

func get_runtime_state() -> Dictionary:
	return {
		"npc_id": npc_id,
		"day": GameState.current_day,
		"time": GameState.current_time,
		"schedule_step": current_schedule_step,
		"state": int(current_state),
		"route": get_route_progress(),
	}

func restore_runtime_state(state: Dictionary) -> void:
	var raw_route: Variant = state.get("route", {})
	if raw_route is Dictionary:
		active_route_id = str(raw_route.get("route_id", ""))
		active_route_index = int(raw_route.get("waypoint_index", -1))
		if active_route_id != "":
			var route_manager := get_node_or_null("/root/NPCRouteManager")
			if route_manager != null and route_manager.has_method("get_route"):
				active_route = route_manager.call("get_route", active_route_id)
		var raw_position: Variant = raw_route.get("position", {})
		if raw_position is Dictionary:
			_target_pos = Vector2(float(raw_position.get("x", global_position.x)), float(raw_position.get("y", global_position.y)))
	current_schedule_step = int(state.get("schedule_step", current_schedule_step))
	_last_schedule_day = int(state.get("day", GameState.current_day))
	_last_schedule_time = float(state.get("time", GameState.current_time))

func _get_player_avoidance() -> Vector2:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return Vector2.ZERO
	var offset := global_position - player.global_position
	var distance := offset.length()
	if distance <= 0.01 or distance > avoid_radius:
		return Vector2.ZERO
	return offset.normalized() * (1.0 - distance / avoid_radius)

func _change_state(new_state: NPCState) -> void:
	if new_state == current_state:
		return
	if new_state != current_state:
		current_state = new_state
		npc_state_changed.emit(NPCState.keys()[new_state])
	_update_npc_animation()

func _execute_schedule_action(action: String) -> void:
	match action:
		"wake_up":
			print("[NPC] %s wakes up." % npc_name)
		"start_work":
			print("[NPC] %s starts working." % npc_name)
		"sleep":
			print("[NPC] %s goes to sleep." % npc_name)
			_change_state(NPCState.SLEEPING)

func _update_npc_animation() -> void:
	if animation_player == null:
		return

	var anim_name := "idle"
	match current_state:
		NPCState.IDLE: anim_name = "idle"
		NPCState.WALKING: anim_name = "walk"
		NPCState.WORKING: anim_name = "work"
		NPCState.RESTING: anim_name = "rest"
		NPCState.SLEEPING: anim_name = "sleep"
		NPCState.SPECIAL: anim_name = "special"

	if animation_player.has_animation(anim_name):
		animation_player.play(anim_name)

func interact(player: Node) -> void:
	if is_interacting:
		return

	is_interacting = true
	talk_count += 1
	npc_dialogue_started.emit()
	print("[NPC] %s interacted with player (talk count: %d)." % [npc_name, talk_count])

	DialogueManager.start_dialogue(dialogue_id, npc_name, npc_id)
	DialogueManager.dialogue_ended.connect(_on_dm_ended, CONNECT_ONE_SHOT)

func _on_dm_ended() -> void:
	is_interacting = false
	npc_dialogue_finished.emit()

func _on_player_nearby(_body: Node) -> void:
	if sprite != null:
		sprite.modulate = Color(1.1, 1.1, 1.0)
	if prompt_label != null:
		prompt_label.text = "[E]"
		prompt_label.visible = true
	_register_with_manager(true)


func _on_player_left(_body: Node) -> void:
	if sprite != null:
		sprite.modulate = Color.WHITE
	if prompt_label != null:
		prompt_label.visible = false
	_register_with_manager(false)


func _register_with_manager(nearby: bool) -> void:
	var mgr := _get_prompt_manager()
	if mgr == null:
		return
	if nearby:
		mgr.register_nearby(self)
	else:
		mgr.unregister_nearby(self)


func _get_prompt_manager() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("InteractionPromptManager")

func set_relationship(delta: int) -> void:
	relationship_value = clamp(relationship_value + delta, -100, 100)
	GameState.set_flag("npc_%s_relationship" % npc_id, relationship_value)

func get_relationship() -> int:
	return relationship_value


# =============================================================================
# MOVEMENT API — stubs cho Milestone 1, sẽ thay thế bằng NavigationAgent2D
# pathfinding ở bước sau (xem TODO ở scripts/npc/npc.gd).
# Hiện tại là no-op để các script con (neighbor.gd) parse được và behavior hiện
# tại (state machine + print) không bị thay đổi.
# =============================================================================

# Stub: dừng di chuyển NPC. Hiện tại không làm gì — sẽ integrate NavigationAgent2D
# + velocity reset ở Milestone 1 khi bạn duyệt plan movement.
func stop_walking() -> void:
	velocity = Vector2.ZERO
	if navigation_agent != null:
		navigation_agent.target_position = global_position
	if current_state == NPCState.WALKING:
		_change_state(NPCState.IDLE)

func apply_current_step() -> void:
	tick_schedule(GameState.current_time)

# Stub: trả về schedule hiện tại. NPCManager dùng để resolve step ở
# npc_manager.gd:295-296.
func get_schedule() -> Array:
	return schedule

# Stub: tick schedule với current_time. NPCManager gọi mỗi frame qua
# time_changed signal (xem npc_manager.gd:582). Hiện tại no-op — sẽ implement
# logic "tìm step khớp → cập nhật _target_pos → state WALKING" ở Milestone 1.
func tick_schedule(current_time: float) -> void:
	if schedule.is_empty() or not schedule_enabled:
		return
	var current_day: int = GameState.current_day
	var day_changed: bool = current_day != _last_schedule_day
	var selected: Dictionary = schedule[0]
	for step: Dictionary in schedule:
		if float(step.get("time", 0.0)) <= current_time:
			selected = step
		else:
			break
	var selected_time: float = float(selected.get("time", 0.0))
	var selected_scene: String = str(selected.get("scene", ""))
	var selected_route_id: String = str(selected.get("route_id", ""))
	# Sau khi handoff qua cổng, NPC đã ở scene đích nhưng step cũ (scene nguồn)
	# vẫn có time <= current_time; áp dụng step đó sẽ kéo NPC quay lại/đứng chặn
	# cửa. Chỉ áp dụng step thuộc đúng scene NPC đang đứng; target do
	# on_route_arrived đặt sẽ được giữ cho tới khi step của scene hiện tại bắt đầu.
	# Ngoại lệ: step transit ghi scene ĐÍCH nhưng có route mà waypoint nguồn nằm
	# đúng scene NPC đang đứng (vd after_intro 20:00 go_to_bed) vẫn được áp dụng.
	var host_scene: String = _get_host_scene_path()
	if selected_scene != "" and host_scene != "" and selected_scene != host_scene:
		var route_starts_here: bool = false
		if selected_route_id != "":
			var route_manager: Node = get_node_or_null("/root/NPCRouteManager")
			if route_manager != null and route_manager.has_method("get_waypoint"):
				var first_waypoint: Variant = route_manager.call("get_waypoint", selected_route_id, 0)
				if first_waypoint is Dictionary:
					route_starts_here = str(first_waypoint.get("scene", "")) == host_scene
		if not route_starts_here:
			return
	# Do not reuse the route that has already delivered this NPC to the map.
	# Only the schedule step's own route may drive the next transition.
	if selected_route_id != "" and selected_route_id == _arrived_route_id and selected_scene == _get_host_scene_path():
		selected_route_id = ""
		selected["route_id"] = ""
	# Keep a route only until its handoff has completed. A later schedule tick
	# must not overwrite the destination state with the previous route target.
	if _arrived_schedule_scene == selected_scene and is_equal_approx(selected_time, _arrived_schedule_time) and selected_route_id == "":
		return
	if _arrived_schedule_scene != "" and selected_scene != _arrived_schedule_scene:
		_arrived_schedule_scene = ""
		_arrived_schedule_time = -1.0
	# Chỉ giữ route đang chạy nếu bước hiện tại vẫn thuộc route đó. Khi lịch
	# chuyển sang bước mới có route khác, phải cho phép thay route ngay.
	if active_route_id != "" and not active_route.is_empty() and selected_route_id == "" and selected_scene == _get_host_scene_path():
		return
	if not day_changed and is_equal_approx(selected_time, _last_schedule_time) and selected_scene == _schedule_target_scene and selected_route_id == active_route_id:
		return
	_last_schedule_day = current_day
	_last_schedule_time = selected_time
	_schedule_target_scene = selected_scene
	current_schedule_step = schedule.find(selected)
	_target_pos = selected.get("pos", global_position)
	var route_id: String = str(selected.get("route_id", ""))
	if route_id != "":
		# Transit begins from the current map's waypoint. Never use an old route
		# index from another schedule transition.
		if str(route_progress.get("route_id", "")) != route_id:
			route_progress.clear()
		if route_id != _arrived_route_id:
			_arrived_route_id = ""
		_completed_route_id = ""
		var route_manager := get_node_or_null("/root/NPCRouteManager")
		if route_manager != null and route_manager.has_method("get_route"):
			var raw_route: Variant = route_manager.call("get_route", route_id)
			var route_waypoints: Array[Dictionary] = []
			if raw_route is Array:
				for raw_waypoint in raw_route:
					if raw_waypoint is Dictionary:
						route_waypoints.append(raw_waypoint)
			var saved_route_id: String = str(route_progress.get("route_id", ""))
			var saved_index: int = int(route_progress.get("waypoint_index", -1))
			# A new schedule route must start from its own waypoint matching the
			# current map; never reuse the completed farm_to_town index (1).
			var route_start: int = saved_index if saved_route_id == route_id and saved_index >= 0 and saved_index < route_waypoints.size() else _find_route_start_index(route_waypoints)
			set_route(route_id, route_waypoints, route_start)
	else:
		clear_route()
	var new_state_value: int = int(selected.get("state", NPCState.IDLE))
	var new_state: NPCState = new_state_value as NPCState
	if new_state != current_state:
		_change_state(new_state)
	if new_state == NPCState.WALKING or global_position.distance_to(_target_pos) > waypoint_reach_distance:
		_change_state(NPCState.WALKING)
	if navigation_agent != null:
		navigation_agent.target_position = _target_pos

# Stub: hook khi NPC được attach vào scene mới (gọi từ NPCManager._attach_npc
# ở npc_manager.gd:397-398). Dùng để reset movement state, snap pos nếu cần.
func _on_attached_to_scene() -> void:
	velocity = Vector2.ZERO
	_avoid_timer = 0.0
	# Ép đồng bộ lịch khi vừa được rehome; tránh guard của tick_schedule giữ
	# trạng thái idle cũ sau khi đổi scene.
	_arrived_schedule_scene = ""
	_arrived_schedule_time = -1.0
	_last_schedule_time = -1.0
	apply_current_step()

# Stub: hook khi NPC bị detach khỏi scene (gọi từ NPCManager._detach_npc ở
# npc_manager.gd:452-453 + npc_manager.gd:524). Dùng để stop movement trước
# khi instance rời tree.
func _on_detached_from_scene() -> void:
	stop_walking()
	_schedule_target_scene = ""
