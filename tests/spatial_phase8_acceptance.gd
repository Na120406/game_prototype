extends Node
## =============================================================================
## SPATIAL PHASE 8 — ACCEPTANCE HARNESS
## =============================================================================
## Kiểm tra các contract tích hợp còn thiếu bằng SceneTree thật và autoload thật.
## Harness tự thoát với mã 1 nếu có bất kỳ tiêu chí nào không đạt.

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
	_test_hotbar_tree_lifecycle_guard()
	_test_config_and_route_contract()
	_test_axe_day_gate()
	_test_spatial_save_round_trip()
	_test_legacy_forest_flag_migration()
	_test_farm_save_round_trip_without_farm_scene()
	await _test_forest_blocker_persistence()
	await _test_tree_blocker_requires_owned_axe()
	await _test_farm_expansion_full_chain()
	await _test_background_blocker_is_ignored()
	await _test_water_source_with_toolbar_item()
	await _test_gathering_inventory_contract()
	# Đợi queue_free của các fixture hoàn tất để leak warning không che khuất
	# lỗi runtime thật trong log nghiệm thu.
	await get_tree().process_frame
	await get_tree().process_frame

	print("")
	if _failures == 0:
		print("=== SPATIAL PHASE 8 ACCEPTANCE: ALL PASS ===")
	else:
		print("=== SPATIAL PHASE 8 ACCEPTANCE: %d FAILURES ===" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _test_hotbar_tree_lifecycle_guard() -> void:
	var file := FileAccess.open("res://scripts/ui/hotbar.gd", FileAccess.READ)
	_check(file != null, "Đọc được hotbar.gd")
	if file == null:
		return
	var source: String = file.get_as_text()
	var handler_start: int = source.find("func _on_scene_changed_refresh")
	var get_tree_pos: int = source.find("var tree := get_tree()", handler_start)
	var guard_pos: int = source.find("not is_inside_tree()", handler_start)
	_check(
		handler_start >= 0 and guard_pos > handler_start and guard_pos < get_tree_pos,
		"Hotbar chặn callback scene_changed khi node đã rời SceneTree"
	)


func _test_config_and_route_contract() -> void:
	var long_cost: float = float(ConfigManager.get_forest_long_route_time())
	var short_cost: float = float(ConfigManager.get_forest_shortcut_time())
	_check(long_cost > short_cost and short_cost >= 0.0, "Long route tốn thời gian hơn shortcut")

	var forest_scene: PackedScene = load("res://scenes/maps/forest_map.tscn")
	_check(forest_scene != null, "Forest scene load được")
	if forest_scene == null:
		return
	var forest: Node = forest_scene.instantiate()
	var found_long: bool = false
	var found_short: bool = false
	var found_gathering: bool = false
	var gathering_items_sellable: bool = true
	for node: Node in forest.find_children("*", "Node", true, false):
		if "portal_id" in node:
			found_long = found_long or str(node.get("portal_id")) == "portal_forest_long_to_town"
			found_short = found_short or str(node.get("portal_id")) == "portal_forest_short_to_town"
		if node.is_in_group("gathering_point") or "gathering_id" in node:
			found_gathering = true
			var gathering_item_id: String = str(node.get("item_id"))
			var gathering_item: ItemData = ItemDB.get_item(gathering_item_id)
			gathering_items_sellable = gathering_items_sellable and gathering_item != null and gathering_item.sell_price > 0
	_check(found_long, "Forest có long-route portal")
	_check(found_short, "Forest có shortcut portal")
	_check(found_gathering, "Forest có gathering point trên map")
	_check(found_gathering and gathering_items_sellable, "Gathering dùng item đi qua sell flow hiện tại")
	forest.free()


func _test_axe_day_gate() -> void:
	var original_day: int = GameState.current_day
	GameState.current_day = maxi(1, ConfigManager.get_axe_available_day() - 1)
	_check(not GameState.is_axe_purchasable(), "Axe chưa mua được trước ngày mở bán")
	GameState.current_day = ConfigManager.get_axe_available_day()
	_check(GameState.is_axe_purchasable(), "Axe mua được đúng ngày mở bán")
	GameState.current_day = original_day


func _test_spatial_save_round_trip() -> void:
	var original_flags: Dictionary = GameState.world_flags.duplicate(true)
	GameState.clear_forest_shortcut()
	GameState.clear_farm_blocker("phase8_round_trip")
	GameState.mark_gathering_collected("phase8_round_trip")
	GameState.set_watering_can_level(2)
	var saved: Dictionary = CatchUpSystem.prepare_save_data()

	GameState.world_flags.clear()
	CatchUpSystem.apply_save_data(saved)
	_check(GameState.is_forest_shortcut_cleared(), "Save/load giữ Forest shortcut")
	_check(GameState.is_farm_blocker_cleared("phase8_round_trip"), "Save/load giữ Farm blocker")
	_check(GameState.is_gathering_collected("phase8_round_trip"), "Save/load giữ gathering point")
	_check(GameState.get_watering_can_level() == 2, "Save/load giữ Watering Can capacity")
	GameState.world_flags = original_flags


func _test_farm_save_round_trip_without_farm_scene() -> void:
	var original_cells: Dictionary = FarmTickManager.serialize()
	var fixture: Dictionary = {
		"99,99": {
			"type": FarmEnums.CropType.TOMATO,
			"state": FarmEnums.CropState.SEEDED,
			"growth_progress": 0.25,
			"watered": true,
			"unwatered_streak": 0,
			"grow_days": 4,
			"water_need": 1,
			"growth_per_water": 0.25,
		}
	}
	FarmTickManager.deserialize(fixture)
	var saved: Dictionary = CatchUpSystem.prepare_save_data()
	var saved_farm: Dictionary = saved.get("farm_cells", {})
	_check(
		saved_farm.has("cells") and saved_farm.get("cells", []).size() == 1,
		"Save ngoài Farm vẫn lấy cells từ FarmTickManager"
	)
	FarmTickManager.deserialize({})
	CatchUpSystem.apply_save_data(saved)
	_check(FarmTickManager.get_cell_state(Vector2i(99, 99)) == FarmEnums.CropState.SEEDED, "Load ngoài Farm phục hồi FarmTickManager")
	FarmTickManager.deserialize(original_cells)


func _test_legacy_forest_flag_migration() -> void:
	var original_flags: Dictionary = GameState.world_flags.duplicate(true)
	var saved: Dictionary = CatchUpSystem.prepare_save_data()
	var legacy_flags: Dictionary = {
		"spatial_farm_blocker_forest_shortcut_tree_cleared": true,
	}
	saved["world_flags"] = legacy_flags.duplicate(true)
	saved["game_state"]["world_flags"] = legacy_flags.duplicate(true)
	CatchUpSystem.apply_save_data(saved)
	_check(GameState.is_forest_shortcut_cleared(), "Save cũ migrate Forest shortcut sang canonical flag")
	GameState.world_flags = original_flags


func _test_forest_blocker_persistence() -> void:
	var original_flags: Dictionary = GameState.world_flags.duplicate(true)
	GameState.clear_forest_shortcut()
	var blocker_scene: PackedScene = load("res://scenes/world/tree_blocker.tscn")
	_check(blocker_scene != null, "TreeBlocker scene load được")
	if blocker_scene != null:
		var blocker: Node = blocker_scene.instantiate()
		blocker.set("blocker_id", "forest_shortcut")
		get_tree().root.add_child(blocker)
		await get_tree().process_frame
		_check(bool(blocker.call("is_cleared")), "Forest blocker không hồi sinh sau reload")
		blocker.queue_free()
	GameState.world_flags = original_flags


func _test_tree_blocker_requires_owned_axe() -> void:
	var original_inventory: Array = GameState.inventory.duplicate(true)
	var original_toolbar: Array = GameState.toolbar.duplicate(true)
	var original_flags: Dictionary = GameState.world_flags.duplicate(true)
	var original_tool: String = ToolHandler.get_equipped()
	GameState.inventory.clear()
	GameState._ensure_inventory_slots()
	GameState.reset_toolbar()
	GameState.selected_toolbar_slot = 0
	ToolHandler.equip("axe")

	var blocker_scene: PackedScene = load("res://scenes/world/tree_blocker.tscn")
	var blocker: Node = blocker_scene.instantiate()
	blocker.set("blocker_id", "phase8_owned_axe")
	get_tree().root.add_child(blocker)
	await get_tree().process_frame
	blocker.call("interact", null)
	_check(not bool(blocker.call("is_cleared")), "Equip giả không clear blocker khi không sở hữu Axe")

	GameState.set_toolbar_slot(0, "axe", 1)
	_check(GameState.has_axe(), "GameState nhận Axe nằm trong toolbar")
	for _hit: int in range(3):
		blocker.call("interact", null)
	_check(bool(blocker.call("is_cleared")), "Axe sở hữu và đang equip clear được blocker")
	blocker.queue_free()

	ToolHandler.unequip()
	if original_tool != "none":
		ToolHandler.equip(original_tool)
	GameState.inventory = original_inventory
	GameState.toolbar = original_toolbar
	GameState.world_flags = original_flags


func _test_background_blocker_is_ignored() -> void:
	var farm_scene: PackedScene = load("res://scenes/maps/farm_map.tscn")
	var farm: Node = farm_scene.instantiate()
	get_tree().current_scene.add_child(farm)
	await get_tree().process_frame
	var plot: Node = farm.find_child("FarmPlot", true, false)
	_check(plot != null, "FarmPlot tồn tại để kiểm tra blocker scope")
	if plot == null:
		farm.queue_free()
		return

	var fake_script: Script = load("res://tests/support/fake_tree_blocker.gd")
	var background_blocker: Node2D = fake_script.new()
	background_blocker.add_to_group("tree_blocker")
	background_blocker.global_position = Vector2(32.0, 282.0)
	get_tree().root.add_child(background_blocker)
	_check(not bool(plot.call("_is_cell_blocked_by_tree", Vector2i.ZERO)), "Blocker của background map không chặn active Farm")

	background_blocker.reparent(farm, true)
	_check(bool(plot.call("_is_cell_blocked_by_tree", Vector2i.ZERO)), "Blocker trong active scene vẫn chặn đúng cell")
	background_blocker.queue_free()
	farm.queue_free()
	await get_tree().process_frame


func _test_farm_expansion_full_chain() -> void:
	var original_cells: Dictionary = FarmTickManager.serialize()
	var original_inventory: Array = GameState.inventory.duplicate(true)
	var original_toolbar: Array = GameState.toolbar.duplicate(true)
	var original_flags: Dictionary = GameState.world_flags.duplicate(true)
	var original_day: int = GameState.current_day
	var original_time: float = GameState.current_time
	var original_tool: String = ToolHandler.get_equipped()
	FarmTickManager.deserialize({})
	GameState.set_flag("spatial_farm_blocker_farm_blocker_1_cleared", false)
	GameState.inventory.clear()
	GameState._ensure_inventory_slots()
	GameState.reset_toolbar()
	GameState.selected_toolbar_slot = 0

	var farm_scene: PackedScene = load("res://scenes/maps/farm_map.tscn")
	var farm: Node = farm_scene.instantiate()
	get_tree().current_scene.add_child(farm)
	await get_tree().process_frame
	var manager: Node = farm.find_child("FarmManager", true, false)
	var blocker: Node = null
	for node: Node in farm.find_children("*", "Node", true, false):
		if "blocker_id" in node and str(node.get("blocker_id")) == "farm_blocker_1":
			blocker = node
			break
	_check(manager != null and blocker != null, "Farm expansion fixture có manager và blocker")
	if manager != null and blocker != null:
		# farm_blocker_1 was compacted with the field; use a cell that is actually
		# inside its 48×48 collision after the Farm map resize.
		var cell := Vector2i(8, 4)
		_check(not bool(manager.call("plow_cell", cell)), "Cell expansion bị chặn trước khi clear")
		GameState.set_toolbar_slot(0, "axe", 1)
		ToolHandler.equip("axe")
		for _hit: int in range(3):
			blocker.call("interact", null)
		_check(bool(manager.call("plow_cell", cell)), "Cell expansion plow được sau khi clear")
		GameState.set_watering_can_level(GameState.get_watering_can_max_capacity())
		var before_water: int = GameState.get_watering_can_level()
		_check(bool(manager.call("water_cell", cell)), "Cell expansion tưới được")
		_check(GameState.get_watering_can_level() == before_water - 1, "Tưới thành công consume đúng một nước")
		_check(bool(manager.call("plant_from_seed", cell, "seed_turnip")), "Cell expansion trồng được seed")
		for _day: int in range(4):
			GameState.set_watering_can_level(GameState.get_watering_can_max_capacity())
			manager.call("water_cell", cell)
			GameState.advance_day(6.0)
		_check(FarmTickManager.get_cell_state(cell) == FarmEnums.CropState.MATURE, "Cây trên cell expansion trưởng thành")
		var harvest_id: String = str(manager.call("harvest_crop", cell))
		_check(harvest_id != "" and GameState.get_item_count(harvest_id) >= 2, "Cell expansion thu hoạch qua item flow hiện tại")

	farm.queue_free()
	await get_tree().process_frame
	ToolHandler.unequip()
	if original_tool != "none":
		ToolHandler.equip(original_tool)
	GameState.current_day = original_day
	GameState.current_time = original_time
	GameState.inventory = original_inventory
	GameState.toolbar = original_toolbar
	GameState.world_flags = original_flags
	FarmTickManager.deserialize(original_cells)


func _test_water_source_with_toolbar_item() -> void:
	var original_inventory: Array = GameState.inventory.duplicate(true)
	var original_toolbar: Array = GameState.toolbar.duplicate(true)
	var original_flags: Dictionary = GameState.world_flags.duplicate(true)
	GameState.inventory.clear()
	GameState._ensure_inventory_slots()
	GameState.reset_toolbar()
	GameState.selected_toolbar_slot = 0
	GameState.set_watering_can_level(0)

	var source_scene: PackedScene = load("res://scenes/world/water_source.tscn")
	var source: Node = source_scene.instantiate()
	get_tree().root.add_child(source)
	await get_tree().process_frame
	source.set("_player_nearby", true)
	source.call("refresh_interaction_state")
	var prompt: Label = source.get("prompt") as Label
	_check(prompt != null and not prompt.visible, "WaterSource ẩn prompt khi chưa có Watering Can")
	GameState.set_toolbar_slot(0, "water_can", 1)
	_check(prompt != null and prompt.visible, "WaterSource nhận Watering Can nằm trong toolbar")
	source.call("interact", null)
	_check(
		GameState.get_watering_can_level() == GameState.get_watering_can_max_capacity(),
		"WaterSource refill capacity về mức tối đa"
	)
	source.queue_free()

	GameState.inventory = original_inventory
	GameState.toolbar = original_toolbar
	GameState.world_flags = original_flags


func _test_gathering_inventory_contract() -> void:
	var original_inventory: Array = GameState.inventory.duplicate(true)
	var original_flags: Dictionary = GameState.world_flags.duplicate(true)
	GameState.inventory.clear()
	for index: int in range(21):
		GameState.inventory.append({"id": "axe", "amount": 1})

	var point_scene: PackedScene = load("res://scenes/world/gathering_point.tscn")
	var point: Node = point_scene.instantiate()
	point.set("gathering_id", "phase8_full_inventory")
	point.set("item_id", "apple")
	point.set("quantity", 1)
	get_tree().root.add_child(point)
	await get_tree().process_frame
	point.call("interact", null)
	_check(not GameState.is_gathering_collected("phase8_full_inventory"), "Túi đầy không consume gathering point")
	_check(not bool(point.call("is_collected")), "Túi đầy giữ gathering point để thử lại")
	point.queue_free()

	GameState.inventory[0] = {"id": "", "amount": 0}
	var success_point: Node = point_scene.instantiate()
	success_point.set("gathering_id", "phase8_success")
	success_point.set("item_id", "apple")
	success_point.set("quantity", 1)
	get_tree().root.add_child(success_point)
	await get_tree().process_frame
	success_point.call("interact", null)
	_check(GameState.is_gathering_collected("phase8_success"), "Gathering thành công đánh dấu persistence")
	_check(GameState.get_item_count("apple") == 1, "Gathering thành công thêm item vào inventory")
	success_point.queue_free()

	GameState.inventory = original_inventory
	GameState.world_flags = original_flags
