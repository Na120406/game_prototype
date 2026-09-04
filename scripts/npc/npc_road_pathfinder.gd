class_name NPCRoadPathfinder
extends RefCounted
## Tạo tuyến di chuyển bám theo các ColorRect biểu diễn đường trong map.
## Map có thể đánh dấu đường bằng group `npc_road`; nếu chưa đánh dấu, helper
## nhận diện theo tên Road/Street/Path và loại các node Trim/Border mỏng.

const ROAD_GROUP: StringName = &"npc_road"
const ROAD_JOIN_TOLERANCE: float = 3.0
const MIN_ROAD_THICKNESS: float = 8.0


static func build_path(scene_root: Node, from_position: Vector2, target_position: Vector2) -> PackedVector2Array:
	var road_rects: Array[Rect2] = _collect_road_rects(scene_root)
	if road_rects.is_empty():
		return PackedVector2Array()

	var start_index: int = _find_closest_rect(road_rects, from_position)
	if start_index < 0:
		return PackedVector2Array()

	# Duyệt toàn bộ thành phần đường nối với điểm xuất phát. Nếu đoạn gần đích
	# bị tách rời, Marcus vẫn bám phần đường có thể tới rồi mới rời đường.
	var parents: Array[int] = []
	parents.resize(road_rects.size())
	parents.fill(-2)
	parents[start_index] = -1
	var queue: Array[int] = [start_index]
	var cursor: int = 0
	while cursor < queue.size():
		var current_index: int = queue[cursor]
		cursor += 1
		for candidate_index: int in range(road_rects.size()):
			if parents[candidate_index] != -2:
				continue
			if _are_connected(road_rects[current_index], road_rects[candidate_index]):
				parents[candidate_index] = current_index
				queue.append(candidate_index)

	var end_index: int = start_index
	var best_distance: float = _distance_squared_to_rect(road_rects[start_index], target_position)
	for index: int in range(road_rects.size()):
		if parents[index] == -2:
			continue
		var distance: float = _distance_squared_to_rect(road_rects[index], target_position)
		if distance < best_distance:
			best_distance = distance
			end_index = index

	var rect_chain: Array[int] = []
	var chain_index: int = end_index
	while chain_index >= 0:
		rect_chain.push_front(chain_index)
		chain_index = parents[chain_index]

	var points: Array[Vector2] = []
	_append_unique(points, _closest_point_on_rect(road_rects[rect_chain[0]], from_position))
	for index: int in range(rect_chain.size() - 1):
		var current_rect: Rect2 = road_rects[rect_chain[index]]
		var next_rect: Rect2 = road_rects[rect_chain[index + 1]]
		_append_unique(points, _connection_point(current_rect, next_rect))
	_append_unique(points, _closest_point_on_rect(road_rects[end_index], target_position))
	# Chỉ đoạn cuối được phép rời ColorRect để tới đúng vị trí lịch trình.
	_append_unique(points, target_position)
	return PackedVector2Array(points)


static func is_point_on_road(scene_root: Node, point: Vector2, tolerance: float = 0.0) -> bool:
	for rect: Rect2 in _collect_road_rects(scene_root):
		if rect.grow(tolerance).has_point(point):
			return true
	return false


static func _collect_road_rects(scene_root: Node) -> Array[Rect2]:
	var result: Array[Rect2] = []
	if scene_root == null:
		return result
	var explicit_roads: Array[ColorRect] = []
	var inferred_roads: Array[ColorRect] = []
	for raw_node: Node in scene_root.find_children("*", "ColorRect", true, false):
		var rect_node := raw_node as ColorRect
		if rect_node == null:
			continue
		if rect_node.is_in_group(ROAD_GROUP):
			explicit_roads.append(rect_node)
		elif _looks_like_road(rect_node):
			inferred_roads.append(rect_node)
	var selected: Array[ColorRect] = explicit_roads if not explicit_roads.is_empty() else inferred_roads
	for road: ColorRect in selected:
		var rect: Rect2 = road.get_global_rect()
		if minf(absf(rect.size.x), absf(rect.size.y)) < MIN_ROAD_THICKNESS:
			continue
		result.append(rect.abs())
	return result


static func _looks_like_road(node: ColorRect) -> bool:
	var lowered_name: String = String(node.name).to_lower()
	if lowered_name.contains("trim") or lowered_name.contains("border") or lowered_name.contains("marker"):
		return false
	return lowered_name.contains("road") or lowered_name.contains("street") or lowered_name.contains("path")


static func _find_closest_rect(rects: Array[Rect2], point: Vector2) -> int:
	var best_index: int = -1
	var best_distance: float = INF
	for index: int in range(rects.size()):
		var distance: float = _distance_squared_to_rect(rects[index], point)
		if distance < best_distance:
			best_distance = distance
			best_index = index
	return best_index


static func _distance_squared_to_rect(rect: Rect2, point: Vector2) -> float:
	return point.distance_squared_to(_closest_point_on_rect(rect, point))


static func _closest_point_on_rect(rect: Rect2, point: Vector2) -> Vector2:
	return Vector2(
		clampf(point.x, rect.position.x, rect.end.x),
		clampf(point.y, rect.position.y, rect.end.y)
	)


static func _are_connected(first: Rect2, second: Rect2) -> bool:
	return first.grow(ROAD_JOIN_TOLERANCE).intersects(second.grow(ROAD_JOIN_TOLERANCE), true)


static func _connection_point(first: Rect2, second: Rect2) -> Vector2:
	var overlap: Rect2 = first.intersection(second)
	if overlap.size.x > 0.0 and overlap.size.y > 0.0:
		return overlap.get_center()
	var first_edge: Vector2 = _closest_point_on_rect(first, second.get_center())
	var second_edge: Vector2 = _closest_point_on_rect(second, first.get_center())
	return (first_edge + second_edge) * 0.5


static func _append_unique(points: Array[Vector2], point: Vector2) -> void:
	if points.is_empty() or not points[-1].is_equal_approx(point):
		points.append(point)
