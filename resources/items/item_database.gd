extends Node

# Preload các resource để Godot đưa chúng chắc chắn vào Web export. Việc load
# bằng đường dẫn động/DirAccess có thể không hoạt động như desktop khi chạy
# trên itch.io.
const ITEM_RESOURCES: Array[ItemData] = [
	preload("res://resources/items/definitions/apple.tres"),
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
	preload("res://resources/items/definitions/potato_harvest.tres"),
	preload("res://resources/items/definitions/tomato_harvest.tres"),
	preload("res://resources/items/definitions/turnip_harvest.tres"),
	preload("res://resources/items/definitions/corn_harvest.tres"),
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
	# Preload array chắc chắn được đưa vào Web export. Load trực tiếp từ constant.
	for item: ItemData in ITEM_RESOURCES:
		if item != null and item.item_id != "":
			if _db.has(item.item_id):
				continue  # tránh duplicate khi scan lại
			_db[item.item_id] = item
			print("[ItemDB] Loaded: %s" % item.item_id)

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
					if item != null and item.item_id != "" and not _db.has(item.item_id):
						_db[item.item_id] = item
						print("[ItemDB] Loaded: %s" % item.item_id)
			file_name = dir.get_next()
		dir.list_dir_end()
	print("[ItemDB] Total items loaded: %d" % _db.size())

func get_item(item_id: String) -> ItemData:
	return _db.get(item_id, null)

func get_item_or_null(item_id: String) -> ItemData:
	var item: ItemData = _db.get(item_id, null)
	if item == null:
		push_warning("[ItemDB] Item not found: %s" % item_id)
	return item

func safe_get_item(item_id: String, default_values: Dictionary = {}) -> ItemData:
	var item: ItemData = _db.get(item_id, null)
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
	var item: ItemData = _db.get(item_id, null)
	if item == null:
		push_warning("[ItemDB] Item not found: %s" % item_id)
		return null
	if item.item_type != expected_type:
		push_warning("[ItemDB] Item %s has type %s, expected %s" % [item_id, item.item_type, expected_type])
	return item

func require_item(item_id: String) -> ItemData:
	var item: ItemData = _db.get(item_id, null)
	if item == null:
		push_error("[ItemDB] CRITICAL: Required item not found: %s" % item_id)
	return item

func is_valid_seed(seed_id: String) -> bool:
	var item: ItemData = _db.get(seed_id, null)
	if item == null:
		return false
	return item.item_type == ItemData.Type.SEED

func is_valid_tool(tool_id: String) -> bool:
	var item: ItemData = _db.get(tool_id, null)
	if item == null:
		return false
	return item.item_type == ItemData.Type.TOOL

func is_valid_consumable(item_id: String) -> bool:
	var item: ItemData = _db.get(item_id, null)
	if item == null:
		return false
	return item.item_type == ItemData.Type.CONSUMABLE

func has_item(item_id: String) -> bool:
	return _db.has(item_id)

func get_all_items() -> Array[ItemData]:
	return _db.values()

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
