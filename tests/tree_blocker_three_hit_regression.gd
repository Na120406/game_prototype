extends Node
## Hồi quy: TreeBlocker cần 3 hit bằng Axe selected, mỗi hit tốn 1 energy,
## lưu số hit còn lại và chặn mọi ô Farm bị vùng collision giao nhau.

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
	await get_tree().process_frame
	GameState.inventory.clear()
	GameState._ensure_inventory_slots()
	GameState.reset_toolbar()
	GameState.set_toolbar_slot(0, "axe", 1)
	GameState.selected_toolbar_slot = 0
	GameState.energy = 10.0

	var blocker_scene: PackedScene = load("res://scenes/world/tree_blocker.tscn")
	var blocker: Node = blocker_scene.instantiate()
	blocker.set("blocker_id", "tree_three_hit_test")
	get_tree().root.add_child(blocker)
	await get_tree().process_frame
	var first_energy: float = GameState.energy
	blocker.call("interact", null)
	_check(int(blocker.call("get_chops_remaining")) == 2, "Hit 1 còn 2 lần chặt")
	_check(absf(GameState.energy - (first_energy - 1.0)) < 0.001, "Hit 1 tốn 1 energy")
	_check(not bool(blocker.call("is_cleared")), "Hit 1 chưa clear thân gỗ")
	blocker.call("interact", null)
	_check(int(blocker.call("get_chops_remaining")) == 1, "Hit 2 còn 1 lần chặt")
	_check(absf(GameState.energy - (first_energy - 2.0)) < 0.001, "Hit 2 tốn thêm 1 energy")
	blocker.call("interact", null)
	_check(bool(blocker.call("is_cleared")), "Hit 3 clear thân gỗ")
	_check(absf(GameState.energy - (first_energy - 3.0)) < 0.001, "Hit 3 tốn thêm 1 energy")
	await get_tree().process_frame
	_check(bool(blocker.get_node("CollisionShape2D").disabled), "Collision bị vô hiệu sau hit 3")
	var energy_after_clear: float = GameState.energy
	blocker.call("interact", null)
	_check(absf(GameState.energy - energy_after_clear) < 0.001, "Hit 4 không trừ energy")
	blocker.queue_free()

	var partial: Node = blocker_scene.instantiate()
	partial.set("blocker_id", "tree_partial_persist_test")
	get_tree().root.add_child(partial)
	await get_tree().process_frame
	partial.call("interact", null)
	_check(int(partial.call("get_chops_remaining")) == 2, "Partial hit lưu số lần còn lại")
	partial.queue_free()
	await get_tree().process_frame
	var reloaded: Node = blocker_scene.instantiate()
	reloaded.set("blocker_id", "tree_partial_persist_test")
	get_tree().root.add_child(reloaded)
	await get_tree().process_frame
	_check(int(reloaded.call("get_chops_remaining")) == 2, "Reload giữ số hit còn lại")
	reloaded.queue_free()

	var farm_scene: Node = load("res://scenes/maps/farm_map.tscn").instantiate()
	get_tree().current_scene.add_child(farm_scene)
	await get_tree().process_frame
	var plot: Node = farm_scene.find_child("FarmPlot", true, false)
	var geometry_blocker: Node = blocker_scene.instantiate()
	geometry_blocker.set("blocker_id", "tree_geometry_test")
	geometry_blocker.position = Vector2(32.0, 282.0)
	farm_scene.add_child(geometry_blocker)
	await get_tree().process_frame
	_check(bool(plot.call("_is_cell_blocked_by_tree", Vector2i(0, 0))), "Cell trung tâm bị collision thân gỗ chặn")
	_check(bool(plot.call("_is_cell_blocked_by_tree", Vector2i(1, 0))), "Cell bên phải bị collision thân gỗ chặn")
	_check(bool(plot.call("_is_cell_blocked_by_tree", Vector2i(0, 1))), "Cell bên dưới bị collision thân gỗ chặn")
	_check(not bool(plot.call("_is_cell_blocked_by_tree", Vector2i(19, 9))), "Cell ngoài vùng collision vẫn thao tác được")
	geometry_blocker.queue_free()
	farm_scene.queue_free()

	GameState.inventory = original_inventory
	GameState.toolbar = original_toolbar
	GameState.world_flags = original_flags
	GameState.energy = original_energy
	GameState.selected_toolbar_slot = original_selected
	print("=== TREE BLOCKER THREE-HIT REGRESSION: %s ===" % ("PASS" if _failures == 0 else "%d FAILURES" % _failures))
	get_tree().quit(0 if _failures == 0 else 1)
