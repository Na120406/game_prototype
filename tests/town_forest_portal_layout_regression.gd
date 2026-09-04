extends Node
## Regression: Town mở rộng xuống dưới và hai cổng Forest nằm cùng mép trái,
## giữ đúng khoảng cách cao độ như Forest.

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
	var town: Node = load("res://scenes/maps/town_map.tscn").instantiate()
	var short_portal: Node2D = town.get_node("FromForestShort") as Node2D
	var long_portal: Node2D = town.get_node("FromForestLong") as Node2D
	var camera: Camera2D = town.get_node("Player/Camera2D") as Camera2D
	var walls: Node = town.get_node("Walls")

	_check(short_portal.position == Vector2(20, 60), "Forest shortcut vào Town ở mép trái phía trên")
	_check(long_portal.position == Vector2(20, 400), "Forest long-route vào Town ở mép trái phía dưới")
	_check(is_equal_approx(long_portal.position.y - short_portal.position.y, 340.0), "Khoảng cách hai cổng khớp Forest")
	_check(camera.limit_bottom == 480, "Camera Town mở rộng xuống 480 px")
	_check((walls.get_node("WallBottom") as Node2D).position.y == 478, "Collision đáy mở rộng theo map")
	_check(town.has_node("ForestLongRoad") and town.has_node("ForestLongRoadVertical"), "Long-route có hành lang dưới")
	_check(town.has_node("TownHall") and town.has_node("CentralPlaza"), "Town có công trình hành chính và quảng trường")
	_check(town.has_node("MarketDistrict/StallA") and town.has_node("MarketDistrict/StallB"), "Town có khu chợ")
	_check(town.has_node("SouthHouseA") and town.has_node("SouthHouseB"), "Khu mở rộng có nhà dân thay vì cây rừng")
	_check(not town.has_node("LowerTree1") and not town.has_node("LowerTree2"), "Đã bỏ trang trí rừng ở khu Town phía dưới")

	var town_to_farm: Array[Dictionary] = NPCRouteManager.get_route("town_to_farm")
	var farm_to_town: Array[Dictionary] = NPCRouteManager.get_route("farm_to_town")
	_check(town_to_farm[0].position == long_portal.position, "NPC rời Town qua đúng cổng long-route mới")
	_check(farm_to_town[3].position == long_portal.position, "NPC vào Town tại đúng cổng long-route mới")

	town.free()
	print("=== TOWN FOREST PORTAL LAYOUT REGRESSION: %s ===" % ("PASS" if _failures == 0 else "%d FAILURES" % _failures))
	get_tree().quit(0 if _failures == 0 else 1)
