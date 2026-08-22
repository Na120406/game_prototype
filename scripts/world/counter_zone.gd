extends Area2D

@export var linked_npc_path: NodePath
@export var interact_prompt: String = "[E]"
@export var prompt_offset_y: float = -28.0
@export var interaction_priority: int = 5

var _player_inside: bool = false

var prompt: Label = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_ensure_prompt_label()
	_show_prompt(false)


func _ensure_prompt_label() -> void:
	if has_node("Prompt"):
		prompt = $Prompt
	else:
		prompt = Label.new()
		prompt.name = "Prompt"
		add_child(prompt)

	# Thuần text trắng cỡ nhỏ
	prompt.anchor_left = 0.0
	prompt.anchor_top = 0.0
	prompt.anchor_right = 0.0
	prompt.anchor_bottom = 0.0
	prompt.offset_left = -12.0
	prompt.offset_top = prompt_offset_y
	prompt.offset_right = 12.0
	prompt.offset_bottom = prompt_offset_y + 8.0

	prompt.text = interact_prompt
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 6)
	prompt.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	prompt.z_index = 20


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
	var nodes: Array = tree.get_nodes_in_group("shop_ui")
	if nodes.size() > 0:
		return nodes[0]
	return null


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = true
		_show_prompt(true)
		_register_with_manager(true)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = false
		_show_prompt(false)
		_register_with_manager(false)


func _show_prompt(visible: bool) -> void:
	if prompt != null:
		prompt.text = interact_prompt
		prompt.visible = visible


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