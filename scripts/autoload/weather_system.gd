extends Node
# =============================================================================
# WEATHER SYSTEM (Hệ thống Thời tiết)
# =============================================================================
# Chức năng: Quản lý thời tiết trong game
#
# Các loại thời tiết:
#   - CLEAR: Trời trong
#   - OVERCAST: Âm u
#   - FOG: Sương mù
#   - DRIZZLE: Mưa phùn
#   - RAIN: Mưa
#   - STORM: Bão
#   - HEAVY_RAIN: Mưa to
#   - MIST: Sương mù nhẹ
#
# Tính năng:
#   - Thời tiết thay đổi theo mùa
#   - Hệ thống dự báo (3 ngày)
#   - Thời tiết bất thường (anomaly)
#   - Tính risk cho các sự kiện
#
# CÁCH SỬ DỤNG:
#   WeatherSystem.get_today_weather() - lấy thời tiết hiện tại
#   WeatherSystem.get_weather_risk() - lấy mức độ nguy hiểm
# =============================================================================

# =============================================================================
# TÍN HIỆU (SIGNALS)
# =============================================================================

# Phát ra khi thời tiết thay đổi
signal weather_changed(new_weather: String, intensity: float)

# Phát ra khi dự báo được cập nhật
signal forecast_updated(forecast: Array)

# Phát ra khi mùa thay đổi
signal season_changed(new_season: String)

# Phát ra khi có thời tiết bất thường (horror element)
signal anomaly_weather_triggered(weather_type: String)


# =============================================================================
# ENUM - CÁC LOẠI THỜI TIẾT
# =============================================================================

enum Weather {
	CLEAR,       # Trời trong
	OVERCAST,    # Âm u
	FOG,         # Sương mù
	DRIZZLE,     # Mưa phùn
	RAIN,        # Mưa
	STORM,       # Bão
	HEAVY_RAIN, # Mưa to
	MIST,        # Sương mù nhẹ
}


# =============================================================================
# HẰNG SỐ - TÊN THỜI TIẾT
# =============================================================================

# Map enum -> tên string
const WEATHER_NAMES := {
	Weather.CLEAR: "clear",        # Trời trong
	Weather.OVERCAST: "overcast",  # Âm u
	Weather.FOG: "fog",            # Sương mù
	Weather.DRIZZLE: "drizzle",    # Mưa phùn
	Weather.RAIN: "rain",          # Mưa
	Weather.STORM: "storm",        # Bão
	Weather.HEAVY_RAIN: "heavy_rain",  # Mưa to
	Weather.MIST: "mist",          # Sương mù nhẹ
}


# =============================================================================
# HẰNG SỐ - MỨC ĐỘ NGUY HIỂM
# =============================================================================

# Risk của mỗi loại thời tiết (ảnh hưởng đến quest, farming...)
const WEATHER_RISK := {
	"clear": 0.0,       # Không nguy hiểm
	"overcast": 0.05,   # Hơi nguy hiểm
	"fog": 0.1,         # Nguy hiểm nhẹ
	"drizzle": 0.15,   # Nguy hiểm nhẹ
	"rain": 0.25,       # Nguy hiểm vừa
	"storm": 0.45,      # Nguy hiểm
	"heavy_rain": 0.6,  # Rất nguy hiểm
	"mist": 0.2,        # Nguy hiểm nhẹ
}


# =============================================================================
# CÁC BIẾN TRẠNG THÁI
# =============================================================================

# Thời tiết hiện tại (string)
var current_weather: String = "clear"

# Cường độ thời tiết (0.0 - 1.0)
var weather_intensity: float = 0.0

# Thời gian kéo dài thời tiết (giờ game)
var weather_duration_hours: float = 8.0

# Timer đếm thời gian thời tiết
var weather_timer: float = 0.0

# Dự báo thời tiết 3 ngày tới
var forecast: Array[Dictionary] = []


# =============================================================================
# CÁC BIẾN MÙA
# =============================================================================

# Mùa hiện tại
var current_season: String = "spring"

# Đếm ngày trong mùa
var season_day_counter: int = 1

# Số ngày mỗi mùa
var season_lengths := {
	"spring": 30,   # Xuân: 30 ngày
	"summer": 30,   # Hạ: 30 ngày
	"autumn": 30,   # Thu: 30 ngày
	"winter": 30,   # Đông: 30 ngày
}


# =============================================================================
# BIẾN ANOMALY (THỜI TIẾT BẤT THƯỜNG)
# =============================================================================

# Có đang trong thời tiết bất thường không
var anomaly_weather_active: bool = false

# Đếm số ngày anomaly đã xảy ra
var anomaly_weather_count: int = 0


# =============================================================================
# HÀM KHỞI TẠO (_ready)
# =============================================================================

func _ready() -> void:
	# Tạo dự báo ban đầu
	_generate_forecast()
	# Tung xíu thời tiết đầu tiên
	_roll_daily_weather()
	print("[WeatherSystem] Ready. Season: %s, Weather: %s" % [current_season, current_weather])


