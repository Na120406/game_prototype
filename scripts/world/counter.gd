extends StaticBody2D

@export var linked_npc_path: NodePath
@export var prompt_offset_y: float = -28.0
@export var interaction_priority: int = 5

var _player_nearby: bool = false

var prompt_label: Label = null
var prompt_area: Area2D = null

func _ready() -> void:
	_ensure_prompt_label()
	_ensure_prompt_area()
	_show_prompt(false)
	if prompt_area != null:
		prompt_area.body_entered.connect(_on_body_entered)
		prompt_area.body_exited.connect(_on_body_exited)


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


func _ensure_prompt_area() -> void:
	if has_node("PromptArea"):
		prompt_area = $PromptArea
		return
	prompt_area = Area2D.new()
	prompt_area.name = "PromptArea"
	prompt_area.collision_layer = 0
	prompt_area.collision_mask = 1
	add_child(prompt_area)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(160, 80)
	shape.shape = rect
	prompt_area.add_child(shape)


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
		_register_with_manager(_player_nearby)


func _get_shop_ui() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	var nodes: Array = tree.get_nodes_in_group("shop_ui")
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
		prompt_label.text = "[E]"
		prompt_label.visible = visible


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		set_player_nearby(true)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		set_player_nearby(false)


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
