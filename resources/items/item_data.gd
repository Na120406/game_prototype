class_name ItemData
extends Resource

enum Type {
	CONSUMABLE = 0,
	TOOL = 1,
	SEED = 2,
	KEY_ITEM = 3,
	CURRENCY = 4,
	MISC = 5,
}

enum Category {
	FARM_PRODUCE = 0,
	SEED = 1,
	CONSUMABLE_FOOD = 2,
	TOOL = 3,
	KEY_ITEM = 4,
	CURRENCY = 5,
	MISC = 6,
}

enum Effect {
	NONE = 0,
	RESTORE_ENERGY = 1,
	RESTORE_HEALTH = 2,
	WATER_CROPS = 3,
	CLIMB = 4,
	GROW_CROP = 5,
}

@export_group("Identity")
@export var item_id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""

@export_group("Visuals")
@export var icon: String = "?"
@export var item_color: Color = Color.WHITE
@export var stack_size: int = 99

@export_group("Categorization")
@export var item_type: Type = Type.MISC
@export var item_category: Category = Category.MISC
@export var effect_type: Effect = Effect.NONE

@export_group("Economy")
@export var buy_price: int = 0
@export var sell_price: int = 0

@export_group("Effect Values")
@export var energy_restore: float = 0.0
@export var health_restore: float = 0.0
@export var crop_to_spawn: String = ""
@export var grow_days: int = 0
@export var harvest_item_id: String = ""
@export var grow_season: String = "spring"

func can_use() -> bool:
	return item_type in [Type.CONSUMABLE, Type.TOOL, Type.SEED]

func can_stack() -> bool:
	return stack_size > 1

func get_sell_price() -> int:
	if sell_price > 0:
		return sell_price
	return int(buy_price * 0.5)

func get_display_name() -> String:
	if display_name != "":
		return display_name
	return item_id.capitalize().replace("_", " ")

func get_type_name() -> String:
	match item_type:
		Type.CONSUMABLE: return "Consumable"
		Type.TOOL: return "Tool"
		Type.SEED: return "Seed"
		Type.KEY_ITEM: return "Key Item"
		Type.CURRENCY: return "Currency"
		Type.MISC: return "Misc"
	return "Unknown"

func get_category_name() -> String:
	match item_category:
		Category.FARM_PRODUCE: return "Farm Produce"
		Category.SEED: return "Seed"
		Category.CONSUMABLE_FOOD: return "Food & Drink"
		Category.TOOL: return "Tool"
		Category.KEY_ITEM: return "Key Item"
		Category.CURRENCY: return "Currency"
		Category.MISC: return "Miscellaneous"
	return "Unknown"

func get_effect_name() -> String:
	match effect_type:
		Effect.NONE: return "None"
		Effect.RESTORE_ENERGY: return "Restore Energy"
		Effect.RESTORE_HEALTH: return "Restore Health"
		Effect.WATER_CROPS: return "Water Crops"
		Effect.CLIMB: return "Climb"
		Effect.GROW_CROP: return "Grow Crop"
	return "Unknown"
