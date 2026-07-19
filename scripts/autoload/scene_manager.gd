extends Node
# =============================================================================
# SCENE MANAGER (Quản lý Scene)
# =============================================================================
# Chức năng: Chuyển đổi giữa các scene trong game
#
# Tính năng:
#   - Chuyển scene với hiệu ứng fade đen
#   - Tự động đặt player tại vị trí portal
#   - Hỗ trợ chuyển scene không có fade
#
# CÁCH SỬ DỤNG:
#   SceneManager.change_scene("res://scenes/farm.tscn") - chuyển scene
#   SceneManager.change_scene("res://scenes/town.tscn", "shop_door") - chuyển đến vị trí portal
# =============================================================================

# =============================================================================
# TÍN HIỆU (SIGNALS)
# =============================================================================

# Phát ra khi scene thay đổi
# Tham số: scene_path (String) - đường dẫn scene mới
signal scene_changed(scene_path: String)


# =============================================================================
# CÁC HẰNG SỐ
# =============================================================================

# Thời gian fade (giây)
const TRANSITION_DURATION: float = 0.5


# =============================================================================
# CÁC BIẾN NỘI BỘ
# =============================================================================

# Scene hiện tại
var current_scene_path: String = ""

# Layer overlay để fade
var _transition_overlay: ColorRect

# CanvasLayer chứa overlay
var _transition_canvas: CanvasLayer

# Portal ID để đặt player sau khi chuyển scene
var _pending_portal_id: String = ""

# Tween cho animation fade
var _transition_tween: Tween


# =============================================================================
# HÀM KHỞI TẠO (_ready)
# =============================================================================

func _ready() -> void:
	print("[SceneManager] Ready — portal transition system active.")
	# Persist in-memory farm data whenever the scene changes
	scene_changed.connect(_on_scene_changed)

var _farm_snapshot: Dictionary = {}


# =============================================================================
# HÀM CHUYỂN SCENE (change_scene)
# =============================================================================
# Chuyển sang scene mới với hiệu ứng fade
#
# Tham số:
#   scene_path: String - đường dẫn scene cần chuyển
#     Ví dụ: "res://scenes/farm_map.tscn"
#   portal_id: String - ID của portal để đặt player (tùy chọn)
#     Nếu không có, player sẽ spawn ở vị trí mặc định của scene
#   use_transition: bool - có dùng fade không (mặc định = true)

func change_scene(scene_path: String, portal_id: String = "", use_transition: bool = true) -> void:
	# Kiểm tra scene tồn tại không
	if not ResourceLoader.exists(scene_path):
		push_error("[SceneManager] Scene not found: %s" % scene_path)
		return

	# Lưu thông tin scene
	current_scene_path = scene_path
	_pending_portal_id = portal_id

	# Chuyển scene
	if use_transition:
		# Có fade: bắt đầu animation fade
		_start_fade_to_black(scene_path)
	else:
		# Không fade: load trực tiếp
		_load_scene(scene_path)


# =============================================================================
# HÀM BẮT ĐẦU FADE ĐEN (_start_fade_to_black)
# =============================================================================
# Tạo overlay đen và fade từ trong suốt sang đen
# Sau khi đen hoàn toàn -> load scene mới

func _start_fade_to_black(scene_path: String) -> void:
	# Tránh gọi nhiều lần cùng lúc
	if _transition_tween != null and _transition_tween.is_valid():
		return

	# =================================================================
	# TẠO OVERLAY FADE
	# =================================================================
	# Tạo CanvasLayer (luôn hiển thị trên cùng)
	_transition_canvas = CanvasLayer.new()
	_transition_canvas.layer = 9999  # Layer cao nhất

	# Tạo ColorRect (hình chữ nhật màu) làm overlay
	_transition_overlay = ColorRect.new()
	_transition_overlay.color = Color.TRANSPARENT  # Bắt đầu trong suốt
	_transition_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)  # Phủ toàn màn hình

	# Thêm overlay vào canvas
	_transition_canvas.add_child(_transition_overlay)
	get_tree().root.add_child(_transition_canvas)

	# =================================================================
	# TẠO ANIMATION FADE
	# =================================================================
	_transition_tween = create_tween()
	# Tween màu từ trong suốt -> đen trong TRANSITION_DURATION giây
	_transition_tween.tween_property(_transition_overlay, "color", Color.BLACK, TRANSITION_DURATION)
	# Khi fade xong -> gọi hàm load scene
	_transition_tween.finished.connect(_on_fade_to_black_complete.bind(scene_path))


# =============================================================================
# HÀM FADE HOÀN TẤT (_on_fade_to_black_complete)
# =============================================================================
# Gọi khi fade đen hoàn tất

func _on_fade_to_black_complete(scene_path: String) -> void:
	# Load scene mới
	_load_scene(scene_path)

	# Chờ fade duration trước khi fade in
	var delay_timer := get_tree().create_timer(TRANSITION_DURATION)
	delay_timer.timeout.connect(_on_fade_in.bind(scene_path))


# =============================================================================
# HÀM FADE IN (_on_fade_in)
# =============================================================================
# Fade từ đen sang trong suốt (hiện scene mới)

func _on_fade_in(scene_path: String) -> void:
	if _transition_overlay == null:
		return

	# Đặt màu đen trước (để fade từ đen ra)
	_transition_overlay.color = Color.BLACK

	# Tạo animation fade
	_transition_tween = create_tween()
	_transition_tween.tween_property(_transition_overlay, "color", Color.TRANSPARENT, TRANSITION_DURATION)
	_transition_tween.finished.connect(_cleanup_transition)

	# Phát tín hiệu scene đã đổi (sau khi đã load scene mới)
	scene_changed.emit(scene_path)


