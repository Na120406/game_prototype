extends Node

func _ready() -> void:
	add_to_group("item_manager")
	print("[ItemManager] Ready.")

func on_item_pickup(item_id: String) -> void:
	GameState.add_item(item_id, 1)
	print("[ItemManager] Picked up: %s" % item_id)
