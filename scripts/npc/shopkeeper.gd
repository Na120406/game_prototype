extends Node2D

signal npc_dialogue_finished()

enum NPCState { IDLE, WALKING, WORKING, RESTING, SPECIAL }

@export var npc_name: String = "NPC"
@export var npc_id: String = "npc_01"
@export var dialogue_id: String = "generic_greeting"

var current_state: NPCState = NPCState.IDLE
var is_interacting: bool = false
var talk_count: int = 0
var _player_nearby: bool = false

@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
@onready var interact_area: Area2D = $InteractArea if has_node("InteractArea") else null
@onready var prompt_label: Label = $Prompt if has_node("Prompt") else null

func _ready() -> void:
	add_to_group("npc")
	add_to_group("npc_" + npc_id)
	_connect_area_signals()
	_hide_prompt()
	print("[Shopkeeper] %s ready." % npc_name)

func _connect_area_signals() -> void:
	if interact_area != null:
		interact_area.body_entered.connect(_on_body_entered)
		interact_area.body_exited.connect(_on_body_exited)

func interact(_player: Node) -> void:
	if is_interacting:
		return
	is_interacting = true
	talk_count += 1
	_hide_prompt()
	print("[Shopkeeper] Interact called (talk #%d)." % talk_count)
	DialogueManager.start_dialogue(dialogue_id, npc_name)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_nearby = true
		_show_prompt()
		if sprite != null:
			sprite.modulate = Color(1.15, 1.15, 1.0)

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_nearby = false
		_hide_prompt()
		if sprite != null:
			sprite.modulate = Color.WHITE

func _show_prompt() -> void:
	if prompt_label != null:
		prompt_label.visible = true

func _hide_prompt() -> void:
	if prompt_label != null:
		prompt_label.visible = false

func on_dialogue_ended() -> void:
	is_interacting = false
	npc_dialogue_finished.emit()
	print("[Shopkeeper] Dialogue finished.")

func get_talk_count() -> int:
	return talk_count
