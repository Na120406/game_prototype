extends Node
## Regression: NPC bám mạng ColorRect đường và fallback đi thẳng ở map không
## có đường được vẽ/đánh dấu.

const RoadPathfinder = preload("res://scripts/npc/npc_road_pathfinder.gd")

var _failures: int = 0


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	if condition:
		print("[PASS] %s" % label)
	else:
		_failures += 1
		print("[FAIL] %s" % label)


func _make_rect(parent: Node, node_name: String, rect: Rect2, road_group: bool) -> ColorRect:
	var node := ColorRect.new()
	node.name = node_name
	node.position = rect.position
	node.size = rect.size
	parent.add_child(node)
	if road_group:
		node.add_to_group("npc_road")
	return node


func _path_stays_on_road(root: Node, path: PackedVector2Array) -> bool:
	if path.size() < 2:
		return false
	for index: int in range(path.size() - 1):
		for sample_index: int in range(11):
			var weight: float = float(sample_index) / 10.0
			var sample: Vector2 = path[index].lerp(path[index + 1], weight)
			if not RoadPathfinder.is_point_on_road(root, sample, 0.5):
				return false
	return true


func _run() -> void:
	var road_map := Node2D.new()
	road_map.name = "RoadMap"
	add_child(road_map)
	_make_rect(road_map, "HorizontalRoad", Rect2(10, 40, 120, 24), true)
	_make_rect(road_map, "VerticalRoad", Rect2(106, 40, 24, 130), true)
	road_map.set_meta("world_scene_path", "test://road_map")
	var road_path: PackedVector2Array = RoadPathfinder.build_path(road_map, Vector2(20, 52), Vector2(118, 156))
	_check(road_path.size() >= 3, "Tạo waypoint qua mạng ColorRect hình chữ L")
	_check(_path_stays_on_road(road_map, road_path), "Các đoạn trung gian luôn nằm trên đường")

	var npc_script: Script = load("res://scripts/npc/npc.gd")
	var npc := npc_script.new() as CharacterBody2D
	npc.npc_id = "road_tracking_test"
	npc.move_speed = 120.0
	npc.acceleration = 2400.0
	road_map.add_child(npc)
	npc.global_position = Vector2(20, 52)
	npc.set("_target_pos", Vector2(118, 156))
	var first_movement_target: Vector2 = npc.call("_get_road_movement_target")
	_check(first_movement_target != Vector2(118, 156), "NPC lấy waypoint đường trước target lịch trình")
	var stayed_on_road: bool = true
	for frame: int in range(180):
		await get_tree().physics_frame
		if not RoadPathfinder.is_point_on_road(road_map, npc.global_position, 2.0):
			stayed_on_road = false
		if npc.global_position.distance_to(Vector2(118, 156)) <= npc.waypoint_reach_distance:
			break
	_check(stayed_on_road, "NPC không cắt góc ra ngoài ColorRect đường")
	_check(npc.global_position.distance_to(Vector2(118, 156)) <= npc.waypoint_reach_distance + 1.0, "NPC đi hết tuyến và tới đúng vị trí yêu cầu")
	npc.queue_free()

	var free_map := Node2D.new()
	free_map.name = "FreeMap"
	free_map.set_meta("world_scene_path", "test://free_map")
	add_child(free_map)
	_make_rect(free_map, "Ground", Rect2(0, 0, 200, 200), false)
	var free_path: PackedVector2Array = RoadPathfinder.build_path(free_map, Vector2(10, 10), Vector2(180, 180))
	_check(free_path.is_empty(), "Map không có ColorRect đường dùng di chuyển tự do")
	var free_npc := npc_script.new() as CharacterBody2D
	free_npc.npc_id = "free_movement_test"
	free_map.add_child(free_npc)
	free_npc.global_position = Vector2(10, 10)
	free_npc.set("_target_pos", Vector2(180, 180))
	_check(free_npc.call("_get_road_movement_target") == Vector2(180, 180), "NPC fallback trực tiếp tới vị trí yêu cầu")
	free_npc.queue_free()

	var inferred_map := Node2D.new()
	inferred_map.name = "InferredMap"
	add_child(inferred_map)
	_make_rect(inferred_map, "VillageRoad", Rect2(0, 80, 200, 24), false)
	var inferred_path: PackedVector2Array = RoadPathfinder.build_path(inferred_map, Vector2(10, 92), Vector2(190, 92))
	_check(not inferred_path.is_empty(), "Tự nhận diện ColorRect có tên Road khi chưa gắn group")

	var farm: Node = load("res://scenes/maps/farm_map.tscn").instantiate()
	var town: Node = load("res://scenes/maps/town_map.tscn").instantiate()
	var forest: Node = load("res://scenes/maps/forest_map.tscn").instantiate()
	_check(_count_marked_roads(farm) == 6, "Farm đánh dấu đủ 6 đoạn đường cho Marcus")
	_check(_count_marked_roads(town) >= 9, "Town đánh dấu mạng đường cho Marcus")
	_check(_count_marked_roads(forest) == 3, "Forest có ba guide bám sát đường Polygon2D")
	var farm_route: PackedVector2Array = RoadPathfinder.build_path(farm, Vector2(85, 200), Vector2(630, 300))
	var town_route: PackedVector2Array = RoadPathfinder.build_path(town, Vector2(20, 400), Vector2(430, 110))
	var forest_route: PackedVector2Array = RoadPathfinder.build_path(forest, Vector2(18, 60), Vector2(622, 400))
	_check(farm_route.size() >= 4 and farm_route[-1] == Vector2(630, 300), "Marcus bám đường Farm tới cổng Forest")
	_check(town_route.size() >= 4 and town_route[-1] == Vector2(430, 110), "Marcus bám đường Town từ cổng dưới tới lịch trình")
	_check(town_route.size() >= 2 and RoadPathfinder.is_point_on_road(town, town_route[-2], 0.5), "Marcus chỉ rời đường ở đoạn cuối tới vị trí yêu cầu")
	_check(forest_route.size() >= 4 and forest_route[-1] == Vector2(622, 400), "Marcus đi đúng nhánh dài qua Forest")
	_check(_path_stays_on_road(forest, forest_route), "Tuyến Forest không cắt ngang khu vực cây")
	farm.free()
	town.free()
	forest.free()
	road_map.queue_free()
	free_map.queue_free()
	inferred_map.queue_free()

	print("=== NPC ROAD TRACKING REGRESSION: %s ===" % ("PASS" if _failures == 0 else "%d FAILURES" % _failures))
	get_tree().quit(0 if _failures == 0 else 1)


func _count_marked_roads(root: Node) -> int:
	var count: int = 0
	for node: Node in root.find_children("*", "ColorRect", true, false):
		if node.is_in_group("npc_road"):
			count += 1
	return count
