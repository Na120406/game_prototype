extends Node2D

signal tool_used(tool_name: String)
signal tool_hit_something(tool_name: String, what: Node)
signal not_enough_energy()

@export var tool_name: String = "Hoe"
@export var tool_id: String = "hoe"
@export var stamina_cost: float = 10.0
@export var range_distance: float = 20.0

var is_equipped: bool = false
var is_using: bool = false

@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
@onready var animation_player: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null

func _ready() -> void:
	print("[Tool] %s ready (id: %s, stamina cost: %.0f)" % [tool_name, tool_id, stamina_cost])

func equip() -> void:
	is_equipped = true
	var handler := get_node_or_null("/root/ToolHandler")
	if handler != null:
		handler.equip(tool_id)
	else:
		push_warning("[Tool] ToolHandler autoload is unavailable.")
	print("[Tool] Equipped: %s" % tool_name)

func unequip() -> void:
	is_equipped = false
	var handler := get_node_or_null("/root/ToolHandler")
	if handler != null:
		handler.unequip()
	else:
		push_warning("[Tool] ToolHandler autoload is unavailable.")
	print("[Tool] Unequipped: %s" % tool_name)

func use(target_pos: Vector2 = Vector2.ZERO) -> bool:
	if is_using:
		return false

	if GameState.energy < stamina_cost:
		not_enough_energy.emit()
		print("[Tool] Not enough energy to use %s (need %.0f, have %.0f)" % [tool_name, stamina_cost, GameState.energy])
		return false

	is_using = true
	GameState.modify_energy(-stamina_cost)
	tool_used.emit(tool_name)

	if animation_player != null and animation_player.has_animation("use"):
		animation_player.play("use")
		await animation_player.animation_finished

	is_using = false
	return true

func get_tool_id() -> String:
	return tool_id

func get_stamina_cost() -> float:
	return stamina_cost
