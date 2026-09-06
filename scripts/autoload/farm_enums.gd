extends Node
# =============================================================================
# SHARED ENUMS AND CONSTANTS FOR FARM SYSTEM
# =============================================================================
# File này chứa tất cả enum và constant dùng chung giữa:
#   - farm_manager.gd
#   - crop_visual_manager.gd
#   - farm_plot.gd
#   - Các script khác liên quan đến farming
#
# ĐƯỢC ĐĂNG KÝ LÀ AUTOLOAD với tên "FarmEnums"
# SỬ DỤNG: FarmEnums.CropState.EMPTY, FarmEnums.CropType.WHEAT
# =============================================================================

# -----------------------------------------------------------------------------
# CROP STATES - Trạng thái của ô đất/cây trồng
# -----------------------------------------------------------------------------
enum CropState {
	EMPTY = 0,     # Ô đất trống, chưa cày
	PLOWED = 1,   # Đã cày, có thể gieo hạt
	SEEDED = 2,    # Đã gieo hạt, đang nảy mầm
	SPROUTED = 3,  # Đã nảy mầm
	GROWING = 4,   # Đang lớn
	MATURE = 5,    # Đã chín, có thể thu hoạch
	WILTED = 6,    # Đã héo (không được tưới đủ)
}

# -----------------------------------------------------------------------------
# CROP TYPES - Loại cây trồng
# -----------------------------------------------------------------------------
enum CropType {
	NONE = 0,
	WHEAT = 1,
	CORN = 2,
	TOMATO = 3,
	POTATO = 4,
	TURNIP = 5,
	MYSTERY_PLANT = 6,
}

# FarmEnums chỉ còn sở hữu enum/trạng thái. Dữ liệu của năm cây trồng sản xuất
# nằm tại crop_profiles.json và được ConfigManager cung cấp cho mọi consumer.
const MYSTERY_PROFILE: Dictionary = {
	"water_need": 1,
	"growth_per_water": 0.20,
	"grow_days": 10,
	"produce_item_id": "strange_fruit",
}

# -----------------------------------------------------------------------------
# HELPER FUNCTIONS
# -----------------------------------------------------------------------------

## Lấy CropType từ seed item ID
static func get_crop_type_from_seed(seed_id: String) -> CropType:
	var config := _get_config_manager()
	if config != null:
		var profile: Dictionary = config.call("get_crop_profile", seed_id)
		return int(profile.get("crop_type", CropType.NONE)) as CropType
	return CropType.NONE

## Lấy harvest item ID từ CropType
static func get_harvest_id(crop_type: CropType) -> String:
	if crop_type == CropType.MYSTERY_PLANT:
		return str(MYSTERY_PROFILE["produce_item_id"])
	var config := _get_config_manager()
	if config != null:
		var profile: Dictionary = config.call("get_crop_profile_for_type", int(crop_type))
		return str(profile.get("produce_item_id", ""))
	return ""

## Lấy thông số nước mặc định từ CropType
static func get_water_profile(crop_type: CropType) -> Dictionary:
	if crop_type == CropType.MYSTERY_PLANT:
		return MYSTERY_PROFILE.duplicate(true)
	var config := _get_config_manager()
	if config != null:
		var profile: Dictionary = config.call("get_crop_profile_for_type", int(crop_type))
		if not profile.is_empty():
			return profile
	return {"water_need": 1, "growth_per_water": 0.25, "grow_days": 6}

static func _get_config_manager() -> Node:
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree:
		return (main_loop as SceneTree).root.get_node_or_null("ConfigManager")
	return null

## Kiểm tra CropState có phải là trạng thái "sống" không
static func is_living_state(state: CropState) -> bool:
	return state in [CropState.SEEDED, CropState.SPROUTED, CropState.GROWING]

## Kiểm tra CropState có thể tưới nước không
static func can_water_state(state: CropState) -> bool:
	return state in [CropState.PLOWED, CropState.SEEDED, CropState.SPROUTED, CropState.GROWING, CropState.MATURE]

## Lấy tên trạng thái dạng string
static func get_state_name(state: CropState) -> String:
	match state:
		CropState.EMPTY: return "EMPTY"
		CropState.PLOWED: return "PLOWED"
		CropState.SEEDED: return "SEEDED"
		CropState.SPROUTED: return "SPROUTED"
		CropState.GROWING: return "GROWING"
		CropState.MATURE: return "MATURE"
		CropState.WILTED: return "WILTED"
	return "UNKNOWN"

## Lấy tên loại cây dạng string
static func get_crop_name(crop_type: CropType) -> String:
	match crop_type:
		CropType.NONE: return "None"
		CropType.WHEAT: return "Wheat"
		CropType.CORN: return "Corn"
		CropType.TOMATO: return "Tomato"
		CropType.POTATO: return "Potato"
		CropType.TURNIP: return "Turnip"
		CropType.MYSTERY_PLANT: return "Mystery Plant"
	return "Unknown"
