extends StaticBody2D

@export var linked_npc_path: NodePath

var _player_nearby: bool = false

@onready var prompt_label: Label = $Prompt if has_node("Prompt") else null
@onready var prompt_area: Area2D = $PromptArea if has_node("PromptArea") else null

func _ready() -> void:
	_show_prompt(false)
	if prompt_area != null:
		prompt_area.body_entered.connect(_on_body_entered)
		prompt_area.body_exited.connect(_on_body_exited)

func interact(_player: Node) -> void:
	if not _is_npc_nearby():
		return
	var shop_ui: Node = _get_shop_ui()
	if shop_ui == null:
		return
	shop_ui.open(GameState.gold)

func is_player_nearby() -> bool:
	return _player_nearby

func set_player_nearby(value: bool) -> void:
	var was_nearby := _player_nearby
	_player_nearby = value
	if _player_nearby != was_nearby:
		_show_prompt(_player_nearby)

func _get_shop_ui() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	var nodes: Array[Node] = tree.get_nodes_in_group("shop_ui")
	if nodes.size() > 0:
		return nodes[0]
	return null

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
	return get_tree().get_first_node_in_group("player") as Node2D

func _show_prompt(visible: bool) -> void:
	if prompt_label != null:
		prompt_label.visible = visible

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		set_player_nearby(true)

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		set_player_nearby(false)
