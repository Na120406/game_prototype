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
	GameState.add_item(item_id, amount)
	print("[ItemManager] Picked up: %s x%d" % [item_id, amount])
	return true

func on_item_drop(item_id: String, amount: int = 1) -> bool:
	if not GameState.has_item(item_id, amount):
		push_warning("[ItemManager] Cannot drop %s x%d - not enough in inventory" % [item_id, amount])
		return false
	GameState.remove_item(item_id, amount)
	print("[ItemManager] Dropped: %s x%d" % [item_id, amount])
	return true
