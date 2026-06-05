extends Node2D

signal interacted(by_player: Node)
signal examine_started()
signal examine_finished()

@export var object_name: String = "Unknown Object"
@export_multiline var description: String = "Something lies here."
@export var can_pickup: bool = false
@export var pickup_item_id: String = ""
@export var is_examinable: bool = true
@export var interaction_priority: int = 0

var has_been_examined: bool = false
var interaction_count: int = 0

@onready var interaction_area: Area2D = $InteractionArea
@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
@onready var label: Label = $Label if has_node("Label") else null

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("world_object")
	if label != null:
		label.text = object_name
		label.visible = false
	print("[WorldObject] %s ready." % object_name)

func interact(player: Node) -> void:
	interaction_count += 1
	interacted.emit(self)

	if can_pickup and pickup_item_id != "":
		_pickup_item(player)
		return

	if is_examinable:
		_examine()

func _examine() -> void:
	examine_started.emit()
	has_been_examined = true
	print("[WorldObject] Examining: %s — %s" % [object_name, description])

	if DialogueManager.is_active:
		DialogueManager.close()
	else:
		DialogueManager.start_dialogue("examine_generic", object_name)

	examine_finished.emit()

func _pickup_item(player: Node) -> void:
	if GameState.has_item(pickup_item_id):
		GameState.add_item(pickup_item_id, 1)
	else:
		GameState.add_item(pickup_item_id, 1)

	print("[WorldObject] Picked up: %s" % pickup_item_id)
	queue_free()

func set_label_visible(visible: bool) -> void:
	if label != null:
		label.visible = visible

func highlight_on() -> void:
	if sprite != null:
		sprite.modulate = Color(1.2, 1.2, 1.0)

func highlight_off() -> void:
	if sprite != null:
		sprite.modulate = Color.WHITE