# =============================================================================
# HÀM CẬP NHẬT MỖI FRAME (_process)
# =============================================================================
# Kiểm tra và thay đổi thời tiết theo thời gian

func _process(delta: float) -> void:
	# Tăng timer
	weather_timer += delta
	
	# Tính thời gian đã trôi (có tính time_scale)
	var time_scale: float = TimeManager.time_scale
	var hours_elapsed: float = weather_timer * time_scale
	
	# Nếu đã đến lúc đổi thời tiết
	if hours_elapsed >= weather_duration_hours:
		_roll_daily_weather()
		weather_timer = 0.0


# =============================================================================
# HÀM TUNG XÍU THỜI TIẾT (_roll_daily_weather)
# =============================================================================
# Random thời tiết mới dựa trên mùa
# Mỗi mùa có xác suất khác nhau cho các loại thời tiết

func _roll_daily_weather() -> void:
	# Random số từ 0.0 đến 1.0
	var roll: float = randf()
	var weather_type: Weather
	var intensity: float

	# =================================================================
	# NẾU ĐANG TRONG ANOMALY WEATHER
	# =================================================================
	if anomaly_weather_active:
		# Luôn là bão khi có anomaly
		weather_type = Weather.STORM
		intensity = 0.8
		anomaly_weather_count += 1
		
		# Sau 3 ngày thì kết thúc anomaly
		if anomaly_weather_count >= 3:
			anomaly_weather_active = false
			anomaly_weather_count = 0
	
	# =================================================================
	# MÙA ĐÔNG (WINTER)
	# =================================================================
	elif current_season == "winter":
		if roll < 0.25: weather_type = Weather.CLEAR
		elif roll < 0.45: weather_type = Weather.OVERCAST
		elif roll < 0.65: weather_type = Weather.FOG
		elif roll < 0.8: weather_type = Weather.MIST
		elif roll < 0.92: weather_type = Weather.DRIZZLE
		else: weather_type = Weather.HEAVY_RAIN
	
	# =================================================================
	# MÙA THU (AUTUMN)
	# =================================================================
	elif current_season == "autumn":
		if roll < 0.25: weather_type = Weather.CLEAR
		elif roll < 0.4: weather_type = Weather.OVERCAST
		elif roll < 0.55: weather_type = Weather.FOG
		elif roll < 0.7: weather_type = Weather.DRIZZLE
		elif roll < 0.85: weather_type = Weather.RAIN
		else: weather_type = Weather.STORM
	
	# =================================================================
	# MÙA HẠ (SUMMER)
	# =================================================================
	elif current_season == "summer":
		if roll < 0.45: weather_type = Weather.CLEAR
		elif roll < 0.6: weather_type = Weather.OVERCAST
		elif roll < 0.72: weather_type = Weather.FOG
		elif roll < 0.85: weather_type = Weather.DRIZZLE
		elif roll < 0.95: weather_type = Weather.RAIN
		else: weather_type = Weather.STORM
	
	# =================================================================
	# MÙA XUÂN (SPRING) - MẶC ĐỊNH
	# =================================================================
	else:
		if roll < 0.35: weather_type = Weather.CLEAR
		elif roll < 0.5: weather_type = Weather.OVERCAST
		elif roll < 0.65: weather_type = Weather.FOG
		elif roll < 0.78: weather_type = Weather.DRIZZLE
		elif roll < 0.9: weather_type = Weather.RAIN
		else: weather_type = Weather.STORM

	# =================================================================
	# CẬP NHẬT TRẠNG THÁI
	# =================================================================
	current_weather = WEATHER_NAMES[weather_type]
	intensity = _roll_intensity(weather_type)
	weather_intensity = intensity
	weather_duration_hours = _roll_duration(weather_type)

	# Cập nhật GameState để các hệ thống khác dùng được
	GameState.weather_type = current_weather
	
	# Phát tín hiệu thay đổi
	weather_changed.emit(current_weather, intensity)


# =============================================================================
# HÀM TUNG XÍU CƯỜNG ĐỘ (_roll_intensity)
# =============================================================================
# Random cường độ thời tiết

func _roll_intensity(wtype: Weather) -> float:
	match wtype:
		Weather.CLEAR: return randf_range(0.0, 0.1)
		Weather.OVERCAST: return randf_range(0.1, 0.3)
		Weather.FOG: return randf_range(0.3, 0.5)
		Weather.DRIZZLE: return randf_range(0.2, 0.4)
		Weather.RAIN: return randf_range(0.4, 0.65)
		Weather.STORM: return randf_range(0.6, 0.8)
		Weather.HEAVY_RAIN: return randf_range(0.7, 1.0)
		Weather.MIST: return randf_range(0.25, 0.5)
	return 0.5


# =============================================================================
# HÀM TUNG XÍU THỜI GIAN (_roll_duration)
# =============================================================================
# Random thời gian kéo dài thời tiết

