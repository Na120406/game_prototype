extends StaticBody2D

signal sleep_requested()

const INTERACT_DISTANCE: float = 50.0

@export var prompt_offset_y: float = -28.0
@export var interaction_priority: int = 5

var prompt: Label = null

var _player: Node = null
var _player_nearby: bool = false


func _ready() -> void:
	_ensure_prompt_label()
	prompt.visible = false
	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		_player = _find_player_in_tree()


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

	prompt.text = "[E]"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 6)
	prompt.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	prompt.z_index = 20


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
		prompt.text = "[E]"
		prompt.visible = nearby
		_register_with_manager(nearby)


func interact(_player_ref: Node) -> void:
	sleep_requested.emit()


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