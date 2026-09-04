extends Node
## Regression: từ ngày 3, thoại nhập hàng mới của Vos chỉ chạy một lần và
## được trigger đúng cả khi nói chuyện trực tiếp lẫn khi mở quầy shop.

var _failures: int = 0


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	if condition:
		print("[PASS] %s" % label)
	else:
		_failures += 1
		print("[FAIL] %s" % label)


func _dialogue_lines() -> Array:
	var data: Variant = DialogueManager.get("_current_dialogue")
	return data.get("lines", []) if data is Dictionary else []


func _close_dialogue() -> void:
	if DialogueManager.is_active:
		DialogueManager.close()
	await get_tree().process_frame
	await get_tree().process_frame


func _run() -> void:
	var original_day: int = GameState.current_day
	var original_flags: Dictionary = GameState.world_flags.duplicate(true)

	if DialogueManager.is_active:
		DialogueManager.close()
	await get_tree().process_frame

	var dialogue_ui: Node = load("res://scenes/ui/dialogue_ui.tscn").instantiate()
	dialogue_ui.name = "VossDialogueRegressionUI"
	get_tree().root.add_child(dialogue_ui)
	var shop: Node = load("res://scenes/ui/shop_ui.tscn").instantiate()
	shop.name = "VossDialogueRegressionShop"
	get_tree().root.add_child(shop)
	await get_tree().process_frame
	await get_tree().process_frame

	var stock_flag: String = GameState.VOSS_DIALOGUE_SEEN_PREFIX + GameState.VOSS_NEW_STOCK_DIALOGUE_KEY
	GameState.world_flags.erase(stock_flag)

	# Trước ngày 3 không được chặn mở shop bởi thoại nhập hàng mới.
	GameState.current_day = 2
	shop.call("open", 200)
	await get_tree().process_frame
	_check(bool(shop.visible) and not DialogueManager.is_active, "Trước ngày 3 mở shop không trigger thoại Vos")
	shop.call("close")

	# Mở shop trước sẽ phát thoại, giữ shop ẩn, rồi tự mở lại sau khi đóng thoại.
	GameState.current_day = 3
	GameState.world_flags.erase(stock_flag)
	shop.call("open", 200)
	await get_tree().process_frame
	_check(DialogueManager.is_active and not bool(shop.visible), "Ngày 3 mở shop hiển thị thoại nhập hàng mới trước")
	var lines: Array = _dialogue_lines()
	var first_text: String = str(lines[0].get("text", "")) if not lines.is_empty() and lines[0] is Dictionary else ""
	_check(first_text.contains("lô hàng mới"), "Thoại Vos nói rõ shop vừa nhập hàng mới")
	_check(GameState.is_voss_dialogue_seen(GameState.VOSS_NEW_STOCK_DIALOGUE_KEY), "Thoại nhập hàng được đánh dấu một lần trong GameState")
	await _close_dialogue()
	_check(bool(shop.visible), "Shop tự mở sau khi thoại nhập hàng kết thúc")
	shop.call("close")
	shop.call("open", 200)
	await get_tree().process_frame
	_check(bool(shop.visible) and not DialogueManager.is_active, "Lần mở shop sau đó trở về flow bình thường")
	shop.call("close")

	# Nói chuyện trực tiếp ở ngày 3 cũng phải trigger được cùng một thoại.
	GameState.world_flags.erase(stock_flag)
	var shopkeeper: Node = load("res://scenes/npc/shopkeeper.tscn").instantiate()
	shopkeeper.name = "VossDialogueRegressionNPC"
	get_tree().root.add_child(shopkeeper)
	await get_tree().process_frame
	shopkeeper.call("interact", null)
	await get_tree().process_frame
	_check(DialogueManager.is_active, "Ngày 3 nói chuyện trực tiếp với Vos trigger thoại nhập hàng")
	lines = _dialogue_lines()
	first_text = str(lines[0].get("text", "")) if not lines.is_empty() and lines[0] is Dictionary else ""
	_check(first_text.contains("lô hàng mới"), "Thoại trực tiếp dùng đúng nội dung nhập hàng mới")
	await _close_dialogue()
	shopkeeper.call("on_dialogue_ended")

	# Sau thoại đặc biệt, các lần nói tiếp theo quay về daily dialogue.
	shopkeeper.call("interact", null)
	await get_tree().process_frame
	lines = _dialogue_lines()
	first_text = str(lines[0].get("text", "")) if not lines.is_empty() and lines[0] is Dictionary else ""
	_check(first_text == "Cậu rảnh thật nhỉ?", "Sau thoại nhập hàng Vos quay về daily dialogue")
	await _close_dialogue()
	shopkeeper.call("on_dialogue_ended")

	if DialogueManager.is_active:
		DialogueManager.close()
	if shop.is_inside_tree():
		shop.queue_free()
	if dialogue_ui.is_inside_tree():
		dialogue_ui.queue_free()
	if shopkeeper.is_inside_tree():
		shopkeeper.queue_free()
	await get_tree().process_frame

	GameState.current_day = original_day
	GameState.world_flags = original_flags
	print("=== VOSS NEW STOCK DIALOGUE REGRESSION: %s ===" % ("PASS" if _failures == 0 else "%d FAILURES" % _failures))
	get_tree().quit(0 if _failures == 0 else 1)
