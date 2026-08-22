extends RefCounted
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

# -----------------------------------------------------------------------------
# SEED TO CROP MAPPING - Chuyển từ seed item ID sang CropType
# -----------------------------------------------------------------------------
const SEED_TO_CROP: Dictionary = {
	"seed_wheat": CropType.WHEAT,
	"seed_corn": CropType.CORN,
	"seed_tomato": CropType.TOMATO,
	"seed_potato": CropType.POTATO,
	"seed_turnip": CropType.TURNIP,
}

# -----------------------------------------------------------------------------
# CROP TO HARVEST MAPPING - Chuyển từ CropType sang harvest item ID
# -----------------------------------------------------------------------------
const CROP_TO_HARVEST: Dictionary = {
	CropType.WHEAT: "wheat",
	CropType.CORN: "corn",
	CropType.TOMATO: "tomato_harvest",
	CropType.POTATO: "potato_harvest",
	CropType.TURNIP: "turnip_harvest",
	CropType.MYSTERY_PLANT: "strange_fruit",
}

# -----------------------------------------------------------------------------
# DEFAULT WATER PROFILES - Thông số nước mặc định cho mỗi loại cây
# -----------------------------------------------------------------------------
# water_need: Số ngày liên tiếp không tưới trước khi héo (1 = phải tưới mỗi ngày)
# growth_per_water: Tốc độ tăng trưởng mỗi lần tưới (0.0 - 1.0)
const DEFAULT_WATER_PROFILES: Dictionary = {
	CropType.WHEAT: {"water_need": 2, "growth_per_water": 0.25, "grow_days": 5},
	CropType.CORN: {"water_need": 1, "growth_per_water": 0.20, "grow_days": 6},
	CropType.TOMATO: {"water_need": 1, "growth_per_water": 0.20, "grow_days": 7},
	CropType.POTATO: {"water_need": 3, "growth_per_water": 0.25, "grow_days": 8},
	CropType.TURNIP: {"water_need": 2, "growth_per_water": 0.20, "grow_days": 4},
	CropType.MYSTERY_PLANT: {"water_need": 1, "growth_per_water": 0.20, "grow_days": 10},
}

# -----------------------------------------------------------------------------
# HELPER FUNCTIONS
# -----------------------------------------------------------------------------

## Lấy CropType từ seed item ID
static func get_crop_type_from_seed(seed_id: String) -> CropType:
	return SEED_TO_CROP.get(seed_id, CropType.NONE)

## Lấy harvest item ID từ CropType
static func get_harvest_id(crop_type: CropType) -> String:
	return CROP_TO_HARVEST.get(crop_type, "")

## Lấy thông số nước mặc định từ CropType
static func get_water_profile(crop_type: CropType) -> Dictionary:
	if DEFAULT_WATER_PROFILES.has(crop_type):
		return DEFAULT_WATER_PROFILES[crop_type]
	return {"water_need": 1, "growth_per_water": 0.25, "grow_days": 6}

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
