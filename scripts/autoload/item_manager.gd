extends Node
# =============================================================================
# ITEM MANAGER - Xử lý việc nhặt items
# =============================================================================

func _ready() -> void:
	add_to_group("item_manager")
	print("[ItemManager] Ready.")

func on_item_pickup(item_id: String, amount: int = 1) -> bool:
	if item_id == "":
		push_warning("[ItemManager] Cannot pickup empty item_id")
		return false
	if not GameState.add_item(item_id, amount):
		push_warning("[ItemManager] Inventory full; pickup rejected: %s x%d" % [item_id, amount])
		return false
	print("[ItemManager] Picked up: %s x%d" % [item_id, amount])
	return true

func on_item_drop(item_id: String, amount: int = 1) -> bool:
	if not GameState.has_item(item_id, amount):
		push_warning("[ItemManager] Cannot drop %s x%d - not enough in inventory" % [item_id, amount])
		return false
	if not GameState.remove_item(item_id, amount):
		push_warning("[ItemManager] Drop failed: %s x%d" % [item_id, amount])
		return false
	print("[ItemManager] Dropped: %s x%d" % [item_id, amount])
	return true
