extends Node
## Regression: FarmMap compact 640×480 và khu trồng chỉ còn 20×10 ô.

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
	var farm: Node = load("res://scenes/maps/farm_map.tscn").instantiate()
	var plot: Node = farm.get_node("FarmPlot")
	var camera: Camera2D = farm.get_node("Player/Camera2D") as Camera2D
	var portal: Node2D = farm.get_node("ToForest") as Node2D
	var horizontal_shape: RectangleShape2D = farm.get_node("Walls/WallBottom/CollisionShape2D").shape as RectangleShape2D
	var vertical_shape: RectangleShape2D = farm.get_node("Walls/WallRight/CollisionShape2D").shape as RectangleShape2D

	_check(camera.limit_right == 640 and camera.limit_bottom == 480, "Camera Farm thu còn 640×480")
	_check(horizontal_shape.size == Vector2(640, 4) and vertical_shape.size == Vector2(4, 480), "Collision biên khớp map compact")
	_check((farm.get_node("Walls/WallBottom") as Node2D).position == Vector2(320, 478), "Biên dưới nằm đúng đáy map")
	_check(portal.position == Vector2(630, 300), "Cổng Forest được dời vào mép phải mới")
	var fence_collisions: Node = farm.get_node("FenceCollisions")
	_check(fence_collisions.get_child_count() == 5, "Hàng rào Farm có đủ năm đoạn collision")
	var fence_top: RectangleShape2D = fence_collisions.get_node("Top/CollisionShape2D").shape as RectangleShape2D
	var fence_left: RectangleShape2D = fence_collisions.get_node("Left/CollisionShape2D").shape as RectangleShape2D
	var fence_right_top: RectangleShape2D = fence_collisions.get_node("RightTop/CollisionShape2D").shape as RectangleShape2D
	var fence_right_bottom: RectangleShape2D = fence_collisions.get_node("RightBottom/CollisionShape2D").shape as RectangleShape2D
	_check(fence_top.size == Vector2(328, 4) and fence_left.size == Vector2(4, 168), "Collision hàng rào ôm đúng biên trên/trái")
	_check(fence_right_top.size == Vector2(4, 120) and fence_right_bottom.size == Vector2(4, 21), "Collision hàng rào chừa lối vào theo đường")

	var farm_zone: Rect2 = plot.call("get_farm_zone")
	_check(farm_zone == Rect2(24, 274, 320, 160), "Khu trồng thu còn 320×160 px")
	_check(plot.call("get_grid_dimensions") == Vector2i(20, 10), "Khu trồng có đúng 20×10 ô")
	_check(bool(plot.call("is_cell_inside_farm_zone", Vector2i(19, 9))), "Ô cuối cùng trong grid vẫn hợp lệ")
	_check(not bool(plot.call("is_cell_inside_farm_zone", Vector2i(20, 9))), "Không thể trồng vượt cạnh phải")
	_check(not bool(plot.call("is_cell_inside_farm_zone", Vector2i(19, 10))), "Không thể trồng vượt cạnh dưới")
	_check(bool(plot.call("_is_cell_blocked_by_tree", Vector2i(20, 0))), "API farming chặn cell ngoài vùng compact")
	var plot_children_before: int = plot.get_child_count()
	plot.call("_show_soil_visual", Vector2i(20, 0), {"state": 1})
	_check(plot.get_child_count() == plot_children_before, "Không render đất của save cũ ngoài vùng mới")
	var crop_visual: Node = farm.get_node("CropVisualManager")
	var crop_children_before: int = crop_visual.get_child_count()
	crop_visual.call("_spawn_sprite", Vector2i(20, 0), {"state": 2, "growth_progress": 0.0})
	_check(crop_visual.get_child_count() == crop_children_before, "Không render cây của save cũ ngoài vùng mới")

	var field_backdrop: ColorRect = farm.get_node("Tree5") as ColorRect
	_check(field_backdrop.get_rect() == Rect2(22, 272, 324, 164), "Nền đất nằm gọn trong hàng rào khu trồng mới")
	var route_to_town: Array[Dictionary] = NPCRouteManager.get_route("farm_to_town")
	var route_to_farm: Array[Dictionary] = NPCRouteManager.get_route("town_to_farm")
	_check(route_to_town[0].position == portal.position and route_to_farm[-1].position == portal.position, "Waypoint Marcus đồng bộ cổng Farm mới")

	farm.free()
	print("=== FARM COMPACT LAYOUT REGRESSION: %s ===" % ("PASS" if _failures == 0 else "%d FAILURES" % _failures))
	get_tree().quit(0 if _failures == 0 else 1)
