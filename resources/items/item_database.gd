extends Node

# Preload các resource để Godot đưa chúng chắc chắn vào Web export. Việc load
# bằng đường dẫn động/DirAccess có thể không hoạt động như desktop khi chạy
# trên itch.io.
const ITEM_RESOURCES: Array[ItemData] = [
	preload("res://resources/items/definitions/apple.tres"),
	preload("res://resources/items/definitions/axe.tres"),
	preload("res://resources/items/definitions/health_potion.tres"),
	preload("res://resources/items/definitions/lore_fragment.tres"),
	preload("res://resources/items/definitions/old_key.tres"),
	preload("res://resources/items/definitions/rope.tres"),
	preload("res://resources/items/definitions/seed_corn.tres"),
	preload("res://resources/items/definitions/seed_potato.tres"),
	preload("res://resources/items/definitions/seed_tomato.tres"),
	preload("res://resources/items/definitions/seed_turnip.tres"),
	preload("res://resources/items/definitions/seed_wheat.tres"),
	preload("res://resources/items/definitions/strange_fruit.tres"),
	preload("res://resources/items/definitions/water_can.tres"),
	preload("res://resources/items/definitions/hoe.tres"),
	preload("res://resources/items/definitions/potato.tres"),
	preload("res://resources/items/definitions/turnip.tres"),
	preload("res://resources/items/definitions/wheat.tres"),
	preload("res://resources/items/definitions/tomato.tres"),
	preload("res://resources/items/definitions/corn.tres"),
]

var _db: Dictionary = {}

func _ready() -> void:
	_load_all_items()

func _load_all_items() -> void:
	_db.clear()
	# Preload array chắc chắn được đưa vào Web export. Load trực tiếp từ constant.
	for item: ItemData in ITEM_RESOURCES:
		_register_item(item)

	# Scan thêm để tự động nhận item mới khi chạy trong editor/desktop.
	var dir := DirAccess.open("res://resources/items/definitions/")
	if dir != null:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var path := "res://resources/items/definitions/" + file_name
				if ResourceLoader.exists(path):
					var item: ItemData = load(path)
					_register_item(item)
			file_name = dir.get_next()
		dir.list_dir_end()
	_apply_crop_profiles()
	_apply_level_design_prices()
	print("[ItemDB] Total items loaded: %d" % _db.size())

func _register_item(item: ItemData) -> void:
	if item == null or item.item_id == "":
		return
	if _db.has(item.item_id):
		var existing: ItemData = _db[item.item_id]
		if existing == item or existing.resource_path == item.resource_path:
			return
		push_error("[ItemDB] Duplicate item_id '%s': %s conflicts with %s" % [
			item.item_id, existing.resource_path, item.resource_path
		])
		return
	_db[item.item_id] = item
	print("[ItemDB] Loaded: %s" % item.item_id)

func _apply_crop_profiles() -> void:
	var cm: Node = get_node_or_null("/root/ConfigManager")
	if cm == null or not cm.has_method("get_crop_ids"):
		return
	for crop_id: String in cm.call("get_crop_ids"):
		var profile: Dictionary = cm.call("get_crop_profile", crop_id)
		var seed: ItemData = _db.get(str(profile.get("seed_item_id", "")), null)
		var produce: ItemData = _db.get(str(profile.get("produce_item_id", "")), null)
		if seed == null or produce == null:
			push_error("[ItemDB] Crop profile references missing items: %s" % crop_id)
			continue
		seed.buy_price = int(profile.get("seed_buy_price", seed.buy_price))
		seed.grow_days = int(profile.get("grow_days", seed.grow_days))
		seed.water_need = int(profile.get("water_need", seed.water_need))
		seed.growth_per_water = float(profile.get("growth_per_water", seed.growth_per_water))
		seed.harvest_item_id = str(profile.get("produce_item_id", seed.harvest_item_id))
		seed.grow_season = str(profile.get("season", seed.grow_season))
		produce.sell_price = int(profile.get("produce_sell_price", produce.sell_price))

func _canonical_id(item_id: String) -> String:
	var cm: Node = get_node_or_null("/root/ConfigManager")
	if cm != null and cm.has_method("canonicalize_item_id"):
		return str(cm.call("canonicalize_item_id", item_id))
	return item_id

