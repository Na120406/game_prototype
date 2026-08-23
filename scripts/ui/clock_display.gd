extends PanelContainer
# =============================================================================
# CLOCK DISPLAY
# =============================================================================#
# Hiển thị thời gian trong ngày theo format "HH:MM", snap về bội số 10 phút
# gần nhất (00:00, 00:10, 00:20, ..., 23:50). Khi current_time chạm 24:00 thì
# GameState.advance_day() sẽ reset current_time về 6:00 → đồng hồ hiện lại
# "06:00" cho ngày mới.
#
# Lắng nghe TimeManager.time_changed để update mượt theo từng frame, nhưng
# chỉ thay text khi giá trị hiển thị thực sự đổi (snap step 10 phút) để tránh
# spam string allocation.
# =============================================================================

const STEP_MINUTES: int = 10

@onready var _label: Label = $ClockLabel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Khởi tạo text ngay (kể cả khi TimeManager chưa emit time_changed).
	_update_text(GameState.current_time)
	if not TimeManager.time_changed.is_connected(_on_time_changed):
		TimeManager.time_changed.connect(_on_time_changed)
	if not TimeManager.day_changed.is_connected(_on_day_changed):
		TimeManager.day_changed.connect(_on_day_changed)

func _on_time_changed(current_time: float, _is_day: bool) -> void:
	_update_text(current_time)

func _on_day_changed(_new_day: int) -> void:
	# advance_day() đã reset current_time về 6.0 trước khi phát day_changed,
	# nhưng để chắc chắn đồng bộ ta gọi lại từ GameState.
	_update_text(GameState.current_time)

# Snap current_time (giờ, float) về định dạng "HH:MM" với bước 10 phút.
func _update_text(current_time: float) -> void:
	# current_time có thể vượt 24 trong khoảng giữa 24:00 và 6:00 ngày mới
	# (TimeManager KHÔNG clamp). Lấy modulo 24 để hiển thị đúng.
	var t24: float = fmod(current_time, 24.0)
	if t24 < 0.0:
		t24 += 24.0
	var total_minutes: int = int(round(t24 * 60.0))
	# Snap xuống bội số STEP_MINUTES gần nhất.
	var snapped_minutes: int = int(floor(float(total_minutes) / float(STEP_MINUTES))) * STEP_MINUTES
	var hour: int = (snapped_minutes / 60) % 24
	var minute: int = snapped_minutes % 60
	var new_text: String = "%02d:%02d" % [hour, minute]
	if _label.text != new_text:
		_label.text = new_text