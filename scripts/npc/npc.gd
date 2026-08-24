extends Node2D

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
@export var move_speed: float = 85.0

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

func _process(_delta: float) -> void:
	if is_interacting or not schedule_enabled:
		return
	_update_schedule()

func _update_schedule() -> void:
	var current_time := GameState.current_time

	for step in schedule:
		if abs(current_time - step.get("time", 0.0)) < 0.1:
			var new_state: NPCState = step.get("state", NPCState.IDLE)
			if new_state != current_state:
				_change_state(new_state)
				_execute_schedule_action(step.get("action", ""))

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
	# TODO (Milestone 1): velocity = Vector2.ZERO; NavigationAgent2D.target_position = global_position.
	pass

# Stub: áp dụng schedule step hiện tại lên NPC. Hiện tại không làm gì — logic
# thật sẽ tính step khớp current_time, cập nhật _target_pos + NavigationAgent2D.
# NPCManager đang gọi method này qua call("apply_current_step") ở
# scripts/autoload/npc_manager.gd:595-596 — cần method tồn tại để parse pass.
func apply_current_step() -> void:
	# TODO (Milestone 1): tương đương _pick_step(schedule, GameState.current_time).
	pass

# Stub: trả về schedule hiện tại. NPCManager dùng để resolve step ở
# npc_manager.gd:295-296.
func get_schedule() -> Array:
	return schedule

# Stub: tick schedule với current_time. NPCManager gọi mỗi frame qua
# time_changed signal (xem npc_manager.gd:582). Hiện tại no-op — sẽ implement
# logic "tìm step khớp → cập nhật _target_pos → state WALKING" ở Milestone 1.
func tick_schedule(_current_time: float) -> void:
	# TODO (Milestone 1): evaluate schedule → set _target_pos + state.
	pass

# Stub: hook khi NPC được attach vào scene mới (gọi từ NPCManager._attach_npc
# ở npc_manager.gd:397-398). Dùng để reset movement state, snap pos nếu cần.
func _on_attached_to_scene() -> void:
	# TODO (Milestone 1): reset NavigationAgent2D, snap pos nếu NPC đang idle.
	pass

# Stub: hook khi NPC bị detach khỏi scene (gọi từ NPCManager._detach_npc ở
# npc_manager.gd:452-453 + npc_manager.gd:524). Dùng để stop movement trước
# khi instance rời tree.
func _on_detached_from_scene() -> void:
	# TODO (Milestone 1): stop_walking(), save state.
	pass
