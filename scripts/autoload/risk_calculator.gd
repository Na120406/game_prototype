extends Node
# =============================================================================
# RISK CALCULATOR (Máy tính Nguy hiểm)
# =============================================================================
# Chức năng: Tính toán mức độ nguy hiểm của các hoạt động
#
# Nguy hiểm ảnh hưởng đến:
#   - Quest outcomes (sống sót, bị thương, chết)
#   - NPC survival
#   - Event chains
#   - Gameplay decisions
#
# CÁC YẾU TỐ ẢNH HƯỞNG:
#   1. Base risk - nguy hiểm cơ bản của hoạt động
#   2. Weather modifier - thời tiết (bão tăng nguy hiểm)
#   3. Time modifier - thời gian (đêm nguy hiểm hơn)
#   4. Personality modifier - tính cách NPC
#   5. Escort modifier - có hộ tống không
#   6. Season modifier - mùa đông nguy hiểm hơn
#
# CÁCH SỬ DỤNG:
#   RiskCalculator.calculate_risk("shopkeeper_father", "mountain_trip") - tính risk
#   RiskCalculator.get_outcome_rolls(0.3) - xem kết quả với risk 30%
# =============================================================================

# =============================================================================
# HẰNG SỐ - NGUY HIỂM CƠ BẢN
# =============================================================================

# Base risk cho mỗi loại hoạt động (0.0 - 1.0)
const BASE_RISK: Dictionary = {
	"mountain_trip": 0.20,   # Đi núi: 20%
	"forest_walk": 0.10,    # Đi rừng: 10%
	"river_crossing": 0.15, # Qua sông: 15%
	"night_walk": 0.25,     # Đi ban đêm: 25%
	"work_field": 0.05,     # Làm việc đồng: 5%
}


# =============================================================================
# HẰNG SỐ - ẢNH HƯỞNG THỜI TIẾT
# =============================================================================

# Thời tiết xấu tăng nguy hiểm
const WEATHER_MODIFIER: Dictionary = {
	"clear": 0.0,       # Trời trong: không ảnh hưởng
	"overcast": 0.05,   # Âm u: +5%
	"fog": 0.10,       # Sương mù: +10%
	"drizzle": 0.08,   # Mưa phùn: +8%
	"rain": 0.15,       # Mưa: +15%
	"storm": 0.35,      # Bão: +35%
	"heavy_rain": 0.45, # Mưa to: +45%
	"mist": 0.12,        # Sương: +12%
}


# =============================================================================
# HẰNG SỐ - ẢNH HƯỞNG THỜI GIAN
# =============================================================================

# Ban đêm nguy hiểm hơn ban ngày
const TIME_MODIFIER: Dictionary = {
	"morning": 0.0,    # Sáng: không ảnh hưởng
	"noon": 0.0,      # Trưa: không ảnh hưởng
	"afternoon": 0.02,  # Chiều: +2%
	"evening": 0.10,    # Tối: +10%
	"night": 0.20,      # Đêm: +20%
}


# =============================================================================
# HẰNG SỐ - ẢNH HƯỞNG TÍNH CÁCH
# =============================================================================

# Tính cách ảnh hưởng đến khả năng sinh tồn
const PERSONALITY_MODIFIER: Dictionary = {
	"cautious": -0.10,  # Cẩn thận: -10% (ít nguy hiểm hơn)
	"normal": 0.0,      # Bình thường: 0%
	"reckless": 0.15,  # Liều lĩnh: +15% (nguy hiểm hơn)
	"old": 0.10,        # Già: +10%
	"young": 0.05,      # Trẻ: +5%
}


# =============================================================================
# HÀM KHỞI TẠO (_ready)
# =============================================================================

func _ready() -> void:
	print("[RiskCalculator] Ready.")


# =============================================================================
# HÀM TÍNH TOÁN NGUY HIỂM (calculate_risk)
# =============================================================================
# Tính tổng mức độ nguy hiểm của một hoạt động
#
# Tham số:
#   npc_id: String - ID NPC thực hiện
#   activity: String - loại hoạt động
#   context: Dictionary - ngữ cảnh bổ sung (thời tiết, thời gian...)
#
# Trả về: float - mức độ nguy hiểm (0.0 - 1.0)
#   0.0 = không nguy hiểm
#   0.3 = 30% khả năng có sự cố
#   1.0 = chắc chắn có sự cố

func calculate_risk(npc_id: String, activity: String, context: Dictionary = {}) -> float:
	# Lấy base risk
	var base: float = BASE_RISK.get(activity, 0.15)

	# Tính các modifier
	var weather_mod: float = _get_weather_modifier(context)
	var time_mod: float = _get_time_modifier(context)
	var personality_mod: float = _get_personality_modifier(npc_id, context)
	var escort_mod: float = _get_escort_modifier(context)
	var season_mod: float = _get_season_modifier()

	# Tổng hợp tất cả
	var total: float = base + weather_mod + time_mod + personality_mod + escort_mod + season_mod
	
	# Giới hạn trong khoảng 0.0 - 1.0
	total = clampf(total, 0.0, 1.0)

	return total


