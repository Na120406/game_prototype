extends Area2D

@export var portal_id: String = ""
@export var target_scene: String = ""
@export var transition_type: String = "instant"
@export var prompt: String = "E"

var _player_inside: bool = false

@onready var prompt_label: Label = $Prompt

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if prompt_label != null:
		prompt_label.visible = false

func _process(_delta: float) -> void:
	if _player_inside and Input.is_action_just_pressed("interact"):
		_change_scene()

func _change_scene() -> void:
	if target_scene == "":
		return
	SceneManager.change_scene(target_scene, portal_id)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = true
		if prompt_label != null:
			prompt_label.text = prompt
			prompt_label.visible = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = false
		if prompt_label != null:
			prompt_label.visible = false

func get_portal_id() -> String:
	return portal_id
