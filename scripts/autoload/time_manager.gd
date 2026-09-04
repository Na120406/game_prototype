extends Node
# =============================================================================
# TIME MANAGER (Quản lý Thời gian)
# =============================================================================
# Chức năng: Điều khiển thời gian trong game - ngày/đêm, giờ
#
# Đặc điểm:
#   - Tự động tăng thời gian mỗi frame dựa trên delta
#   - Phát tín hiệu khi có thay đổi thời gian/ngày
#   - Hỗ trợ tạm dừng và thay đổi tốc độ thời gian
#
# CÁCH SỬ DỤNG:
#   - TimeManager.is_night() - kiểm tra có phải ban đêm
#   - TimeManager.pause() - tạm dừng thời gian
#   - TimeManager.set_time_scale(2.0) - tăng tốc thời gian gấp đôi
#
# Mốc thời gian mặc định "bắt đầu state ngày mới" = 6:00:
#   - Time chạy 0-24 liên tục (KHÔNG clamp, KHÔNG phạt khi qua 24).
#   - Tới 1:00 (mod 24) → trigger AFK penalty (bất tỉnh + gold penalty).
#     Sau AFK xong → set time = 6.0 → advance_day(6.0) tự động chạy.
#   - Tới 6:00 (mod 24) → advance_day(6.0): tăng current_day + emit
#     farm_day_changed + day_changed.
#   - Tới 24.0 → wrap về mod 24 (= 0.0). KHÔNG phạt, KHÔNG tăng day.
# =============================================================================

# =============================================================================
# TÍN HIỆU (SIGNALS) - Thông báo khi thời gian thay đổi
# =============================================================================

# Phát ra khi thời gian thay đổi - UI lắng nghe để cập nhật đồng hồ
# Tham số: current_time (float), is_day (bool)
signal time_changed(current_time: float, is_day: bool)

# Phát ra khi chuyển sang ngày mới
# Tham số: new_day (int) - ngày mới
signal day_changed(new_day: int)

# Phát ra mỗi khi trôi qua 1 giờ
# Tham số: hour (int) - giờ hiện tại (0-23)
signal hour_elapsed(hour: int)


# =============================================================================
# CÁC BIẾN NỘI BỘ (INTERNAL VARIABLES)
# =============================================================================

# Tốc độ thời gian - 1.0 = bình thường, 2.0 = nhanh gấp đôi, 0.0 = dừng
var time_scale: float = 1.0

# Trạng thái tạm dừng - true thì thời gian không trôi
var paused: bool = false

# Cờ chỉ trigger AFK penalty 1 lần mỗi đêm. Reset khi advance_day emit
# day_changed (khi qua 6:00 hoặc player ngủ tại giường).
var _afk_triggered_this_night: bool = false

# Cờ chỉ tick farm day 1 lần mỗi đêm. Reset cùng _afk_triggered_this_night.
var _farm_day_ticked_this_night: bool = false

func _ready() -> void:
	# Khi GameState tăng day (qua advance_day từ ngủ / farm tick / AFK reset
	# 6.0), reset các cờ night-boundary để đêm tiếp theo hoạt động đúng.
	if not GameState.day_changed.is_connected(_on_day_changed_reset_flags):
		GameState.day_changed.connect(_on_day_changed_reset_flags)
	print("[TimeManager] Ready.")

func _on_day_changed_reset_flags(_new_day: int) -> void:
	# Sau khi ngày chính thức đổi → reset cờ để sẵn sàng cho đêm tiếp theo.
	_afk_triggered_this_night = false
	_farm_day_ticked_this_night = false


# =============================================================================
# HÀM CẬP NHẬT MỖI FRAME (_process)
# =============================================================================
# Được gọi mỗi frame (thường 60 lần/giây)
# Tự động tăng thời gian game dựa trên delta và time_scale
#
# QUAN TRỌNG: Không chỉnh sửa trực tiếp hàm này
# Nếu cần thay đổi cách thời gian hoạt động, gọi các hàm bên dưới

