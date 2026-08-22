extends Node

# Quản lý "focus" của UI: khi một popup/backdrop hiện, các UI phụ (energy bar,
# day info, gold, hotbar, time HUD,...) được làm mờ để backdrop và panel chính
# nổi bật. Khi popup đóng, các UI phụ trở lại bình thường.

const _DIM_MODULATE := Color(0.45, 0.45, 0.5, 1.0)
const _NORMAL_MODULATE := Color(1, 1, 1, 1)

var _ref_count: int = 0
var _original_modulates: Dictionary = {}

func dim_background(dim: bool) -> void:
	if dim:
		_ref_count += 1
		if _ref_count > 1:
			return
		_apply_dim_to_all()
	else:
		_ref_count = max(0, _ref_count - 1)
		if _ref_count > 0:
			return
		_restore_all()

func _collect_targets() -> Array:
	var out: Array = []
	var root := get_tree().root if get_tree() != null else null
	if root == null:
		return out
	var seen: Dictionary = {}
	for child in root.get_children():
		_walk(child, out, seen)
	return out

func _walk(node: Node, out: Array, seen: Dictionary) -> void:
	if node == null:
		return
	if seen.has(node.get_instance_id()):
		return
	seen[node.get_instance_id()] = true

	if _is_background_widget(node):
		out.append(node)

	for child in node.get_children():
		_walk(child, out, seen)

func _is_background_widget(node: Node) -> bool:
	if not (node is CanvasItem):
		return false
	if node is CanvasLayer:
		return false
	# Energy bar: scene root EnergyBar
	if node.name == "EnergyBar" and node is Control:
		return true
	# Day info container ở UI canvas
	if node.name == "DayInfo" and node is Control:
		return true
	# Map label nhỏ ở góc
	if node.name == "MapLabel" and node is Label:
		return true
	# Hotbar (là Control)
	if node.is_in_group("hotbar"):
		return true
	return false

func _apply_dim_to_all() -> void:
	_original_modulates.clear()
	for n in _collect_targets():
		var ci: CanvasItem = n
		_original_modulates[ci.get_instance_id()] = ci.modulate
		ci.modulate = _DIM_MODULATE

func _restore_all() -> void:
	for n in _collect_targets():
		var ci: CanvasItem = n
		var id := ci.get_instance_id()
		if _original_modulates.has(id):
			ci.modulate = _original_modulates[id]
		else:
			ci.modulate = _NORMAL_MODULATE
	_original_modulates.clear()
