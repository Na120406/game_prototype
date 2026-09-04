extends Node
## Regression: shortcut portal phải tự enforce canonical flag, không phụ thuộc
## việc TreeBlocker có thể bị player đi vòng trên placeholder map.

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
	GameState.set_flag(GameState.FOREST_SHORTCUT_CLEARED_KEY, false)
	GameState.current_time = 12.0

	var portal_script: Script = load("res://scripts/world/world_transition.gd")
	var portal: Area2D = portal_script.new()
	portal.set("portal_id", "portal_forest_short_to_town")
	portal.set("target_scene", "res://scenes/maps/town_map.tscn")
	get_tree().root.add_child(portal)
	await get_tree().process_frame

	var before: float = GameState.current_time
	portal.call("_change_scene")
	_check(absf(GameState.current_time - before) < 0.0001, "Shortcut bị khóa không cộng traversal cost")
	_check(not bool(portal.get("_traversal_cost_applied")), "Shortcut bị khóa vẫn cho thử lại sau khi clear")

	var town_portal: Area2D = portal_script.new()
	town_portal.set("portal_id", "portal_town_to_forest_short")
	town_portal.set("target_scene", "res://scenes/maps/forest_map.tscn")
	get_tree().root.add_child(town_portal)
	await get_tree().process_frame
	_check(not bool(town_portal.call("can_traverse")), "Cổng Town phía trên cũng bị khóa bởi thân gỗ")
	town_portal.call("_show_locked_feedback")
	var warning: Node = get_node_or_null("/root/FloatingWarning")
	var warning_label: Label = warning.get("_current_label") as Label if warning != null else null
	_check(warning_label != null and warning_label.text == "đường này bị chặn rồi", "Cổng Town hiện đúng thông báo đường bị chặn")

	GameState.clear_forest_shortcut()
	_check(portal.has_method("can_traverse") and bool(portal.call("can_traverse")), "Shortcut mở khi canonical flag đã clear")
	_check(bool(town_portal.call("can_traverse")), "Cổng Town mở đồng bộ sau khi dọn thân gỗ")
	portal.queue_free()
	town_portal.queue_free()
	GameState.world_flags = original_flags

	if _failures == 0:
		print("=== FOREST SHORTCUT GATE REGRESSION: PASS ===")
	else:
		print("=== FOREST SHORTCUT GATE REGRESSION: %d FAILURES ===" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
