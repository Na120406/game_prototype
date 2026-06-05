extends StaticBody2D

signal sleep_requested()

const INTERACT_DISTANCE: float = 50.0

@onready var prompt: Label = $Prompt

var _player: Node = null
var _player_nearby: bool = false

func _ready() -> void:
	prompt.visible = false
	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		_player = _find_player_in_tree()

func _find_player_in_tree() -> Node:
	var root: Node = get_tree().root
	if root == null:
		return null
	return _find_child_by_group(root, "player")

func _find_child_by_group(node: Node, group: String) -> Node:
	if node == null:
		return null
	if node.is_in_group(group):
		return node
	for child in node.get_children():
		var found := _find_child_by_group(child, group)
		if found != null:
			return found
	return null

func is_player_nearby() -> bool:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		return false
	var dist := global_position.distance_to(_player.global_position)
	return dist <= INTERACT_DISTANCE

func _process(_delta: float) -> void:
	var nearby := is_player_nearby()
	if nearby != _player_nearby:
		_player_nearby = nearby
		prompt.visible = nearby

func interact(_player_ref: Node) -> void:
	sleep_requested.emit()
