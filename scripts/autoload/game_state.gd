extends Node

signal inventory_changed

var player_name: String = "Player"
var current_day: int = 1
var current_time: float = 6.0
var energy: float = 100.0
var max_energy: float = 100.0
var stamina_drain_rate: float = 5.0

var is_sleeping: bool = false
var is_paused: bool = false

var inventory: Array[Dictionary] = []
var equipped_tool: String = "none"

var world_flags: Dictionary = {}
var discovered_areas: Array[String] = []
var lore_fragments_found: int = 0

var health: float = 100.0
var max_health: float = 100.0

var weather_type: String = "clear"
var is_day: bool = true
var gold: int = 100
var farm_cells_data: Dictionary = {}

func _ready() -> void:
	print("[GameState] Initialized — Day %d, %.0f:00" % [current_day, current_time])

func advance_day() -> void:
	current_day += 1
	current_time = 6.0
	energy = max_energy
	is_day = true
	print("[GameState] Day %d begins." % current_day)

func advance_time(hours: float) -> void:
	current_time += hours
	if current_time >= 22.0:
		is_day = false
	if current_time >= 24.0:
		advance_day()
	print("[GameState] Time: %.0f:00" % current_time)

func modify_energy(amount: float) -> void:
	energy = clampf(energy + amount, 0.0, max_energy)
	if energy <= 0.0:
		print("[GameState] Energy depleted! Forcing sleep...")

func modify_health(amount: float) -> void:
	health = clampf(health + amount, 0.0, max_health)
	print("[GameState] Health: %.0f / %.0f" % [health, max_health])

func add_item(item_id: String, amount: int = 1) -> bool:
	for i: int in range(inventory.size()):
		var existing_id: String = inventory[i].get("id", "")
		if existing_id == item_id:
			inventory[i]["amount"] = inventory[i].get("amount", 0) + amount
			print("[GameState] Added %d x %s (now %d)" % [amount, item_id, inventory[i]["amount"]])
			inventory_changed.emit()
			return true
	inventory.append({"id": item_id, "amount": amount})
	print("[GameState] Added %d x %s to inventory" % [amount, item_id])
	inventory_changed.emit()
	return true

func remove_item(item_id: String, amount: int = 1) -> bool:
	for i: int in range(inventory.size()):
		var existing_id: String = inventory[i].get("id", "")
		if existing_id == item_id:
			inventory[i]["amount"] = inventory[i].get("amount", 0) - amount
			if inventory[i]["amount"] <= 0:
				inventory.remove_at(i)
			print("[GameState] Removed %d x %s" % [amount, item_id])
			inventory_changed.emit()
			return true
	return false

func has_item(item_id: String, amount: int = 1) -> bool:
	for item: Dictionary in inventory:
		var item_id_found: String = item.get("id", "")
		var item_amount: int = item.get("amount", 0)
		if item_id_found == item_id and item_amount >= amount:
			return true
	return false

func get_item_count(item_id: String) -> int:
	for item: Dictionary in inventory:
		var item_id_found: String = item.get("id", "")
		if item_id_found == item_id:
			return item.get("amount", 0)
	return 0

func set_flag(flag: String, value: Variant = true) -> void:
	world_flags[flag] = value
	print("[GameState] Flag set: %s = %s" % [flag, str(value)])

func get_flag(flag: String, default: Variant = false) -> Variant:
	return world_flags.get(flag, default)

func discover_area(area_id: String) -> bool:
	if area_id in discovered_areas:
		return false
	discovered_areas.append(area_id)
	print("[GameState] New area discovered: %s" % area_id)
	return true

func reset() -> void:
	current_day = 1
	current_time = 6.0
	energy = max_energy
	health = max_health
	is_sleeping = false
	is_paused = false
	inventory.clear()
	world_flags.clear()
	discovered_areas.clear()
	lore_fragments_found = 0
	weather_type = "clear"
	is_day = true
	gold = 100
	print("[GameState] Game state reset.")
