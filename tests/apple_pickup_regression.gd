extends Node
## Regression: táo đặt sẵn tại Farm dùng cùng feedback pickup với táo Forest.

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
	var original_flags: Dictionary = GameState.world_flags.duplicate(true)
	GameState.inventory.clear()
	GameState._ensure_inventory_slots()
	GameState.world_flags.erase("apple_collected_day")

	var apple_scene: PackedScene = load("res://scenes/world/items/apple.tscn")
	var apple: Node = apple_scene.instantiate()
	get_tree().root.add_child(apple)
	await get_tree().process_frame
	_check(apple.has_node("Body") and apple.has_node("Highlight") and apple.has_node("Stem"), "Táo Farm có đủ visual giống táo Forest")
	var fake_player := Node2D.new()
	get_tree().root.add_child(fake_player)
	apple.global_position = Vector2.ZERO
	apple.set("_player", fake_player)
	fake_player.global_position = Vector2(17.0, 0.0)
	_check(bool(apple.call("is_player_nearby")), "Táo Farm nhận tương tác khi player đứng sát")
	fake_player.global_position = Vector2(19.0, 0.0)
	_check(not bool(apple.call("is_player_nearby")), "Táo Farm không nhận tương tác khi đứng quá xa")
	apple.call("interact", null)
	_check(GameState.get_item_count("apple") == 1, "Nhặt táo Farm thêm đúng một quả")
	_check(str(GameState.get_flag("apple_collected_day", "")) == str(GameState.current_day), "Táo Farm lưu ngày đã nhặt")
	await get_tree().process_frame
	_check(not is_instance_valid(apple), "Táo Farm biến mất sau khi nhặt thành công")
	fake_player.queue_free()

	GameState.inventory = original_inventory
	GameState.world_flags = original_flags
	print("=== APPLE PICKUP REGRESSION: %s ===" % ("PASS" if _failures == 0 else "%d FAILURES" % _failures))
	get_tree().quit(0 if _failures == 0 else 1)
