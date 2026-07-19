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
	# KIỂM TRA TRẠNG THÁI NGÀY/ĐÊM
	# =================================================================
	# Nếu thời gian >= 22:00 (10 giờ tối) -> ĐÊM
	if GameState.current_time >= 22.0:
		GameState.is_day = false
	# Nếu thời gian >= 6:00 và < 22:00 -> NGÀY
	elif GameState.current_time >= 6.0:
		GameState.is_day = true

	# =================================================================
	# XỬ LÝ CHUYỂN NGÀY MỚI
	# =================================================================
	# Nếu thời gian >= 24:00 (nửa đêm)
	if GameState.current_time >= 24.0:
		# Reset về 0:00
		GameState.current_time = 0.0
		# Tăng ngày
		GameState.current_day += 1
		# Khôi phục năng lượng đầy (mỗi ngày mới)
		GameState.energy = GameState.max_energy
		# Đặt ban ngày
		GameState.is_day = true
		# Phát tín hiệu ngày mới
		day_changed.emit(GameState.current_day)

	# =================================================================
	# KIỂM TRA TRÔI QUA 1 GIỜ
	# =================================================================
	# Lấy phần nguyên của thời gian (để lấy giờ)
	var prev_hour: int = int(previous_time)
	var curr_hour: int = int(GameState.current_time)
	
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
#   new_time: float - thời gian mới (0.0 - 24.0)

func set_time(new_time: float) -> void:
	# Clamp để đảm bảo thời gian hợp lệ
	GameState.current_time = clampf(new_time, 0.0, 24.0)
	
	# Tính toán is_day
	# Ngày: 6:00 <= time < 22:00
	GameState.is_day = GameState.current_time >= 6.0 and GameState.current_time < 22.0
	
	# Thông báo thay đổi
	time_changed.emit(GameState.current_time, GameState.is_day)


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
	return GameState.current_time >= 5.0 and GameState.current_time < 7.0


# =============================================================================
# HÀM KIỂM TRA HOÀNG HÔN (is_dusk)
# =============================================================================
# Kiểm tra xem có phải lúc hoàng hôn (xế chiều) không
#
# Trả về: true nếu là 19:00 - 22:00

func is_dusk() -> bool:
	return GameState.current_time >= 19.0 and GameState.current_time < 22.0


# =============================================================================
# HÀM LẤY CHUỖI THỜI GIAN (get_time_of_day_string)
# =============================================================================
# Lấy thời gian dạng chuỗi để hiển thị (ví dụ: "14:30")
#
# Trả về: String - thời gian dạng "HH:MM"

func get_time_of_day_string() -> String:
	# Lấy phần nguyên (giờ)
	var hour: int = int(GameState.current_time)
	# Lấy phần thập phân, chuyển thành phút (nhân 60)
	var minute: int = int((GameState.current_time - hour) * 60.0)
	# Format: 02d = luôn có 2 chữ số (01, 02, ... 23)
	return "%02d:%02d" % [hour, minute]
