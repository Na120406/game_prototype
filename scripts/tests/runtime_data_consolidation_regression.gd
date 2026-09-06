extends Node

const FarmManagerScript = preload("res://scripts/world/farm/farm_manager.gd")

const EXPECTED_CROPS: Dictionary = {
	"turnip": {"crop_type": 5, "seed": "seed_turnip", "days": 4, "water": 2, "growth": 0.20, "seed_price": 10, "sell_price": 20},
	"wheat": {"crop_type": 1, "seed": "seed_wheat", "days": 6, "water": 2, "growth": 0.25, "seed_price": 15, "sell_price": 45},
	"corn": {"crop_type": 2, "seed": "seed_corn", "days": 8, "water": 1, "growth": 0.20, "seed_price": 20, "sell_price": 75},
	"tomato": {"crop_type": 3, "seed": "seed_tomato", "days": 5, "water": 1, "growth": 0.20, "seed_price": 12, "sell_price": 30},
	"potato": {"crop_type": 4, "seed": "seed_potato", "days": 7, "water": 3, "growth": 0.25, "seed_price": 18, "sell_price": 30},
}

const EXPECTED_GOLD_REWARDS: Dictionary = {
	"turnip": [30, 55, 85, 110, 140],
	"tomato": [40, 85, 125, 170, 210],
	"wheat": [65, 125, 190, 250, 315],
	"potato": [40, 85, 125, 170, 210],
	"corn": [105, 210, 315, 420, 525],
}

var _failures: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	_test_config_contract()
	_test_item_database_contract()
	await _test_farming_contract()
	_test_growth_and_farm_save_contract()
	_test_quest_contract()
	_test_save_migration_contract()
	_test_knockout_contract()
	_test_consumable_contract()

	if _failures.is_empty():
		print("[RuntimeDataRegression] PASS")
		get_tree().quit(0)
	else:
		for failure: String in _failures:
			push_error("[RuntimeDataRegression] %s" % failure)
		print("[RuntimeDataRegression] FAIL (%d)" % _failures.size())
		get_tree().quit(1)


func _test_config_contract() -> void:
	_assert_true(ConfigManager.has_method("get_crop_profile"), "ConfigManager must expose canonical crop profiles")
	if not ConfigManager.has_method("get_crop_profile"):
		return
	for crop_id: String in EXPECTED_CROPS:
		var expected: Dictionary = EXPECTED_CROPS[crop_id]
		var profile: Dictionary = ConfigManager.get_crop_profile(crop_id)
		_assert_true(not profile.is_empty(), "%s profile exists" % crop_id)
		_assert_equal(str(profile.get("seed_item_id", "")), expected["seed"], "%s seed ID" % crop_id)
		_assert_equal(str(profile.get("produce_item_id", "")), crop_id, "%s produce ID" % crop_id)
		_assert_equal(int(profile.get("crop_type", 0)), expected["crop_type"], "%s CropType" % crop_id)
		_assert_equal(int(profile.get("grow_days", 0)), expected["days"], "%s grow days" % crop_id)
		_assert_equal(int(profile.get("water_need", 0)), expected["water"], "%s water need" % crop_id)
		_assert_float(float(profile.get("growth_per_water", 0.0)), expected["growth"], "%s growth per water" % crop_id)
		var expected_yield: int = 2 if crop_id == "potato" else 1
		_assert_equal(int(profile.get("harvest_yield", 0)), expected_yield, "%s harvest yield" % crop_id)


func _test_item_database_contract() -> void:
	var seen: Dictionary = {}
	for item: ItemData in ItemDB.get_all_items():
		_assert_true(not seen.has(item.item_id), "duplicate ItemDB ID: %s" % item.item_id)
		seen[item.item_id] = true
	for crop_id: String in EXPECTED_CROPS:
		var expected: Dictionary = EXPECTED_CROPS[crop_id]
		var seed: ItemData = ItemDB.get_item(expected["seed"])
		var produce: ItemData = ItemDB.get_item(crop_id)
		_assert_true(seed != null, "%s seed is loaded" % crop_id)
		_assert_true(produce != null, "%s produce is loaded" % crop_id)
		if seed != null:
			_assert_equal(seed.grow_days, expected["days"], "%s seed tooltip days" % crop_id)
			_assert_equal(seed.water_need, expected["water"], "%s seed water profile" % crop_id)
			_assert_float(seed.growth_per_water, expected["growth"], "%s seed growth profile" % crop_id)
			_assert_equal(seed.buy_price, expected["seed_price"], "%s seed buy price" % crop_id)
		if produce != null:
			_assert_equal(produce.sell_price, expected["sell_price"], "%s produce sell price" % crop_id)
		var legacy_id := "%s_harvest" % crop_id
		_assert_true(ItemDB.get_item(legacy_id) == produce, "%s resolves to canonical produce" % legacy_id)


