extends Area2D

@export var linked_npc_path: NodePath
@export var interact_prompt: String = "[E]"

var _player_inside: bool = false

@onready var prompt: Label = $Prompt if has_node("Prompt") else null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_show_prompt(false)

func is_player_nearby() -> bool:
	return _player_inside

func interact(_player: Node) -> void:
	var shop_ui: Node = _get_shop_ui()
	if shop_ui == null:
		print("[CounterZone] ShopUI not found via group.")
		return
	shop_ui.open(GameState.gold)
	print("[CounterZone] Shop opened.")

func _get_shop_ui() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	var nodes: Array[Node] = tree.get_nodes_in_group("shop_ui")
	if nodes.size() > 0:
		return nodes[0]
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
