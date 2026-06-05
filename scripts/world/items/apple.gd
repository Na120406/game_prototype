extends StaticBody2D

const INTERACT_DISTANCE: float = 30.0

@onready var prompt: Label = $Prompt

var _player: Node = null
var _player_nearby: bool = false
var _collected: bool = false

func _ready() -> void:
	prompt.visible = false
	_player = get_tree().get_first_node_in_group("player")
	_set_prompt_visible(false)

func is_player_nearby() -> bool:
	if _collected:
		return false
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		return false
	return global_position.distance_to(_player.global_position) <= INTERACT_DISTANCE

func _process(_delta: float) -> void:
	if _collected:
		return
	var nearby := is_player_nearby()
	if nearby != _player_nearby:
		_player_nearby = nearby
		_set_prompt_visible(nearby)

func _set_prompt_visible(v: bool) -> void:
	if prompt != null:
		prompt.visible = v

func interact(_player_ref: Node) -> void:
	if _collected:
		return
	_collect()

func _collect() -> void:
	_collected = true
	_set_prompt_visible(false)
	ItemManager.on_item_pickup("apple")
	queue_free()
