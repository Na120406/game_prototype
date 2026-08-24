extends Node
# =============================================================================
# CAMERA MANAGER (Quản lý Camera)
# =============================================================================
# Chức năng: Điều khiển camera và các hiệu ứng camera
#
# Các tính năng:
#   - Screen shake (rung camera khi va chạm, nổ)
#   - Zoom in/out
#   - Giới hạn vùng camera (limit)
#
# CÁCH SỬ DỤNG:
#   CameraManager.request_shake(10.0, 0.5) - rung camera cường độ 10, 0.5 giây
#   CameraManager.set_zoom_level(2.0) - zoom 2x
#   CameraManager.set_camera_limits(0, 0, 1000, 1000) - giới hạn vùng camera
# =============================================================================

# =============================================================================
# TÍN HIỆU (SIGNALS)
# =============================================================================

# Phát ra khi có yêu cầu rung camera
# Tham số: intensity (cường độ), duration (thời gian)
signal screen_shake_requested(intensity: float, duration: float)


# =============================================================================
# CÁC BIẾN NỘI BỘ
# =============================================================================

# Cường độ rung (pixel)
var _shake_intensity: float = 0.0

# Thời gian rung (giây)
var _shake_duration: float = 0.0

# Timer đếm ngược thời gian rung
var _shake_timer: float = 0.0

# Camera hiện tại
var _camera: Camera2D


# =============================================================================
# HÀM KHỞI TẠO (_ready)
# =============================================================================

func _ready() -> void:
	# Lắng nghe khi có camera mới được thêm vào scene
	get_tree().node_added.connect(_on_node_added)
	print("[CameraManager] Ready.")


# =============================================================================
# HÀM XỬ LÝ NODE ĐƯỢC THÊM (_on_node_added)
# =============================================================================

func _on_node_added(node: Node) -> void:
	# CHỈ nhận camera từ player's current_scene — KHÔNG nhận camera từ
	# NPC preload scene (embedded camera). Nếu không check, khi NPC preload
	# scene được add vào tree → embedded camera ghi đè _camera → camera
	# bị fixed ở corner của map NPC preload.
	#
	# Check: camera phải nằm trong current_scene của tree (scene player đang ở).
	# Nếu camera từ scene khác (NPC preload) → bỏ qua.
	if node is Camera2D:
		var tree := get_tree()
		if tree == null:
			return
		var current := tree.current_scene
		if current == null:
			return
		# Kiểm tra camera có nằm trong current_scene không bằng cách
		# duyệt parent chain từ node lên và so sánh với current_scene.
		var parent: Node = node.get_parent()
		while parent != null:
			if parent == current:
				_camera = node
				print("[CameraManager] Registered camera from current_scene: %s" % node.name)
				return
			parent = parent.get_parent()


# =============================================================================
# HÀM YÊU CẦU RUNG CAMERA (request_shake)
# =============================================================================
# Gây hiệu ứng rung camera (screen shake)
# Dùng khi: va chạm, nổ, sự kiện đặc biệt
#
# Tham số:
#   intensity: float - cường độ rung (pixel)
#     5.0 = nhẹ (bước chân)
#     10.0 = vừa (va chạm)
#     20.0 = mạnh (nổ)
#   duration: float - thời gian rung (giây)
#     0.2 = ngắn
#     0.5 = vừa
#     1.0 = dài

func request_shake(intensity: float = 8.0, duration: float = 0.3) -> void:
	# Tìm camera nếu chưa có
	if _camera == null:
		_camera = get_viewport().get_camera_2d()
	if _camera == null:
		return

	# Lưu thông số rung
	_shake_intensity = intensity
	_shake_duration = duration
	_shake_timer = duration
	
	# Phát tín hiệu để các hệ thống khác phản ứng
	screen_shake_requested.emit(intensity, duration)


# =============================================================================
# HÀM CẬP NHẬT MỖI FRAME (_process)
# =============================================================================
# Xử lý rung camera mỗi frame
# Di chuyển camera ngẫu nhiên trong thời gian rung

func _process(delta: float) -> void:
	# Nếu đang trong thời gian rung
	if _shake_timer > 0.0 and _camera != null:
		# Giảm timer
		_shake_timer -= delta
		
		# Tính độ rung còn lại (giảm dần theo thời gian)
		var progress := _shake_timer / _shake_duration
		var current_intensity := _shake_intensity * progress
		
		# Tạo offset ngẫu nhiên
		var offset := Vector2(
			randf_range(-current_intensity, current_intensity),  # X ngẫu nhiên
			randf_range(-current_intensity, current_intensity)   # Y ngẫu nhiên
		)
		
		# Di chuyển camera đến vị trí offset
		_camera.offset = offset
	else:
		# Hết rung -> đặt camera về vị trí bình thường
		if _camera != null:
			_camera.offset = Vector2.ZERO


# =============================================================================
# HÀM ĐẶT ZOOM (set_zoom_level)
# =============================================================================
# Thay đổi độ zoom của camera
#
# Tham số:
#   level: float - hệ số zoom
#     1.0 = bình thường
#     2.0 = zoom 2x (phóng to gấp đôi)
#     0.5 = thu nhỏ (nhìn rộng hơn)

func set_zoom_level(level: float) -> void:
	if _camera != null:
		# Zoom đồng đều X và Y
		_camera.zoom = Vector2(level, level)


# =============================================================================
# HÀM LẤY ZOOM HIỆN TẠI (get_zoom_level)
# =============================================================================

func get_zoom_level() -> float:
	if _camera != null:
		return _camera.zoom.x
	return 1.0


# =============================================================================
# HÀM ĐẶT GIỚI HẠN CAMERA (set_camera_limits)
# =============================================================================
# Giới hạn vùng camera có thể di chuyển
# Dùng để ngăn camera đi ra ngoài map
#
# Tham số:
#   left: int - giới hạn trái (pixel)
#   top: int - giới hạn trên
#   right: int - giới hạn phải
#   bottom: int - giới hạn dưới

func set_camera_limits(left: int, top: int, right: int, bottom: int) -> void:
	if _camera != null:
		_camera.limit_left = left
		_camera.limit_top = top
		_camera.limit_right = right
		_camera.limit_bottom = bottom
