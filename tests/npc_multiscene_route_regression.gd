extends Node
## Regression: route Farm -> Forest -> Town phải giữ route khi tới Forest và
## chỉ hoàn tất sau khi Marcus tới Town.

const FARM_SCENE := "res://scenes/maps/farm_map.tscn"
const FOREST_SCENE := "res://scenes/maps/forest_map.tscn"
const TOWN_SCENE := "res://scenes/maps/town_map.tscn"

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
	var original_time: float = GameState.current_time
	GameState.current_time = 8.0

	var source_world := Node2D.new()
	source_world.name = "RouteRegressionSource"
	source_world.set_meta("world_scene_path", FARM_SCENE)
	get_tree().root.add_child(source_world)

	var npc_script: Script = load("res://scripts/npc/npc.gd")
	var marcus := npc_script.new() as CharacterBody2D
	marcus.npc_id = "route_regression_marcus"
	source_world.add_child(marcus)
	await get_tree().process_frame

	var route: Array[Dictionary] = NPCRouteManager.get_route("farm_to_town")
	var day1_schedule: Array[Dictionary] = [
		{"time": 7.0, "state": 1, "action": "leave_player_farm", "scene": FARM_SCENE, "pos": route[0].position, "route_id": "farm_to_town"},
		{"time": 7.1, "state": 1, "action": "arrive_in_town", "scene": TOWN_SCENE, "pos": Vector2(430, 110), "route_id": "farm_to_town"},
	]
	marcus.schedule = day1_schedule
	marcus.set_route("farm_to_town", route, 0)
	marcus.global_position = route[0].position

	marcus.call("_advance_route_if_reached")
	_check(str(marcus.get_meta("world_scene_path")) == FOREST_SCENE, "Marcus handoff từ Farm sang Forest")
	_check(marcus.active_route_id == "farm_to_town", "Route vẫn hoạt động khi tới Forest")
	_check(marcus.active_route_index == 1, "Forest entry là waypoint trung gian hiện tại")
	_check(marcus.active_route.size() == 4, "Không xóa route nhiều scene tại Forest")

	marcus.global_position = route[1].position
	marcus.call("_advance_route_if_reached")
	_check(marcus.active_route_index == 2, "Marcus tiếp tục đi tới cổng Town trong Forest")
	_check(marcus.get("_target_pos") == route[2].position, "Target trong Forest là long-route portal")

	marcus.global_position = route[2].position
	marcus.call("_advance_route_if_reached")
	_check(str(marcus.get_meta("world_scene_path")) == TOWN_SCENE, "Marcus handoff từ Forest sang Town")
	_check(marcus.active_route_id == "" and marcus.active_route.is_empty(), "Route chỉ hoàn tất tại Town")
	_check(marcus.get("_target_pos") == Vector2(430, 110), "Marcus tiếp tục bước lịch trình ngày 1 trong Town")

	GameState.current_time = original_time
	marcus.queue_free()
	source_world.queue_free()
	await get_tree().process_frame

	print("=== NPC MULTI-SCENE ROUTE REGRESSION: %s ===" % ("PASS" if _failures == 0 else "%d FAILURES" % _failures))
	get_tree().quit(0 if _failures == 0 else 1)
