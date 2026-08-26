extends Node
# =============================================================================
# EVENT MANAGER (Quản lý Sự kiện)
# =============================================================================
# Chức năng: Quản lý các sự kiện trong thế giới game
#
# Các loại sự kiện:
#   - World Events: Sự kiện cốt truyện (quest, cutscene)
#   - Anomalies: Hiện tượng bí ẩn (horror elements)
#   - Missed Events: Sự kiện bỏ lỡ (player không kịp làm)
#
# CÁCH SỬ DỤNG:
#   - EventManager.trigger_event("quest_1_start") - kích hoạt sự kiện
#   - EventManager.is_event_triggered("x") - kiểm tra đã xảy ra chưa
#   - EventManager.spawn_anomaly("flicker", position) - tạo hiện tượng lạ
# =============================================================================

# =============================================================================
# TÍN HIỆU (SIGNALS) - Thông báo khi có sự kiện
# =============================================================================

# Phát ra khi một sự kiện được kích hoạt
# Tham số: event_id (String) - tên sự kiện
signal event_triggered(event_id: String)

# Phát ra khi trạng thái khu vực thay đổi
# Tham số: area_id (String) - khu vực bị thay đổi
signal world_state_changed(area_id: String)

# Phát ra khi có hiện tượng bí ẩn xuất hiện
# Tham số: anomaly_type (String), position (Vector2)
signal anomaly_occurred(anomaly_type: String, position: Vector2)


# =============================================================================
# CÁC BIẾN THEO DÕI SỰ KIỆN
# =============================================================================

# Các sự kiện đang diễn ra (active)
# Ví dụ: ["quest_1_active", "festival_running"]
var active_events: Array[String] = []

# Các sự kiện đã xảy ra (hoàn thành)
# Dùng để kiểm tra player đã làm gì chưa
var triggered_events: Array[String] = []

# Các sự kiện đã bỏ lỡ
# Ví dụ: player không kịp đến dự lễ hội
var missed_events: Array[String] = []

# Thời gian cooldown của sự kiện
# Key: tên sự kiện, Value: thời gian (milliseconds) hết cooldown
var event_cooldowns: Dictionary = {}

# Số lần xuất hiện anomaly (hiện tượng lạ)
var anomaly_occurrences: int = 0

# Khoảng cách tối thiểu giữa 2 anomaly (giây)
const MIN_ANOMALY_INTERVAL: float = 300.0


# =============================================================================
# HÀM KHỞI TẠO (_ready)
# =============================================================================

func _ready() -> void:
	print("[EventManager] Ready — world event system active.")


# =============================================================================
# HÀM KÍCH HOẠT SỰ KIỆN (trigger_event)
# =============================================================================
# Kích hoạt một sự kiện để nó xảy ra
#
# Quy tắc:
#   - Sự kiện chỉ kích hoạt được 1 lần
#   - Nếu đang cooldown, không kích hoạt được
#
# Tham số:
#   event_id: String - tên sự kiện cần kích hoạt
#
# Trả về: true nếu kích hoạt thành công, false nếu thất bại

func trigger_event(event_id: String) -> bool:
	# Kiểm tra: sự kiện đã xảy ra chưa?
	if event_id in triggered_events:
		return false
	
	# Kiểm tra: sự kiện đang trong thời gian cooldown?
	if event_id in event_cooldowns:
		var cooldown_ms: int = event_cooldowns[event_id]
		# Time.get_ticks_msec() = thời gian hiện tại (ms)
		# Nếu chưa hết cooldown (thời gian hiện tại < thời gian hết cooldown)
		if Time.get_ticks_msec() < cooldown_ms:
			return false

	# Thêm vào danh sách đã xảy ra
	triggered_events.append(event_id)
	# Thêm vào danh sách đang diễn ra
	active_events.append(event_id)
	# Phát tín hiệu để các hệ thống khác phản ứng
	event_triggered.emit(event_id)
	active_events.erase(event_id)
	
	print("[EventManager] Event triggered: %s" % event_id)
	return true


# =============================================================================
# HÀM ĐĂNG KÝ SỰ KIỆN BỎ LỠ (register_missed_event)
# =============================================================================
# Đánh dấu một sự kiện đã bị bỏ lỡ
# Dùng khi player không đáp ứng được yêu cầu kịp thời
#
# Tham số:
#   event_id: String - tên sự kiện bị bỏ lỡ
#   description: String - mô tả tại sao bị bỏ lỡ

