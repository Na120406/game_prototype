extends Node
## Regression: cùng một portal bị gọi hai lần trong một frame chỉ được cộng
## traversal cost đúng một lần.

var _failures: int = 0
var _farm_day_events: int = 0


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	if condition:
		print("[PASS] %s" % label)
	else:
		_failures += 1
		print("[FAIL] %s" % label)


func _on_farm_day_changed(_day: int) -> void:
	_farm_day_events += 1


func _run() -> void:
	var portal_script: Script = load("res://scripts/world/world_transition.gd")
	var portal: Area2D = portal_script.new()
	portal.set("portal_id", "portal_forest_long_to_town")
	portal.set("target_scene", "res://scenes/maps/town_map.tscn")
	get_tree().root.add_child(portal)
	await get_tree().process_frame

	GameState.current_day = 10
	GameState.current_time = 23.0
	GameState.energy = 42.0
	var before: float = GameState.current_time
	var before_day: int = GameState.current_day
	var before_energy: float = GameState.energy
	portal.call("_change_scene")
	portal.call("_change_scene")
	var elapsed: float = fposmod(GameState.current_time - before, 24.0)
	var expected: float = float(ConfigManager.get_forest_long_route_time())
	_check(absf(elapsed - expected) < 0.0001, "Traversal cost chỉ áp dụng đúng một lần")
	_check(GameState.current_day == before_day, "Traversal qua nửa đêm không tự tăng ngày")
	_check(absf(GameState.energy - before_energy) < 0.0001, "Traversal qua nửa đêm không hồi năng lượng")
	_check(absf(fposmod(GameState.current_time, 24.0) - 0.5) < 0.0001, "23:00 + 1,5 giờ giữ đúng phần dư 00:30")

	# Travel phải đi qua cùng boundary pipeline với clock realtime.
	GameState.current_day = 20
	GameState.current_time = 5.0
	GameState.energy = 42.0
	if not GameState.farm_day_changed.is_connected(_on_farm_day_changed):
		GameState.farm_day_changed.connect(_on_farm_day_changed)
	var dawn_portal: Area2D = portal_script.new()
	get_tree().root.add_child(dawn_portal)
	dawn_portal.call("_apply_traversal_cost", expected)
	_check(GameState.current_day == 21, "Travel qua 06:00 kích hoạt day/farm boundary")
	_check(_farm_day_events == 1, "Travel qua 06:00 emit đúng một farm day tick")
	_check(absf(GameState.current_time - 6.5) < 0.0001, "Travel qua 06:00 giữ đủ phần dư chi phí tới 06:30")

	GameState.current_time = 0.5
	var afk_portal: Area2D = portal_script.new()
	get_tree().root.add_child(afk_portal)
	afk_portal.call("_apply_traversal_cost", expected)
	_check(bool(EnergyManager.get("_knock_out_active")), "Travel qua 01:00 kích hoạt AFK boundary")

	if _failures == 0:
		print("=== PORTAL COST ONCE REGRESSION: PASS ===")
	else:
		print("=== PORTAL COST ONCE REGRESSION: %d FAILURES ===" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
