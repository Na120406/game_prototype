extends Node

## Quản lý input [E] tập trung cho mọi interactable trong scene.
##
## KHÔNG render prompt ở đây — mỗi interactable tự có Label cố định
## (anchor cứng theo parent trong scene file). Manager chỉ giữ logic:
##   - register_nearby / unregister_nearby: thông báo vào/ra vùng tương tác
##   - _recompute_target: chọn 1 target duy nhất theo priority + khoảng cách
##   - try_interact: bấm E gọi interact() trên target hiện tại
##
## Lý do: render ở overlay (CanvasLayer) sẽ khiến label "trôi" theo target
## mỗi frame và dễ lệch. Label trong scene là node con của interactable,
## đi theo transform cha một cách tự nhiên → cố định.

signal target_changed(new_target: Node)
signal interact_pressed(target: Node)

const AUTOLOAD_PATH: String = "/root/InteractionPromptManager"

var _active_nearby: Array[Node] = []
var _current_target: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Một interactable gọi khi player vừa vào vùng tương tác.
func register_nearby(node: Node) -> void:
	if node == null or _active_nearby.has(node):
		return
	_active_nearby.append(node)
	_recompute_target()


## Một interactable gọi khi player vừa rời vùng tương tác.
func unregister_nearby(node: Node) -> void:
	_active_nearby.erase(node)
	if _current_target == node:
		_current_target = null
	_recompute_target()


## Một interactable (hoặc scene) gọi khi node bị queue_free()
## để manager không giữ reference rỗng.
func notify_freed(node: Node) -> void:
	if node == null:
		return
	_active_nearby.erase(node)
	if _current_target == node:
		_current_target = null
	_recompute_target()


## Input "interact" được xử lý tập trung ở đây.
## Object nào đang là target thì được gọi interact(player).
func try_interact(player: Node) -> bool:
	if _current_target == null:
		return false
	if not is_instance_valid(_current_target):
		_current_target = null
		return false
	if _current_target.has_method("interact"):
		_current_target.interact(player)
		interact_pressed.emit(_current_target)
		return true
	return false


func is_showing_prompt() -> bool:
	return _current_target != null


func get_current_target() -> Node:
	return _current_target


func _recompute_target() -> void:
	var alive: Array[Node] = []
	for n in _active_nearby:
		if is_instance_valid(n):
			alive.append(n)
	_active_nearby = alive

	if alive.is_empty():
		_current_target = null
		target_changed.emit(null)
		return

	var player: Node2D = null
	var tree: SceneTree = get_tree()
	if tree != null:
		player = tree.get_first_node_in_group("player") as Node2D

	var best: Node = null
	var best_score: float = INF

	for n in alive:
		var priority: float = 0.0
		if "interaction_priority" in n and typeof(n.interaction_priority) == TYPE_INT:
			priority = float(n.interaction_priority)

		var dist: float = 99999.0
		if player != null and n is Node2D:
			dist = (n as Node2D).global_position.distance_to(player.global_position)

		var score: float = dist - priority * 100.0
		if score < best_score:
			best_score = score
			best = n

	if best != _current_target:
		_current_target = best
		target_changed.emit(_current_target)


## Static helper: lấy instance autoload một cách an toàn.
## Dùng pattern này thay cho truy cập trực tiếp identifier ở các script
## không cùng module (tránh phụ thuộc parse order của Godot).
static func get_instance() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var root: Window = tree.root
	if root == null:
		return null
	return root.get_node_or_null(AUTOLOAD_PATH)