func register_missed_event(event_id: String, description: String) -> void:
	# Không đăng ký trùng lặp
	if event_id in missed_events:
		return
	
	# Thêm vào danh sách bỏ lỡ
	missed_events.append(event_id)
	print("[EventManager] Missed event: %s — %s" % [event_id, description])


# =============================================================================
# HÀM KIỂM TRA SỰ KIỆN BỎ LỠ (check_missed_events)
# =============================================================================
# Lấy danh sách các sự kiện đã bỏ lỡ
#
# Trả về: Array - danh sách event_id đã bỏ lỡ

func check_missed_events() -> Array:
	# .duplicate() tạo bản sao để tránh sửa mảng gốc
	return missed_events.duplicate()


# =============================================================================
# HÀM KIỂM TRA SỰ KIỆN ĐÃ XẢY RA (is_event_triggered)
# =============================================================================
# Kiểm tra xem một sự kiện đã xảy ra chưa
#
# Tham số:
#   event_id: String - tên sự kiện cần kiểm tra
#
# Trả về: true nếu đã xảy ra, false nếu chưa

func is_event_triggered(event_id: String) -> bool:
	return event_id in triggered_events


# =============================================================================
# HÀM RESET SỰ KIỆN KHU VỰC (reset_area_events)
# =============================================================================
# Xóa tất cả sự kiện liên quan đến một khu vực
# Dùng khi player quay lại khu vực sau thời gian dài
#
# Tham số:
#   area_id: String - tên khu vực cần reset

func reset_area_events(area_id: String) -> void:
	# Prefix để nhận diện sự kiện thuộc khu vực
	# Ví dụ: area_id = "farm" -> prefix = "farm_"
	var prefix: String = area_id + "_"
	
	# Duyệt ngược (để có thể xóa phần tử)
	for i: int in range(triggered_events.size() - 1, -1, -1):
		var event_id: String = triggered_events[i]
		# Kiểm tra xem sự kiện có thuộc khu vực không
		if event_id.begins_with(prefix):
			# Xóa khỏi danh sách đã xảy ra
			triggered_events.remove_at(i)
			# Xóa khỏi danh sách đang diễn ra
			active_events.erase(event_id)


# =============================================================================
# HÀM TẠO HIỆN TƯỢNG BÍ ẨN (spawn_anomaly)
# =============================================================================
# Tạo một hiện tượng bí ẩn (horror element)
# Ví dụ: đèn nhấp nháy, âm thanh lạ, vật dịch chuyển
#
# Tham số:
#   anomaly_type: String - loại anomaly
#     - "flicker": đèn nhấp nháy
#     - "whisper": tiếng thì thầm
#     - "shadow": bóng ma
#     - "move": vật dịch chuyển
#   position: Vector2 - vị trí xuất hiện

func spawn_anomaly(anomaly_type: String, position: Vector2) -> void:
	if not can_trigger_anomaly():
		return
	# Tăng số lần anomaly
	anomaly_occurrences += 1
	
	# Đặt cooldown cho anomaly (ngăn spam)
	# MIN_ANOMALY_INTERVAL * 1000 để chuyển giây thành milliseconds
	event_cooldowns["anomaly_last"] = Time.get_ticks_msec() + int(MIN_ANOMALY_INTERVAL * 1000.0)
	
	# Phát tín hiệu để các hệ thống khác phản ứng
	# VD: AtmosphereManager bật hiệu ứng, AudioManager phát âm thanh
	anomaly_occurred.emit(anomaly_type, position)
	
	print("[EventManager] Anomaly at %s: %s" % [str(position), anomaly_type])


# =============================================================================
# HÀM KIỂM TRA CÓ THỂ TẠO ANOMALY (can_trigger_anomaly)
# =============================================================================
# Kiểm tra xem đã hết cooldown chưa
# Dùng trước khi gọi spawn_anomaly
#
# Trả về: true nếu có thể tạo anomaly, false nếu đang cooldown

func can_trigger_anomaly() -> bool:
	# Nếu chưa từng có anomaly, cho phép
	if not event_cooldowns.has("anomaly_last"):
		return true
	
	# Kiểm tra đã hết cooldown chưa
	return Time.get_ticks_msec() >= event_cooldowns["anomaly_last"]
