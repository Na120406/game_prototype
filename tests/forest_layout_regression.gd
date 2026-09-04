extends Node
## Regression: Forest phải giữ topology theo bản thiết kế mới và waypoint NPC
## phải trùng chính xác với vị trí portal trong scene.

var _failures: int = 0


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	if condition:
		print("[PASS] %s" % label)
	else:
		_failures += 1
		print("[FAIL] %s" % label)


func _run() -> void:
	var forest: Node = load("res://scenes/maps/forest_map.tscn").instantiate()
	var farm_portal: Node2D = forest.get_node("ToFarm") as Node2D
	var short_portal: Node2D = forest.get_node("ToTownShort") as Node2D
	var long_portal: Node2D = forest.get_node("ToTownLong") as Node2D
	var blocker: Node2D = forest.get_node("ShortcutBlocker") as Node2D

	_check(farm_portal.position == Vector2(18, 60), "Farm spawn nằm ở góc trên-trái")
	_check(short_portal.position == Vector2(622, 60), "Town shortcut nằm ở góc trên-phải")
	_check(long_portal.position == Vector2(622, 400), "Town long-route nằm ở góc dưới-phải")
	_check(blocker.position.y == short_portal.position.y and blocker.position.x < short_portal.position.x, "Thân gỗ chắn ngay trước shortcut")
	_check(forest.has_node("RoadSurface") and forest.has_node("NPCRoadGuides"), "Đường chính có surface và guide cho NPC")
	var road_guides: Node = forest.get_node("NPCRoadGuides")
	_check(road_guides.get_child_count() == 3, "Forest có đủ ba đoạn guide theo đường dài")
	_check(forest.get_node("Walls").get_child_count() == 4, "Forest có collision biên bốn phía")

	var gathering_points: Node = forest.get_node("GatheringPoints")
	_check(gathering_points.get_child_count() == 3, "Forest có ba điểm spawn táo")
	var gathering_ids: Array[String] = []
	for point: Node in gathering_points.get_children():
		gathering_ids.append(str(point.get("gathering_id")))
		_check(bool(point.get("respawn_daily")) and is_equal_approx(float(point.get("daily_spawn_chance")), 0.25), "Mỗi điểm táo roll 25%% theo ngày")
		var apple_visual: Node = point.get_node("Visual")
		_check(apple_visual.has_node("Body") and apple_visual.has_node("Highlight") and apple_visual.has_node("Stem"), "Táo Forest dùng visual Body/Highlight/Stem như Farm")
	_check(gathering_ids.has("forest_gather_apple_1") and gathering_ids.has("forest_gather_apple_2") and gathering_ids.has("forest_gather_apple_3"), "Giữ ID cũ và thêm điểm táo thứ ba")

	var farm_to_town: Array[Dictionary] = NPCRouteManager.get_route("farm_to_town")
	_check(farm_to_town[1].position == farm_portal.position, "Waypoint NPC vào Forest khớp Farm portal")
	_check(farm_to_town[2].position == long_portal.position, "Waypoint NPC rời Forest khớp long-route portal")
	var town_to_farm: Array[Dictionary] = NPCRouteManager.get_route("town_to_farm")
	_check(town_to_farm[1].position == long_portal.position, "Waypoint NPC từ Town vào đúng long-route")
	_check(town_to_farm[2].position == farm_portal.position, "Waypoint NPC từ Forest về đúng Farm portal")

	forest.free()
	print("=== FOREST LAYOUT REGRESSION: %s ===" % ("PASS" if _failures == 0 else "%d FAILURES" % _failures))
	get_tree().quit(0 if _failures == 0 else 1)
