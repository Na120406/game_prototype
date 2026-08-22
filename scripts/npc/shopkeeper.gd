extends Node2D

signal npc_dialogue_finished()

enum NPCState { IDLE, WALKING, WORKING, RESTING, SPECIAL }

@export var npc_name: String = "NPC"
@export var npc_id: String = "npc_01"
@export var dialogue_id: String = "generic_greeting"
@export var prompt_offset_y: float = -32.0
@export var interaction_priority: int = 5

var current_state: NPCState = NPCState.IDLE
var is_interacting: bool = false
var talk_count: int = 0
var _player_nearby: bool = false

var sprite: Sprite2D = null
var interact_area: Area2D = null
var prompt_label: Label = null

func _ready() -> void:
	add_to_group("npc")
	add_to_group("npc_" + npc_id)
	if has_node("Sprite2D"):
		sprite = $Sprite2D
	if has_node("InteractArea"):
		interact_area = $InteractArea
	_ensure_prompt_label()
	_connect_area_signals()
	_hide_prompt()
	print("[Shopkeeper] %s ready." % npc_name)


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


func is_player_nearby() -> bool:
	return _player_nearby


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_nearby = true
		_show_prompt()
		_register_with_manager(true)
		if sprite != null:
			sprite.modulate = Color(1.15, 1.15, 1.0)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_nearby = false
		_hide_prompt()
		_register_with_manager(false)
		if sprite != null:
			sprite.modulate = Color.WHITE


func _show_prompt() -> void:
	if prompt_label != null:
		prompt_label.text = "[E]"
		prompt_label.visible = true


func _hide_prompt() -> void:
	if prompt_label != null:
		prompt_label.visible = false


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


func on_dialogue_ended() -> void:
	is_interacting = false
	npc_dialogue_finished.emit()
	print("[Shopkeeper] Dialogue finished.")


func get_talk_count() -> int:
	return talk_count