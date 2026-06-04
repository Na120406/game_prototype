extends Node2D

signal npc_state_changed(new_state: String)
signal npc_dialogue_started()
signal npc_dialogue_finished()

enum NPCState { IDLE, WALKING, WORKING, RESTING, SPECIAL, SLEEPING }

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

@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
@onready var animation_player: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null
@onready var interaction_area: Area2D = $InteractionArea if has_node("InteractionArea") else null
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D if has_node("NavigationAgent2D") else null

func _ready() -> void:
	add_to_group("npc")
	add_to_group("npc_" + npc_id)
	_build_default_schedule()
	_connect_signals()
	print("[NPC] %s (%s) ready." % [npc_name, npc_id])

func _connect_signals() -> void:
	if interaction_area != null:
		interaction_area.body_entered.connect(_on_player_nearby)
		interaction_area.body_exited.connect(_on_player_left)

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
	var old_state_str := NPCState.keys()[current_state]
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

	DialogueManager.start_dialogue(dialogue_id, npc_name)

	await DialogueManager.dialogue_ended
	is_interacting = false
	npc_dialogue_finished.emit()

func _on_player_nearby(_body: Node) -> void:
	if sprite != null:
		sprite.modulate = Color(1.1, 1.1, 1.0)

func _on_player_left(_body: Node) -> void:
	if sprite != null:
		sprite.modulate = Color.WHITE

func set_relationship(delta: int) -> void:
	relationship_value = clamp(relationship_value + delta, -100, 100)
	GameState.set_flag("npc_%s_relationship" % npc_id, relationship_value)

func get_relationship() -> int:
	return relationship_value
