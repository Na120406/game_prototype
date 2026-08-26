extends Node
# =============================================================================
# ITEM HANDLER - Xử lý việc sử dụng items
# =============================================================================

signal item_used(item_id: String, item_data: ItemData)
signal item_equipped(item_id: String)
signal item_consumed(item_id: String)
signal item_planted(item_id: String, crop_id: String)

func _ready() -> void:
	if not item_planted.is_connected(_on_item_planted):
		item_planted.connect(_on_item_planted)

func use_item(item_id: String, from_inventory: bool = true) -> bool:
	var db = get_node_or_null("/root/ItemDB")
	var item_data: ItemData = null
	if db != null:
		item_data = db.get_item(item_id)
	if item_data == null:
		push_error("[ItemHandler] Unknown item: %s" % item_id)
		return false

	if not item_data.can_use():
		print("[ItemHandler] Cannot use item: %s" % item_id)
		return false

	match item_data.item_type:
		ItemData.Type.CONSUMABLE:
			_apply_consumable(item_data)
			if from_inventory:
				GameState.remove_item(item_id, 1)
			item_consumed.emit(item_id)
		ItemData.Type.TOOL:
			_apply_tool(item_data)
			item_equipped.emit(item_id)
		ItemData.Type.SEED:
			_plant_seed(item_data)
			if from_inventory:
				GameState.remove_item(item_id, 1)
		_:
			print("[ItemHandler] Unhandled item type for: %s" % item_id)
			return false

	item_used.emit(item_id, item_data)
	return true

# =============================================================================
# TOOLBAR SLOT USAGE (gắn với phím 1-5)
# =============================================================================
# Khi nhấn phím 1..5, dùng item ở GameState.toolbar[idx].
# Sau khi dùng (consumable/seed) sẽ consume từ TOOLBAR chứ không phải inventory.
# =============================================================================

func use_toolbar_slot(idx: int) -> bool:
	if idx < 0 or idx >= GameState.toolbar.size():
		return false
	var slot: Dictionary = GameState.toolbar[idx]
	var item_id: String = slot.get("id", "")
	if item_id == "":
		return false

	var db = get_node_or_null("/root/ItemDB")
	if db == null:
		return false
	var data: ItemData = db.get_item(item_id)
	if data == null:
		return false

	if not data.can_use():
		print("[ItemHandler] Cannot use toolbar item: %s" % item_id)
		return false

	match data.item_type:
		ItemData.Type.CONSUMABLE:
			_apply_consumable(data)
			GameState.consume_toolbar_slot(idx, 1)
			item_consumed.emit(item_id)
		ItemData.Type.TOOL:
			_apply_tool(data)
			item_equipped.emit(item_id)
		ItemData.Type.SEED:
			_plant_seed(data)
			GameState.consume_toolbar_slot(idx, 1)
		_:
			return false

	item_used.emit(item_id, data)
	return true

func _apply_consumable(data: ItemData) -> void:
	match data.effect_type:
		ItemData.Effect.RESTORE_ENERGY:
			GameState.modify_energy(data.energy_restore)
			print("[ItemHandler] Restored %.0f energy from %s" % [data.energy_restore, data.item_id])
		ItemData.Effect.RESTORE_HEALTH:
			GameState.modify_health(data.health_restore)
			print("[ItemHandler] Restored %.0f health from %s" % [data.health_restore, data.item_id])
		_:
			print("[ItemHandler] No effect for consumable: %s" % data.item_id)

func _apply_tool(data: ItemData) -> void:
	var tool_handler = get_node_or_null("/root/ToolHandler")
	if tool_handler != null:
		tool_handler.equip(data.item_id)
	else:
		push_error("[ItemHandler] ToolHandler not found!")

func _plant_seed(data: ItemData) -> void:
	if data.harvest_item_id != "":
		item_planted.emit(data.item_id, data.harvest_item_id)
		print("[ItemHandler] Seed planted: %s -> will yield %s" % [data.item_id, data.harvest_item_id])
	else:
		item_planted.emit(data.item_id, data.item_id)
		print("[ItemHandler] Seed planted: %s" % data.item_id)

func get_use_message(item_id: String) -> String:
	var db = get_node_or_null("/root/ItemDB")
	var data: ItemData = null
	if db != null:
		data = db.get_item(item_id)
	if data == null:
		return "Cannot use %s." % item_id

	match data.item_type:
		ItemData.Type.CONSUMABLE:
			match data.effect_type:
				ItemData.Effect.RESTORE_ENERGY:
					return "Restores %.0f energy." % data.energy_restore
		ItemData.Type.TOOL:
			return data.get_description() if data.has_method("get_description") else data.description
		ItemData.Type.SEED:
			return "Plant it to grow %s in %d days." % [data.harvest_item_id, data.grow_days]
		ItemData.Type.KEY_ITEM:
			return "A key item. Cannot be used."
		ItemData.Type.CURRENCY:
			return "Currency."
	return data.get_description() if data.has_method("get_description") else data.description

func _on_item_planted(seed_id: String, harvest_id: String) -> void:
	var farm: Node = get_tree().get_first_node_in_group("farm_manager")
	if farm == null:
		print("[ItemHandler] No farm_manager found, cannot plant seed.")
		return

	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		print("[ItemHandler] No player found, cannot determine plant cell.")
		return

	var farm_plot: Node = get_tree().get_first_node_in_group("farm_plot")
	var cell: Vector2i
	if farm_plot != null and farm_plot.has_method("get_player_facing_cell"):
		cell = farm_plot.get_player_facing_cell(player)
	elif player.has_method("get_facing_cell"):
		cell = player.get_facing_cell()
	else:
		push_error("[ItemHandler] Cannot determine facing cell!")
		return

	if farm.has_method("plant_from_seed"):
		if farm.plant_from_seed(cell, seed_id):
			print("[ItemHandler] Seed %s planted at cell %s" % [seed_id, str(cell)])
		else:
			print("[ItemHandler] Failed to plant seed %s at cell %s" % [seed_id, str(cell)])
	else:
		push_error("[ItemHandler] farm_manager missing plant_from_seed method!")
