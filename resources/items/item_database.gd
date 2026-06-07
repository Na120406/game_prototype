extends Node

var _db: Dictionary = {}

func _ready() -> void:
	_load_all_items()

func _load_all_items() -> void:
	var dir := DirAccess.open("res://resources/items/definitions/")
	if dir == null:
		push_error("[ItemDB] Folder not found: res://resources/items/definitions/")
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var path := "res://resources/items/definitions/" + file_name
			var item: ItemData = load(path)
			if item != null and item.item_id != "":
				_db[item.item_id] = item
				print("[ItemDB] Loaded: %s" % item.item_id)
		file_name = dir.get_next()
	dir.list_dir_end()
	print("[ItemDB] Total items loaded: %d" % _db.size())

func get_item(item_id: String) -> ItemData:
	return _db.get(item_id, null)

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