func _roll_duration(wtype: Weather) -> float:
	match wtype:
		Weather.CLEAR: return randf_range(6.0, 12.0)    # Trời trong có thể kéo dài
		Weather.STORM: return randf_range(2.0, 4.0)      # Bão ngắn
		Weather.HEAVY_RAIN: return randf_range(3.0, 6.0)
		Weather.RAIN: return randf_range(4.0, 8.0)
		Weather.FOG: return randf_range(4.0, 10.0)
	return randf_range(4.0, 10.0)  # Mặc định 4-10 giờ


# =============================================================================
# HÀM TẠO DỰ BÁO (_generate_forecast)
# =============================================================================
# Tạo dự báo thời tiết 3 ngày tới

func _generate_forecast() -> void:
	forecast.clear()
	
	# Tạo dự báo cho 3 ngày tới
	for i: int in range(3):
		var day_ahead: int = i + 1
		var fake_weather: String = _roll_forecast_weather()
		forecast.append({
			"day": GameState.current_day + day_ahead,
			"weather": fake_weather,
			"accurate": i == 0,  # Chỉ ngày mai là chính xác
		})
	
	forecast_updated.emit(forecast)


# =============================================================================
# HÀM TUNG XÍU THỜI TIẾT DỰ BÁO (_roll_forecast_weather)
# =============================================================================

func _roll_forecast_weather() -> String:
	var roll: float = randf()
	if roll < 0.4: return "clear"
	elif roll < 0.6: return "overcast"
	elif roll < 0.75: return "drizzle"
	elif roll < 0.85: return "rain"
	elif roll < 0.92: return "fog"
	elif roll < 0.97: return "storm"
	else: return "heavy_rain"


# =============================================================================
# HÀM LẤY MỨC ĐỘ NGUY HIỂM (get_weather_risk)
# =============================================================================
# Lấy mức độ nguy hiểm của thời tiết hiện tại
# Dùng để tính risk cho quest, farming...

func get_weather_risk() -> float:
	return WEATHER_RISK.get(current_weather, 0.0)


# =============================================================================
# HÀM LẤY THỜI TIẾT HÔM NAY (get_today_weather)
# =============================================================================

func get_today_weather() -> String:
	return current_weather


# =============================================================================
# HÀM LẤY DỰ BÁO NGÀY MAI (get_tomorrow_forecast)
# =============================================================================

func get_tomorrow_forecast() -> Dictionary:
	return forecast[1] if forecast.size() > 1 else {}


# =============================================================================
# HÀM LẤY DỰ BÁO NGÀY MỐT (get_day_after_forecast)
# =============================================================================

func get_day_after_forecast() -> Dictionary:
	return forecast[2] if forecast.size() > 2 else {}


# =============================================================================
# HÀM KÍCH HOẠT ANOMALY WEATHER (trigger_anomaly_weather)
# =============================================================================
# Bắt đầu thời tiết bất thường (horror element)
# Gây bão kéo dài 3 ngày

func trigger_anomaly_weather() -> void:
	anomaly_weather_active = true
	anomaly_weather_count = 0
	anomaly_weather_triggered.emit("anomaly")
	print("[WeatherSystem] ANOMALY WEATHER triggered.")


# =============================================================================
# HÀM CHUYỂN MÙA (advance_season)
# =============================================================================
# Chuyển sang mùa tiếp theo

func advance_season() -> void:
	var seasons: Array[String] = ["spring", "summer", "autumn", "winter"]
	var idx: int = seasons.find(current_season)
	idx = (idx + 1) % seasons.size()  # Mùa tiếp theo (xoay vòng)
	current_season = seasons[idx]
	season_day_counter = 1
	season_changed.emit(current_season)
	print("[WeatherSystem] Season changed to: %s" % current_season)


# =============================================================================
# HÀM TĂNG NGÀY (_advance_day)
# =============================================================================
# Được gọi mỗi ngày mới

func _advance_day() -> void:
	season_day_counter += 1
	var season_len: int = season_lengths.get(current_season, 30)
	
	# Nếu hết mùa -> chuyển mùa
	if season_day_counter > season_len:
		advance_season()
	
	# Cập nhật dự báo
	_generate_forecast()


# =============================================================================
# HÀM SIMULATE NGÀY (simulate_day)
# =============================================================================
# Mô phỏng thời tiết cho một ngày (dùng cho WorldSimulator)
#
# Trả về: Dictionary chứa thông tin thời tiết ngày đó

func simulate_day(day_number: int) -> Dictionary:
	var old_weather: String = current_weather
	var old_season: String = current_season
	
	_roll_daily_weather()
	weather_timer = 0.0
	_advance_day()
	
	return {
		"day": day_number,
		"weather": current_weather,
		"intensity": weather_intensity,
		"season": current_season,
	}


# =============================================================================
# HÀM ÉP THỜI TIẾT (force_weather)
# =============================================================================
# Đặt thời tiết cụ thể (cho debug hoặc sự kiện)
#
# Tham số:
#   weather_name: String - tên thời tiết

func force_weather(weather_name: String) -> void:
	current_weather = weather_name
	var intensity: float = WEATHER_RISK.get(weather_name, 0.3)
	weather_intensity = intensity
	GameState.weather_type = current_weather
	weather_changed.emit(current_weather, weather_intensity)
