extends StaticBody2D

signal sleep_requested()

var _player_nearby: bool = false

@onready var prompt: Label = $Prompt

func _ready() -> void:
	_interact_area().body_entered.connect(_on_body_entered)
	_interact_area().body_exited.connect(_on_body_exited)
	_show_prompt(false)

func _interact_area() -> Area2D:
	return $InteractArea

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
		_player_nearby = true
		_show_prompt(true)

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_nearby = false
		_show_prompt(false)

func _show_prompt(visible: bool) -> void:
	if prompt != null:
		prompt.visible = visible

func _input(event: InputEvent) -> void:
	if not _player_nearby:
		return
	if not visible:
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_show_sleep_prompt()

func _show_sleep_prompt() -> void:
	var player: Node2D = _get_player()
	if player == null:
		return
	if player.has_method("show_sleep_prompt"):
		player.show_sleep_prompt()
