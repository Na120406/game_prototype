extends Area2D

@export var object_name: String = "Object"
@export_multiline var interaction_text: String = "You examined the object."
@export var can_interact: bool = true
@export var interaction_type: String = "examine"
@export var portal_id: String = ""
@export var target_scene: String = ""
@export var prompt_offset_y: float = -28.0
@export var interaction_priority: int = 0

var _player_inside: bool = false

var sprite: Sprite2D = null
var prompt_label: Label = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if has_node("Sprite"):
		sprite = $Sprite
	_ensure_prompt_label()
	if prompt_label != null:
		prompt_label.visible = false


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


func _process(_delta: float) -> void:
	if _player_inside and Input.is_action_just_pressed("interact"):
		_do_interact()


func interact(_player: Node) -> void:
	_do_interact()


func _do_interact() -> void:
	if not can_interact:
		return

	GameState.set_flag("examined_" + object_name.to_lower().replace(" ", "_"), true)
	print("[WorldObject] %s: type=%s" % [object_name, interaction_type])

	if interaction_type == "examine":
		DialogueManager.start_dialogue("examine_generic", object_name)
	elif interaction_type == "enter" and target_scene != "":
		SceneManager.change_scene(target_scene, portal_id)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = true
		_register_with_manager(true)
		if prompt_label != null:
			prompt_label.text = "[E]"
			prompt_label.visible = true


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = false
		_register_with_manager(false)
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


func get_portal_id() -> String:
	return portal_id