func _test_farming_contract() -> void:
	var original_cells: Dictionary = FarmTickManager.serialize()
	var original_inventory: Array[Dictionary] = GameState.inventory.duplicate(true)
	var original_toolbar: Array[Dictionary] = GameState.toolbar.duplicate(true)
	var manager: Node = FarmManagerScript.new()
	add_child(manager)
	await get_tree().process_frame

	for crop_id: String in EXPECTED_CROPS:
		var expected: Dictionary = EXPECTED_CROPS[crop_id]
		FarmTickManager.deserialize({})
		var cell := Vector2i(10 + int(expected["crop_type"]), 10)
		_assert_true(FarmTickManager.plow_cell(cell), "%s test cell plowed" % crop_id)
		_assert_true(manager.plant_from_seed(cell, expected["seed"]), "%s seed plants" % crop_id)
		var planted: Dictionary = FarmTickManager.get_cell_data(cell)
		_assert_equal(int(planted.get("grow_days", 0)), expected["days"], "%s planted grow days" % crop_id)
		_assert_equal(int(planted.get("water_need", 0)), expected["water"], "%s planted water need" % crop_id)
		_assert_float(float(planted.get("growth_per_water", 0.0)), expected["growth"], "%s planted growth per water" % crop_id)
		planted["state"] = FarmEnums.CropState.MATURE
		planted["growth_progress"] = 1.0
		var before: int = GameState.get_item_count(crop_id)
		var harvested_id: String = manager.harvest_crop(cell)
		_assert_equal(harvested_id, crop_id, "%s canonical harvest ID" % crop_id)
		var expected_yield: int = 2 if crop_id == "potato" else 1
		_assert_equal(GameState.get_item_count(crop_id) - before, expected_yield, "%s exact harvest yield" % crop_id)

	manager.queue_free()
	FarmTickManager.deserialize(original_cells)
	GameState.inventory = original_inventory
	GameState.toolbar = original_toolbar


func _test_quest_contract() -> void:
	for crop_id: String in EXPECTED_CROPS:
		var expected: Dictionary = EXPECTED_CROPS[crop_id]
		_assert_equal(QuestSystem.get_crop_grow_days(crop_id), expected["days"], "%s quest grow days" % crop_id)
		_assert_true(QuestSystem.delivery_items_match(crop_id, "%s_harvest" % crop_id), "%s quest alias match" % crop_id)
		for amount: int in range(1, 6):
			var reward: int = ConfigManager.get_dynamic_quest_gold_reward(crop_id, amount)
			_assert_equal(reward, EXPECTED_GOLD_REWARDS[crop_id][amount - 1], "%s quest reward x%d" % [crop_id, amount])

	var original_day: int = GameState.current_day
	var original_active: Array[Dictionary] = QuestSystem.active_quests.duplicate(true)
	var original_completed: Array[String] = QuestSystem.completed_quests.duplicate()
	var original_failed: Array[String] = QuestSystem.failed_quests.duplicate()
	GameState.current_day = 2
	QuestSystem.active_quests.clear()
	QuestSystem.completed_quests.clear()
	QuestSystem.failed_quests.clear()
	var first := _delivery_quest("regression_turnip_a", "turnip")
	var duplicate := _delivery_quest("regression_turnip_b", "turnip_harvest")
	_assert_true(QuestSystem.accept_quest(first["id"], first), "first dynamic delivery quest accepted")
	_assert_true(not QuestSystem.accept_quest(duplicate["id"], duplicate), "duplicate dynamic delivery alias rejected")
	var generated_a: Dictionary = QuestSystem.generate_random_delivery_quest("neighbor")
	var generated_b: Dictionary = QuestSystem.generate_random_delivery_quest("neighbor")
	_assert_true(str(generated_a.get("id", "")) != str(generated_b.get("id", "")), "dynamic quest IDs are unique in one frame")

	# Reward được snapshot trong quest; completion phải trao đúng snapshot đó.
	var original_toolbar: Array[Dictionary] = GameState.toolbar.duplicate(true)
	var original_inventory: Array[Dictionary] = GameState.inventory.duplicate(true)
	var original_gold: int = GameState.gold
	QuestSystem.active_quests.clear()
	var reward_quest := _delivery_quest("regression_reward_snapshot", "turnip")
	reward_quest["reward"]["gold"] = 123
	_assert_true(QuestSystem.accept_quest(reward_quest["id"], reward_quest), "reward snapshot quest accepted")
	GameState.toolbar[0] = {"id": "turnip_harvest", "amount": 1}
	GameState.selected_toolbar_slot = 0
	_assert_true(QuestSystem.complete_delivery_quest(reward_quest["id"]), "legacy alias stack completes canonical quest")
	_assert_equal(GameState.gold - original_gold, 123, "completion grants displayed reward snapshot")
	_assert_equal(int(GameState.toolbar[0].get("amount", 0)), 0, "delivery consumes selected alias stack")
	GameState.toolbar = original_toolbar
	GameState.inventory = original_inventory
	GameState.gold = original_gold
	QuestSystem.active_quests = original_active
	QuestSystem.completed_quests = original_completed
	QuestSystem.failed_quests = original_failed
	GameState.current_day = original_day