# =============================================================================
# HÀM LẤY MODIFIER THỜI TIẾT (_get_weather_modifier)
# =============================================================================

func _get_weather_modifier(context: Dictionary) -> float:
	# Lấy thời tiết từ context hoặc từ WeatherSystem
	var weather: String = context.get("weather", WeatherSystem.get_today_weather())
	return WEATHER_MODIFIER.get(weather, 0.0)


# =============================================================================
# HÀM LẤY MODIFIER THỜI GIAN (_get_time_modifier)
# =============================================================================

func _get_time_modifier(context: Dictionary) -> float:
	# Lấy giờ từ context hoặc từ GameState
	var time: float = context.get("time", GameState.current_time)
	var hour: int = int(time)
	
	# Xác định thời điểm trong ngày
	if hour >= 6 and hour < 12:
		return TIME_MODIFIER["morning"]
	elif hour >= 12 and hour < 14:
		return TIME_MODIFIER["noon"]
	elif hour >= 14 and hour < 18:
		return TIME_MODIFIER["afternoon"]
	elif hour >= 18 and hour < 21:
		return TIME_MODIFIER["evening"]
	return TIME_MODIFIER["night"]


# =============================================================================
# HÀM LẤY MODIFIER TÍNH CÁCH (_get_personality_modifier)
# =============================================================================

func _get_personality_modifier(npc_id: String, context: Dictionary) -> float:
	var personality: String = context.get("personality", "normal")
	return PERSONALITY_MODIFIER.get(personality, 0.0)


# =============================================================================
# HÀM LẤY MODIFIER HỘ TỐNG (_get_escort_modifier)
# =============================================================================

func _get_escort_modifier(context: Dictionary) -> float:
	# Có player hộ tống -> giảm nguy hiểm nhiều nhất
	if context.get("player_escorted", false):
		return -0.20  # -20% (an toàn hơn)
	
	# Có người hộ tống khác -> giảm nguy hiểm ít hơn
	if context.get("has_escort", false):
		return -0.10  # -10%
	
	return 0.0  # Không có hộ tống


# =============================================================================
# HÀM LẤY MODIFIER MÙA (_get_season_modifier)
# =============================================================================

func _get_season_modifier() -> float:
	match WeatherSystem.current_season:
		"winter": return 0.15   # Mùa đông: nguy hiểm +15%
		"autumn": return 0.08   # Mùa thu: nguy hiểm +8%
		"summer": return -0.02  # Mùa hè: an toàn hơn -2%
		"spring": return 0.0     # Mùa xuân: bình thường
	return 0.0


# =============================================================================
# HÀM XEM KẾT QUẢ (get_outcome_rolls)
# =============================================================================
# Tung xíu để xem kết quả dựa trên risk
#
# Tham số:
#   risk: float - mức độ nguy hiểm (0.0 - 1.0)
#
# Trả về: Dictionary chứa:
#   - outcome: "safe", "delayed", "injured", "dead"
#   - roll: số ngẫu nhiên đã tung
#   - description: mô tả kết quả

func get_outcome_rolls(risk: float) -> Dictionary:
	# Tung xíu từ 0.0 đến 1.0
	var roll: float = randf()

	# Xác định kết quả dựa trên roll và risk
	if roll < risk * 0.4:
		# 0% - 40% của risk = DEAD (chết)
		return {"outcome": "dead", "roll": roll, "description": "Worst outcome."}
	elif roll < risk * 0.8:
		# 40% - 80% của risk = INJURED (bị thương)
		return {"outcome": "injured", "roll": roll, "description": "Something went wrong."}
	elif roll < risk:
		# 80% - 100% của risk = DELAYED (bị trì hoãn)
		return {"outcome": "delayed", "roll": roll, "description": "Minor complication."}
	else:
		# > risk = SAFE (an toàn)
		return {"outcome": "safe", "roll": roll, "description": "No incident."}


# =============================================================================
# HÀM LẤY MÔ TẢ NGUY HIỂM (get_activity_risk_description)
# =============================================================================
# Lấy text mô tả tại sao hoạt động nguy hiểm

func get_activity_risk_description(activity: String) -> String:
	match activity:
		"mountain_trip": return "Mountain paths become dangerous in bad weather."
		"forest_walk": return "The forest has uneven terrain."
		"river_crossing": return "Water levels rise quickly."
		"night_walk": return "Darkness hides many dangers."
		"work_field": return "Physical labor has its hazards."
	return "An ordinary activity."
