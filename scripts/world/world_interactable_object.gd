extends Area2D

@export var object_name: String = "Object"
@export_multiline var interaction_text: String = "You examined the object."
@export var can_interact: bool = true
@export var interaction_type: String = "examine"
@export var portal_id: String = ""
@export var target_scene: String = ""

var _player_inside: bool = false

@onready var sprite: Sprite2D = $Sprite
@onready var prompt_label: Label = $Prompt

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if prompt_label != null:
		prompt_label.visible = false

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
		if prompt_label != null:
			prompt_label.text = "E"
			prompt_label.visible = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = false
		if prompt_label != null:
			prompt_label.visible = false

func get_portal_id() -> String:
	return portal_id
