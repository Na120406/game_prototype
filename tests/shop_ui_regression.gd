extends Node
## Regression: Shop UI có kích thước cố định và tooltip tab Mua hoạt động
## ngay lần mở đầu tiên.

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
	GameState.inventory.clear()
	GameState._ensure_inventory_slots()
	GameState.inventory[0] = {"id": "apple", "amount": 3}

	var shop: Node = load("res://scenes/ui/shop_ui.tscn").instantiate()
	get_tree().root.add_child(shop)
	await get_tree().process_frame
	await get_tree().process_frame

	var win: Control = shop.get_node("Win") as Control
	_check(win != null and win.size == Vector2(220, 176), "Shop Win giữ kích thước cố định 220×176")

	shop.call("open", 200)
	await get_tree().process_frame
	await get_tree().process_frame
	var rows: VBoxContainer = shop.get_node("Win/Col/ItemsScroll/Margin/ItemsList") as VBoxContainer
	_check(rows != null and rows.get_child_count() > 0, "Tab Mua dựng danh sách ngay khi mở shop")
	var buy_action_end: float = -1.0
	var buy_row: Node = null
	if rows != null and rows.get_child_count() > 0:
		buy_row = rows.get_child(0)
		buy_action_end = (buy_row.get_node("ActionZone") as Control).get_global_rect().end.x
	shop.call("_on_tab_sell")
	await get_tree().process_frame
	await get_tree().process_frame
	var sell_row: Node = rows.get_child(0) if rows != null and rows.get_child_count() > 0 else null
	var sell_hover: Control = sell_row.get_node("HoverZone") as Control if sell_row != null else null
	var sell_action: Control = sell_row.get_node("ActionZone") as Control if sell_row != null else null
	_check(sell_hover != null and sell_hover.get_child_count() == 3 and str((sell_hover.get_child(2) as Label).text) == "x3", "Bộ đếm số lượng nằm cạnh tên item")
	_check(sell_action != null and sell_action.get_child_count() == 2 and sell_action.get_child(1) is Button, "Hàng Bán chỉ giữ giá và nút ở vùng phải")
	if sell_action != null and buy_action_end >= 0.0:
		_check(is_equal_approx(sell_action.get_global_rect().end.x, buy_action_end), "Giá và nút Bán thẳng cột với hàng Mua")
	shop.call("_on_tab_buy")
	await get_tree().process_frame
	await get_tree().process_frame
	rows = shop.get_node("Win/Col/ItemsScroll/Margin/ItemsList") as VBoxContainer
	var hover_zone: Control = null
	if rows != null:
		for row: Node in rows.get_children():
			var candidate: Control = row.find_child("HoverZone", true, false) as Control
			if candidate != null:
				hover_zone = candidate
				break
	var mouse_pos := hover_zone.get_global_rect().get_center() if hover_zone != null else Vector2.ZERO
	var item_data: ItemData = shop.call("_get_item_data_at_mouse", mouse_pos) as ItemData
	_check(item_data != null, "Tooltip tab Mua tìm được item ngay lần mở đầu")
	# `_get_item_data_at_mouse()` là lớp dò mà `_process()` dùng khi hover;
	# cache còn nguyên sau open nên tooltip không bị mất dữ liệu lần đầu.
	shop.call("_show_tooltip", item_data)
	_check(bool(shop.get("_tooltip_is_shown")), "Tooltip tab Mua hiện ngay lần mở đầu")
	shop.queue_free()
	GameState.inventory = original_inventory
	print("=== SHOP UI REGRESSION: %s ===" % ("PASS" if _failures == 0 else "%d FAILURES" % _failures))
	get_tree().quit(0 if _failures == 0 else 1)