func _process(delta: float) -> void:
	# Nếu đang tạm dừng, không làm gì
	if paused:
		return

	# Lưu thời gian trước khi thay đổi (để so sánh)
	var previous_time: float = GameState.current_time

	# Tăng thời gian: delta * time_scale * 0.1
	# 0.1 là hệ số để 1 giờ game = 10 giây thực
	# Ví dụ: delta=0.016 (60fps), time_scale=1.0 -> thêm 0.0016 giờ
	GameState.current_time += delta * time_scale * 0.1

	# =================================================================
	# KIỂM TRA TRẠNG THÁI NGÀY/ĐÊM (dùng mod 24 để xử lý khi time vượt 24)
	# =================================================================
	var t24: float = fposmod(GameState.current_time, 24.0)
	if t24 >= 22.0 or t24 < 6.0:
		GameState.is_day = false
	else:
		GameState.is_day = true

	# =================================================================
	# XỬ LÝ CÁC MỐC THỜI GIAN (midnight wrap / AFK / farm day)
	# =================================================================
	if not TimeManager.paused:
		var prev_t24: float = fposmod(previous_time, 24.0)
		var curr_t24: float = t24

		# --- Bước 1: midnight wrap ---
		# Khi time >= 24.0 → wrap về mod 24. KHÔNG tăng day, KHÔNG phạt.
		# Day chỉ update lúc 6:00 (qua advance_day(6.0)).
		if GameState.current_time >= 24.0:
			GameState.current_time = curr_t24
			print("[TimeManager] Hour wrapped to %.1f (midnight)." % curr_t24)
			curr_t24 = fposmod(GameState.current_time, 24.0)

		# --- Bước 2: AFK trigger lúc 1:00 sáng ---
		# Điều kiện: previous_time (mod 24) < 1.0 <= current_time (mod 24).
		# Sau khi wrap về 0.0 → frame sau time tăng dần tới 1.0 → trigger.
		if prev_t24 < 1.0 and curr_t24 >= 1.0 and not _afk_triggered_this_night:
			var em := get_tree().root.get_node_or_null("EnergyManager")
			if em != null and em.has_method("trigger_afk_knock_out"):
				print("[TimeManager] Hour %.1f — 1:00 AM, triggering AFK penalty." % GameState.current_time)
				em.call("trigger_afk_knock_out")
				_afk_triggered_this_night = true
			else:
				# Fallback: set time = 6.0 + advance_day (start of new day).
				GameState.advance_day(6.0)
				_afk_triggered_this_night = true
				_farm_day_ticked_this_night = true
				curr_t24 = fposmod(GameState.current_time, 24.0)

		# --- Bước 3: farm day tick lúc 6:00 sáng ---
		# Điều kiện: previous_time (mod 24) < 6.0 <= current_time (mod 24).
		# Guard: KHÔNG tick farm nếu AFK vừa trigger trong frame này (sẽ được
		# xử lý bởi AFK reset path → tự gọi advance_day(6.0)).
		if not _afk_triggered_this_night:
			if prev_t24 < 6.0 and curr_t24 >= 6.0 and not _farm_day_ticked_this_night:
				print("[TimeManager] Hour %.1f — 6:00 AM, farm day tick." % GameState.current_time)
				GameState.advance_day(6.0)
				_farm_day_ticked_this_night = true

	# =================================================================
	# KIỂM TRA TRÔI QUA 1 GIỜ
	# =================================================================
	var prev_hour: int = int(fposmod(previous_time, 24.0))
	var curr_hour: int = int(fposmod(GameState.current_time, 24.0))

	# Nếu giờ thay đổi -> phát tín hiệu
	if curr_hour != prev_hour:
		hour_elapsed.emit(curr_hour)

	# Nếu thời gian thay đổi đáng kể -> phát tín hiệu
	if absf(GameState.current_time - previous_time) > 0.001:
		time_changed.emit(GameState.current_time, GameState.is_day)


# =============================================================================
# HÀM ĐẶT THỜI GIAN (set_time)
# =============================================================================
# Đặt thời gian game thủ công
# Dùng khi cần teleport thời gian (ví dụ: debug, chuyển scene)
#
# Tham số:
#   new_time: float - thời gian mới

func set_time(new_time: float) -> void:
	# KHÔNG clamp về [0, 24] — để các mốc trên 24 có thể đạt tới cho debug.
	# Time sẽ được wrap tự nhiên trong _process khi vượt 24.
	GameState.current_time = new_time

	# Tính toán is_day — dùng fposmod để xử lý khi time >= 24
	var t24: float = fposmod(new_time, 24.0)
	GameState.is_day = t24 >= 6.0 and t24 < 22.0

	# Thông báo thay đổi
	time_changed.emit(GameState.current_time, GameState.is_day)


