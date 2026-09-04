extends Node
## Hồi quy: WaterSource chỉ refill khi Watering Can đang selected; refill tốn
## 3 energy; thanh lượng nước đồng bộ trên hotbar và inventory.

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
	var original_inventory: Array = GameState.inventory.duplicate(true)
	var original_toolbar: Array = GameState.toolbar.duplicate(true)
	var original_flags: Dictionary = GameState.world_flags.duplicate(true)
	var original_energy: float = GameState.energy
	var original_selected: int = GameState.selected_toolbar_slot
	GameState.inventory.clear()
	GameState._ensure_inventory_slots()
	GameState.reset_toolbar()
	GameState.inventory[0] = {"id": "water_can", "amount": 1}
	GameState.set_toolbar_slot(0, "water_can", 1)
	GameState.selected_toolbar_slot = 0
	GameState.set_watering_can_level(2)

	var hotbar: Node = load("res://scenes/ui/hotbar.tscn").instantiate()
	var inventory_ui: Node = load("res://scenes/ui/inventory_ui.tscn").instantiate()
	var source: Node = load("res://scenes/world/water_source.tscn").instantiate()
	get_tree().root.add_child(hotbar)
	get_tree().root.add_child(inventory_ui)
	get_tree().root.add_child(source)
	await get_tree().process_frame
	await get_tree().process_frame
	GameState.energy = 10.0

	source.set("_player_nearby", true)
	source.call("refresh_interaction_state")
	_check(bool(source.get("prompt").visible), "WaterSource hiện prompt khi Watering Can selected")
	source.call("interact", null)
	_check(GameState.get_watering_can_level() == GameState.get_watering_can_max_capacity(), "Ấn E tại nguồn nước refill đầy bình")
	_check(absf(GameState.energy - 7.0) < 0.001, "Refill nước tiêu hao đúng 3 energy")

	GameState.set_watering_can_level(2)
	GameState.set_toolbar_slot(1, "axe", 1)
	GameState.selected_toolbar_slot = 1
	source.call("refresh_interaction_state")
	_check(not bool(source.get("prompt").visible), "WaterSource ẩn prompt khi selected item không phải Watering Can")
	source.call("interact", null)
	_check(GameState.get_watering_can_level() == 2, "Selected item khác không được refill")
	_check(absf(GameState.energy - 7.0) < 0.001, "Selected item khác không bị trừ energy")

	GameState.set_watering_can_level(2)
	await get_tree().process_frame
	_check(absf(float(hotbar.call("get_watering_bar_ratio", 0)) - 0.4) < 0.001, "Hotbar bar hiển thị đúng 2/5 nước")
	_check(absf(float(hotbar.call("get_watering_bar_height", 0)) - 3.0) < 0.001, "Hotbar bar chỉ cao 3px và không che icon")
	_check(absf(float(inventory_ui.call("get_watering_bar_ratio", 0)) - 0.4) < 0.001, "Inventory bar hiển thị đúng 2/5 nước")
	GameState.set_watering_can_level(4)
	await get_tree().process_frame
	_check(absf(float(hotbar.call("get_watering_bar_ratio", 0)) - 0.8) < 0.001, "Hotbar bar cập nhật sau mỗi lần tưới/refill")
	_check(absf(float(inventory_ui.call("get_watering_bar_ratio", 0)) - 0.8) < 0.001, "Inventory bar cập nhật sau mỗi lần tưới/refill")

	hotbar.queue_free()
	inventory_ui.queue_free()
	source.queue_free()
	GameState.inventory = original_inventory
	GameState.toolbar = original_toolbar
	GameState.world_flags = original_flags
	GameState.energy = original_energy
	GameState.selected_toolbar_slot = original_selected
	print("=== WATERING CAN UI REGRESSION: %s ===" % ("PASS" if _failures == 0 else "%d FAILURES" % _failures))
	get_tree().quit(0 if _failures == 0 else 1)