# =============================================================================
# HÀM DỌN DẸP (_cleanup_transition)
# =============================================================================
# Xóa overlay sau khi fade hoàn tất

func _cleanup_transition() -> void:
	if _transition_canvas != null:
		_transition_canvas.queue_free()  # Xóa sau khi animation kết thúc
		_transition_canvas = null
	_transition_overlay = null


# =============================================================================
# HÀM LOAD SCENE (_load_scene)
# =============================================================================
# Load và chuyển sang scene mới

func _load_scene(scene_path: String) -> void:
	# Snapshot farm state from current scene BEFORE removing it
	_persist_farm_state()

	# Load scene từ file
	var packed := load(scene_path)
	if packed == null:
		push_error("[SceneManager] Failed to load: %s" % scene_path)
		return

	# Tạo instance từ scene
	var new_scene: Node = packed.instantiate()

	# Lấy root node
	var root := get_tree().root

	# =================================================================
	# XÓA SCENE CŨ
	# =================================================================
	var current: Node = get_tree().current_scene
	if current != null:
		root.remove_child(current)
		current.queue_free()  # Xóa sau khi remove

	# =================================================================
	# THÊM SCENE MỚI
	# =================================================================
	root.add_child(new_scene)
	get_tree().current_scene = new_scene

	# =================================================================
	# KHÔI PHỤC FARM DATA NẾU SCENE MỚI CÓ FARM
	# =================================================================
	_restore_farm_state_for_new_scene(new_scene)

	# =================================================================
	# ĐẶT PLAYER TẠI PORTAL
	# =================================================================
	if _pending_portal_id != "":
		# Tìm portal trong scene mới
		var portal := _find_portal_in_scene(new_scene, _pending_portal_id)
		if portal != null:
			# Tìm player
			var player: Node = get_tree().get_first_node_in_group("player")
			if player != null and player.has_method("force_position"):
				# Di chuyển player đến vị trí portal
				player.force_position(portal.global_position)
				print("[SceneManager] Spawned at portal '%s': %s" % [_pending_portal_id, str(portal.global_position)])
		else:
			push_warning("[SceneManager] Portal '%s' not found in %s" % [_pending_portal_id, scene_path])
	else:
		print("[SceneManager] No portal_id — using scene default spawn")

	# Reset portal ID
	_pending_portal_id = ""


# =============================================================================
# HÀM TÌM PORTAL (_find_portal_in_scene)
# =============================================================================
# Tìm portal theo ID trong scene đã load

func _find_portal_in_scene(scene: Node, portal_id: String) -> Node:
	# Duyệt tất cả Area2D trong scene
	for area in scene.find_children("*", "Area2D", false, false):
		# Thử gọi method get_portal_id()
		if area.has_method("get_portal_id") and area.get_portal_id() == portal_id:
			return area
		# Thử lấy property portal_id trực tiếp
		if area.get("portal_id") != null and area.get("portal_id") == portal_id:
			return area
	return null


# =============================================================================
# HÀM RELOAD SCENE (reload_current_scene)
# =============================================================================
# Load lại scene hiện tại
# Dùng để reset scene (ví dụ: sau khi ngủ)

func reload_current_scene() -> void:
	if current_scene_path != "":
		change_scene(current_scene_path, "", false)


# =============================================================================
# HÀM LẤY SCENE HIỆN TẠI (get_current_scene)
# =============================================================================

func get_current_scene() -> Node:
	return get_tree().current_scene

# =============================================================================
# AUTO-SAVE HOOK (Khi chuyển scene)
# =============================================================================
# Snapshot trạng thái farm vào CatchUpSystem trước khi rời scene cũ
# để có thể phục hồi khi quay lại.

func _on_scene_changed(_scene_path: String) -> void:
	_persist_farm_state()

func persist_current_farm_state() -> void:
	_persist_farm_state()

func _persist_farm_state() -> void:
	var farm: Node = get_tree().get_first_node_in_group("farm_manager")
	if farm == null or not farm.has_method("serialize"):
		return
	_farm_snapshot = farm.serialize()
	print("[SceneManager] Persisted %d farm cells." % int(_farm_snapshot.get("cells", []).size()))

func _restore_farm_state_for_new_scene(new_scene: Node) -> void:
	# Wait one frame so child nodes finish _ready and join groups
	await get_tree().process_frame
	var farm: Node = new_scene.get_tree().get_first_node_in_group("farm_manager")
	if farm == null or not farm.has_method("deserialize"):
		return
	if _farm_snapshot.is_empty():
		return
	farm.deserialize(_farm_snapshot)
	# Trigger crop visual manager rebuild
	var crop_visuals: Node = new_scene.get_tree().get_first_node_in_group("crop_visual_manager")
	if crop_visuals != null and crop_visuals.has_method("on_farm_data_loaded"):
		crop_visuals.on_farm_data_loaded()
	elif crop_visuals != null and crop_visuals.has_method("rebuild_all"):
		crop_visuals.rebuild_all()
	# Trigger soil visual refresh
	var plot: Node = new_scene.get_tree().get_first_node_in_group("farm_plot")
	if plot != null and plot.has_method("_refresh_soil_visuals"):
		plot.call("_refresh_soil_visuals")
	print("[SceneManager] Restored %d farm cells." % int(_farm_snapshot.get("cells", []).size()))
