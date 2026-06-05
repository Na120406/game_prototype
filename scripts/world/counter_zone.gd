extends Area2D

@export var linked_npc_path: NodePath
@export var shop_ui_path: NodePath
@export var interact_prompt: String = "[E]"

var _player_inside: bool = false

@onready var prompt: Label = $Prompt if has_node("Prompt") else null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_show_prompt(false)

func _is_npc_nearby() -> bool:
	if linked_npc_path == null or linked_npc_path.is_empty():
		return true
	if not has_node(linked_npc_path):
		return false
	var npc: Node2D = get_node(linked_npc_path)
	var player: Node2D = _get_player()
	if player == null or npc == null:
		return false
	return player.global_position.distance_to(npc.global_position) < 80.0

func _get_player() -> Node2D:
	var scene: SceneTree = get_tree()
	if scene == null:
		return null
	var root: Node = scene.current_scene
	if root == null:
		return null
	return _find_child(root, "Player")

func _find_child(root: Node, name: String) -> Node:
	if root == null:
		return null
	if root.name == name:
		return root
	for child in root.get_children():
		var result := _find_child(child, name)
		if result != null:
			return result
	return null

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = true
		_show_prompt(true)

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = false
		_show_prompt(false)

func _show_prompt(visible: bool) -> void:
	if prompt != null:
		prompt.visible = visible