## Tăng clock theo một bước gameplay (travel, cutscene) nhưng vẫn xử lý các
## boundary mà `_process()` sẽ gặp nếu thời gian trôi liên tục. Boundary đầu
## tiên có side effect kết thúc chu kỳ hiện tại (AFK hoặc dawn) giữ nguyên
## semantics realtime: AFK bắt đầu knock-out; dawn bắt đầu ngày mới ở 06:00.
func advance_clock(hours: float) -> void:
	var duration: float = maxf(0.0, hours)
	if duration <= 0.0:
		return
	var previous_time: float = GameState.current_time
	var next_time: float = previous_time + duration
	var afk_at: float = _next_daily_boundary(previous_time, 1.0)
	var dawn_at: float = _next_daily_boundary(previous_time, 6.0)

	if afk_at <= next_time and afk_at < dawn_at and not _afk_triggered_this_night:
		set_time(next_time)
		var energy_manager: Node = get_tree().root.get_node_or_null("EnergyManager")
		if energy_manager != null and energy_manager.has_method("trigger_afk_knock_out"):
			energy_manager.call("trigger_afk_knock_out")
			_afk_triggered_this_night = true
		else:
			GameState.advance_day(6.0)
			_afk_triggered_this_night = true
			_farm_day_ticked_this_night = true
		return

	if dawn_at <= next_time and not _farm_day_ticked_this_night:
		# Dawn bắt đầu ngày mới nhưng travel vẫn phải giữ phần thời gian đã đi
		# sau 06:00 (05:00 + 1,5h => 06:30, không bị cắt về 06:00).
		GameState.advance_day(fposmod(next_time, 24.0))
		_farm_day_ticked_this_night = true
		time_changed.emit(GameState.current_time, GameState.is_day)
		return

	set_time(next_time)


func _next_daily_boundary(from_time: float, boundary_hour: float) -> float:
	var cycle_start: float = floorf(from_time / 24.0) * 24.0
	var occurrence: float = cycle_start + boundary_hour
	if occurrence <= from_time:
		occurrence += 24.0
	return occurrence


# =============================================================================
# HÀM ĐẶT NGÀY (set_day)
# =============================================================================
# Đặt ngày game thủ công
# Dùng cho debug hoặc chuyển ngày nhanh
#
# Tham số:
#   new_day: int - ngày mới

func set_day(new_day: int) -> void:
	GameState.current_day = new_day
	day_changed.emit(new_day)


# =============================================================================
# HÀM ĐẶT TỐC ĐỘ THỜI GIAN (set_time_scale)
# =============================================================================
# Thay đổi tốc độ thời gian trôi
# Dùng để tăng tốc chờ đợi (xem sunset nhanh) hoặc làm chậm
#
# Tham số:
#   scale: float - hệ số tốc độ
#     1.0 = bình thường (mặc định)
#     2.0 = nhanh gấp đôi
#     0.5 = chậm một nửa
#     0.0 = dừng hẳn (tương đương pause())

func set_time_scale(scale: float) -> void:
	# maxf để không cho giá trị âm
	time_scale = maxf(0.0, scale)


# =============================================================================
# HÀM TẠM DỪNG (pause)
# =============================================================================
# Tạm dừng thời gian game
# Thời gian sẽ không trôi cho đến khi gọi resume()

func pause() -> void:
	paused = true


# =============================================================================
# HÀM TIẾP TỤC (resume)
# =============================================================================
# Tiếp tục thời gian game sau khi pause

func resume() -> void:
	paused = false


# =============================================================================
# HÀM KIỂM TRA ĐÊM (is_night)
# =============================================================================
# Kiểm tra xem có phải thời điểm ban đêm không
#
# Trả về: true nếu là đêm (22:00 - 6:00)

func is_night() -> bool:
	return not GameState.is_day


# =============================================================================
# HÀM KIỂM TRA HỪNG ĐÔNG (is_dawn)
# =============================================================================
# Kiểm tra xem có phải lúc hừng đông (rạng sáng) không
#
# Trả về: true nếu là 5:00 - 7:00

func is_dawn() -> bool:
	var t24: float = fposmod(GameState.current_time, 24.0)
	return t24 >= 5.0 and t24 < 7.0


# =============================================================================
# HÀM KIỂM TRA HOÀNG HÔN (is_dusk)
# =============================================================================
# Kiểm tra xem có phải lúc hoàng hôn (xế chiều) không
#
# Trả về: true nếu là 19:00 - 22:00

func is_dusk() -> bool:
	var t24: float = fposmod(GameState.current_time, 24.0)
	return t24 >= 19.0 and t24 < 22.0


# =============================================================================
# HÀM LẤY CHUỖI THỜI GIAN (get_time_of_day_string)
# =============================================================================
# Lấy thời gian dạng chuỗi để hiển thị (ví dụ: "14:30")
#
# Trả về: String - thời gian dạng "HH:MM"

func get_time_of_day_string() -> String:
	var t24: float = fposmod(GameState.current_time, 24.0)
	# Lấy phần nguyên (giờ)
	var hour: int = int(t24)
	# Lấy phần thập phân, chuyển thành phút (nhân 60)
	var minute: int = int((t24 - hour) * 60.0)
	# Format: 02d = luôn có 2 chữ số (01, 02, ... 23)
	return "%02d:%02d" % [hour, minute]
