extends Node
## Regression: mỗi điểm táo có một roll độc lập cho từng ngày, kết quả ổn định
## trong ngày và trạng thái thu thập không cộng dồn sang ngày kế tiếp.

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
	var original_flags: Dictionary = GameState.world_flags.duplicate(true)
	var id := "daily_spawn_regression_point"

	# Biên xác suất giúp test không phụ thuộc random seed: 0% luôn vắng,
	# 100% luôn xuất hiện. Gọi lặp lại trong cùng ngày phải giữ cùng kết quả.
	var day1_first: bool = GameState.roll_daily_gathering_spawn(id, 1, 0.0)
	var day1_repeat: bool = GameState.roll_daily_gathering_spawn(id, 1, 1.0)
	_check(not day1_first and not day1_repeat, "Roll ngày 1 ổn định và tôn trọng kết quả đã lưu")

	var day2_first: bool = GameState.roll_daily_gathering_spawn(id, 2, 1.0)
	var day2_repeat: bool = GameState.roll_daily_gathering_spawn(id, 2, 0.0)
	_check(day2_first and day2_repeat, "Roll ngày 2 ổn định ở 100%")
	GameState.mark_daily_gathering_collected(id, 2)
	_check(GameState.is_daily_gathering_collected(id, 2), "Điểm táo lưu trạng thái đã nhặt trong ngày")

	_check(not GameState.is_daily_gathering_collected(id, 3), "Sang ngày mới trạng thái nhặt được reset")
	var day3_spawn: bool = GameState.roll_daily_gathering_spawn(id, 3, 1.0)
	_check(day3_spawn, "Điểm táo có thể spawn lại ở ngày mới")

	GameState.world_flags = original_flags
	print("=== DAILY GATHERING SPAWN REGRESSION: %s ===" % ("PASS" if _failures == 0 else "%d FAILURES" % _failures))
	get_tree().quit(0 if _failures == 0 else 1)