# Axe.buy_price phải khớp resources/config/game_config.json (level_design.axe_price)
# để giá là data-driven duy nhất — không hardcode song song trong .tres.
# Đọc trực tiếp từ ConfigManager (autoload đứng trước ItemDB trong project.godot).
func _apply_level_design_prices() -> void:
	var cm: Node = get_node_or_null("/root/ConfigManager")
	if cm == null or not cm.has_method("get_axe_price"):
		return
	var axe: ItemData = _db.get("axe", null)
	if axe != null:
		axe.buy_price = int(cm.call("get_axe_price"))

func get_item(item_id: String) -> ItemData:
	return _db.get(_canonical_id(item_id), null)

func get_item_or_null(item_id: String) -> ItemData:
	var item: ItemData = _db.get(_canonical_id(item_id), null)
	if item == null:
		push_warning("[ItemDB] Item not found: %s" % item_id)
	return item

func safe_get_item(item_id: String, default_values: Dictionary = {}) -> ItemData:
	var item: ItemData = _db.get(_canonical_id(item_id), null)
	if item == null:
		push_warning("[ItemDB] Item not found: %s, using defaults" % item_id)
		# Return a placeholder ItemData with default values
		return _create_default_item_data(item_id, default_values)
	return item

func _create_default_item_data(item_id: String, defaults: Dictionary) -> ItemData:
	var data := ItemData.new()
	data.item_id = item_id
	data.display_name = defaults.get("display_name", item_id)
	data.item_type = defaults.get("item_type", ItemData.Type.CONSUMABLE)
	data.item_category = defaults.get("item_category", ItemData.Category.MISC)
	data.buy_price = defaults.get("buy_price", 10)
	data.sell_price = defaults.get("sell_price", 5)
	data.item_color = defaults.get("item_color", Color.WHITE)
	return data

func get_item_with_validation(item_id: String, expected_type: ItemData.Type = ItemData.Type.CONSUMABLE) -> ItemData:
	var item: ItemData = _db.get(_canonical_id(item_id), null)
	if item == null:
		push_warning("[ItemDB] Item not found: %s" % item_id)
		return null
	if item.item_type != expected_type:
		push_warning("[ItemDB] Item %s has type %s, expected %s" % [item_id, item.item_type, expected_type])
	return item

func require_item(item_id: String) -> ItemData:
	var item: ItemData = _db.get(_canonical_id(item_id), null)
	if item == null:
		push_error("[ItemDB] CRITICAL: Required item not found: %s" % item_id)
	return item

func is_valid_seed(seed_id: String) -> bool:
	var item: ItemData = _db.get(_canonical_id(seed_id), null)
	if item == null:
		return false
	return item.item_type == ItemData.Type.SEED

func is_valid_tool(tool_id: String) -> bool:
	var item: ItemData = _db.get(_canonical_id(tool_id), null)
	if item == null:
		return false
	return item.item_type == ItemData.Type.TOOL

func is_valid_consumable(item_id: String) -> bool:
	var item: ItemData = _db.get(_canonical_id(item_id), null)
	if item == null:
		return false
	return item.item_type == ItemData.Type.CONSUMABLE

func has_item(item_id: String) -> bool:
	return _db.has(_canonical_id(item_id))

func get_all_items() -> Array[ItemData]:
	var result: Array[ItemData] = []
	for item: ItemData in _db.values():
		result.append(item)
	return result

func get_items_by_type(type: ItemData.Type) -> Array[ItemData]:
	var result: Array[ItemData] = []
	for item: ItemData in _db.values():
		if item.item_type == type:
			result.append(item)
	return result

func get_items_by_category(cat: ItemData.Category) -> Array[ItemData]:
	var result: Array[ItemData] = []
	for item: ItemData in _db.values():
		if item.item_category == cat:
			result.append(item)
	return result

func get_seeds() -> Array[ItemData]:
	return get_items_by_type(ItemData.Type.SEED)

func get_produce() -> Array[ItemData]:
	return get_items_by_category(ItemData.Category.FARM_PRODUCE)

func get_consumables() -> Array[ItemData]:
	return get_items_by_type(ItemData.Type.CONSUMABLE)

func get_tools() -> Array[ItemData]:
	return get_items_by_type(ItemData.Type.TOOL)

func get_buyable_items() -> Array[ItemData]:
	var result: Array[ItemData] = []
	for item: ItemData in _db.values():
		if item.buy_price > 0:
			result.append(item)
	return result

func get_item_count() -> int:
	return _db.size()
