extends Node
## Branch A: Voss mountain event phải lấy lịch ngày 5 từ config, tạo context
## đầy đủ và không trigger chain trùng khi world mô phỏng lại cùng ngày.

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
	await get_tree().process_frame
	var engine: Node = get_node_or_null("/root/EventChainEngine")
	var world: Node = get_node_or_null("/root/WorldSimulator")
	var schedules: Node = get_node_or_null("/root/NPCSchedules")
	_check(schedules != null and schedules.has_method("get_voss_mountain_schedule_for_day"), "NPCSchedules có API Voss mountain theo ngày")
	if schedules != null and schedules.has_method("get_voss_mountain_schedule_for_day"):
		var off_day: Dictionary = schedules.call("get_voss_mountain_schedule_for_day", 4)
		var event_day: Dictionary = schedules.call("get_voss_mountain_schedule_for_day", 5)
		_check(off_day.is_empty(), "Ngày 4 không tạo lịch Voss mountain")
		_check(int(event_day.get("event_day", -1)) == 5, "Ngày 5 lấy đúng event_day từ config")
		_check(float(event_day.get("departure_time", -1.0)) == 11.0 and float(event_day.get("fall_time", -1.0)) == 16.0, "Lịch ngày 5 giữ đúng mốc 11:00/16:00")

	if engine != null and engine.has_method("abort_chain"):
		engine.call("abort_chain", "shopkeeper_mountain", "branch_a_test_reset")
	GameState.set_flag("voss_mountain_phase", "SCHEDULED")
	GameState.set_flag("voss_mountain_event_day", 0)
	var first: Array = world.call("_evaluate_npc_schedules", 5) if world != null else []
	_check(not first.is_empty(), "WorldSimulator phát hiện event Branch A ở ngày 5")
	_check(engine != null and engine.is_chain_active("shopkeeper_mountain"), "Branch A trigger chain khi player vắng")
	if engine != null and engine.is_chain_active("shopkeeper_mountain"):
		var info: Dictionary = engine.get_chain_info("shopkeeper_mountain")
		var context: Dictionary = info.get("context", {})
		_check(int(context.get("event_day", -1)) == 5, "Context Branch A có event_day=5")
		_check(str(context.get("discovery_mode", "")) == "UNSEEN", "Context Branch A mặc định discovery UNSEEN")
		_check(float(context.get("departure_time", -1.0)) == 11.0 and float(context.get("fall_time", -1.0)) == 16.0, "Context Branch A có mốc tick đầy đủ")
	var before_count: int = engine.get_all_active_chains().size() if engine != null else 0
	world.call("_evaluate_npc_schedules", 5) if world != null else []
	var after_count: int = engine.get_all_active_chains().size() if engine != null else 0
	_check(before_count == after_count, "Mô phỏng lại ngày 5 không tạo chain thứ hai")

	print("=== VOSS BRANCH A SCHEDULE REGRESSION: %s ===" % ("PASS" if _failures == 0 else "%d FAILURES" % _failures))
	get_tree().quit(0 if _failures == 0 else 1)
