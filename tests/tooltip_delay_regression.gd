extends Node
## Regression: Inventory, Shop/Hotbar và EnergyBar dùng chung thời gian hover
## của tooltip vật phẩm trong Inventory.

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
	var expected: float = ConfigManager.get_tooltip_hover_delay()
	_check(is_equal_approx(expected, 0.3), "Delay tooltip cấu hình đúng 0,3 giây")

	var inventory: Node = load("res://scenes/ui/inventory_ui.tscn").instantiate()
	get_tree().root.add_child(inventory)
	await get_tree().process_frame
	var inventory_timer: Timer = inventory.get("_tooltip_timer") as Timer
	_check(inventory_timer != null and is_equal_approx(inventory_timer.wait_time, expected), "Inventory dùng delay tooltip chuẩn")

	var shop: Node = load("res://scenes/ui/shop_ui.tscn").instantiate()
	get_tree().root.add_child(shop)
	await get_tree().process_frame
	_check(is_equal_approx(float(shop.call("_get_tooltip_hover_delay")), expected), "Shop và Hotbar dùng cùng delay Inventory")
	_check(is_equal_approx(float(EnergyBar.call("_get_tooltip_hover_delay")), expected), "EnergyBar dùng cùng delay Inventory")

	inventory.queue_free()
	shop.queue_free()
	print("=== TOOLTIP DELAY REGRESSION: %s ===" % ("PASS" if _failures == 0 else "%d FAILURES" % _failures))
	get_tree().quit(0 if _failures == 0 else 1)