func _test_growth_and_farm_save_contract() -> void:
	var original_cells: Dictionary = FarmTickManager.serialize()
	var original_day: int = GameState.current_day
	var cell := Vector2i(30, 30)
	GameState.current_day = 2
	FarmTickManager.import_save_data({"cells": [{
		"x": cell.x,
		"y": cell.y,
		"data": {
			"type": FarmEnums.CropType.CORN,
			"state": FarmEnums.CropState.SEEDED,
			"growth_progress": 0.4,
			"watered": false,
			"unwatered_streak": 0,
			"grow_days": 6,
			"water_need": 9,
			"growth_per_water": 0.9,
		},
	}]})
	var migrated: Dictionary = FarmTickManager.get_cell_data(cell)
	_assert_equal(int(migrated.get("grow_days", 0)), 8, "farm save rehydrates Corn grow days")
	_assert_equal(int(migrated.get("water_need", 0)), 1, "farm save rehydrates Corn water need")
	_assert_float(float(migrated.get("growth_progress", 0.0)), 0.4, "farm save preserves growth progress")

	# Giữ nguyên semantics: growth tăng trước, sau đó mới xét ngưỡng wilt.
	FarmTickManager.deserialize({"31,30": {
		"type": FarmEnums.CropType.TURNIP,
		"state": FarmEnums.CropState.SEEDED,
		"growth_progress": 0.0,
		"watered": false,
		"unwatered_streak": 0,
		"grow_days": 4,
		"water_need": 2,
		"growth_per_water": 0.2,
	}})
	FarmTickManager.call("_day_boundary_update", false)
	var first_day: Dictionary = FarmTickManager.get_cell_data(Vector2i(31, 30))
	_assert_float(float(first_day.get("growth_progress", 0.0)), 0.25, "unwatered day still advances growth before wilt threshold")
	_assert_true(int(first_day.get("state", 0)) != FarmEnums.CropState.WILTED, "crop survives below wilt threshold")
	FarmTickManager.call("_day_boundary_update", false)
	var second_day: Dictionary = FarmTickManager.get_cell_data(Vector2i(31, 30))
	_assert_float(float(second_day.get("growth_progress", 0.0)), 0.5, "threshold day advances growth before wilting")
	_assert_equal(int(second_day.get("state", 0)), FarmEnums.CropState.WILTED, "crop wilts at canonical threshold")
	FarmTickManager.deserialize(original_cells)
	GameState.current_day = original_day


func _test_save_migration_contract() -> void:
	var legacy_save: Dictionary = {
		"version": 3,
		"game_state": {
			"inventory": [{"id": "tomato_harvest", "amount": 3}],
			"toolbar": [{"id": "potato_harvest", "amount": 2}],
		},
	}
	CatchUpSystem.call("_migrate_save_data", legacy_save, 3)
	var state: Dictionary = legacy_save.get("game_state", {})
	_assert_equal(str(state.get("inventory", [])[0].get("id", "")), "tomato", "inventory legacy ID migration")
	_assert_equal(int(state.get("inventory", [])[0].get("amount", 0)), 3, "inventory migration preserves amount")
	_assert_equal(str(state.get("toolbar", [])[0].get("id", "")), "potato", "toolbar legacy ID migration")


func _test_knockout_contract() -> void:
	_assert_float(float(ConfigManager.get_value("money.knockout_loss_ratio", -1.0)), 0.10, "knockout config stays at 10 percent")
	var source := FileAccess.get_file_as_string("res://scripts/autoload/energy_manager.gd")
	_assert_true(source.contains("const GOLD_LOSS_RATIO: float = 0.10"), "knockout fallback constant is 10 percent")
	var original_gold: int = GameState.gold
	GameState.gold = 11
	EnergyManager.call("_apply_gold_loss_penalty")
	_assert_equal(GameState.gold, 9, "knockout removes ceil(10 percent) of Gold")
	GameState.gold = original_gold


func _test_consumable_contract() -> void:
	var apple: ItemData = ItemDB.get_item("apple")
	var potion: ItemData = ItemDB.get_item("health_potion")
	_assert_true(apple != null, "Apple exists")
	_assert_true(potion != null, "Health Potion exists")
	if apple != null:
		_assert_float(apple.energy_restore, 3.0, "Apple restores 3 Energy")
		_assert_equal(apple.sell_price, 3, "Apple sells for 3 Gold")
	if potion != null:
		_assert_float(potion.energy_restore, 15.0, "Health Potion restores 15 Energy")
		_assert_equal(potion.buy_price, 20, "Health Potion buy price")
		_assert_equal(potion.sell_price, 10, "Health Potion sell price")


func _delivery_quest(quest_id: String, item_id: String) -> Dictionary:
	return {
		"id": quest_id,
		"name": quest_id,
		"type": "delivery",
		"giver": "neighbor",
		"required_item": item_id,
		"required_amount": 1,
		"deadline_days": 3,
		"reward": {"gold": 55, "relationship": 2},
	}


func _assert_true(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)


func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [label, str(expected), str(actual)])


func _assert_float(actual: float, expected: float, label: String) -> void:
	if not is_equal_approx(actual, expected):
		_failures.append("%s (expected %.3f, got %.3f)" % [label, expected, actual])
