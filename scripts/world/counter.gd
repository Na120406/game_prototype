extends StaticBody2D

@export var linked_npc_path: NodePath
@export var shop_ui_path: NodePath

@onready var prompt_label: Label = $Prompt if has_node("Prompt") else null
@onready var prompt_area: Area2D = $PromptArea if has_node("PromptArea") else null

func _ready() -> void:
	_show_prompt(false)
	if prompt_area != null:
		prompt_area.body_entered.connect(_on_body_entered)
		prompt_area.body_exited.connect(_on_body_exited)

func interact(_player: Node) -> void:
	if not _is_npc_nearby():
		print("[Counter] No NPC nearby, cannot open shop.")
		return
	var shop_ui: Node = _get_shop_ui()
	if shop_ui == null:
		print("[Counter] ShopUI not found.")
		return
	shop_ui.open(GameState.gold)
	print("[Counter] Shop opened.")

func _get_shop_ui() -> Node:
	if shop_ui_path != null and not shop_ui_path.is_empty() and has_node(shop_ui_path):
		return get_node(shop_ui_path)
	var scene: SceneTree = get_tree()
	if scene == null:
		return null
	var root: Node = scene.current_scene
	if root == null:
		return null
	return _find_child(root, "ShopUI")

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

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_show_prompt(true)

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_show_prompt(false)

func _show_prompt(visible: bool) -> void:
	if prompt_label != null:
		prompt_label.visible = visible
