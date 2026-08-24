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

# Phat ra NGAY TRUOC khi scene cu bi remove khoi tree. Listener (NPCManager) dung
# de detach NPC attached o scene cu truoc khi Godot queue_free scene do — tranh
# warning "freed instance" khi NPC instance bi free theo scene.
# Tham số:
#   old_scene_path (String) - đường dẫn scene cũ ("" nếu là lần đầu load).
#   new_scene_path (String) - đường dẫn scene mới sắp được add.
signal scene_changing(old_scene_path: String, new_scene_path: String)


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

# Cache scene instances đang active — key = scene_file_path, value = scene Node.
# Dùng để sync với NPCManager._loaded_scenes khi SceneManager reuse scene.
var _loaded_scenes: Dictionary = {}

# Layer overlay để fade
var _transition_overlay: ColorRect

# CanvasLayer chứa overlay
var _transition_canvas: CanvasLayer

# Portal ID để đặt player sau khi chuyển scene
var _pending_portal_id: String = ""

# Tween cho animation fade
var _transition_tween: Tween

# Player position cuối cùng ở mỗi scene trước khi rời đi, key = scene path.
# Dùng để khi quay lại scene này player spawn ở đúng vị trí đã rời.
# KHÔNG lưu khi spawn từ portal (vì chưa đi loanh quanh được) → xem _is_via_portal.
var _last_player_positions: Dictionary = {}

# Lưu vị trí player khi đã "thực sự" di chuyển trong scene (không phải teleport do portal).
# Set true bởi player.gd qua notify_moved() mỗi frame khi pos thay đổi.
# SceneManager chỉ capture khi flag này true.
var _player_has_moved: bool = false

# Đánh dấu lần chuyển scene gần nhất qua portal_id != "".
# Để _pick_spawn_position skip nhánh "saved position" và dùng portal trước.
var _is_via_portal: bool = false


# =============================================================================
# HÀM KHỞI TẠO (_ready)
# =============================================================================

func _ready() -> void:
	print("[SceneManager] Ready — portal transition system active.")
	# Persist in-memory farm data whenever the scene changes
	scene_changed.connect(_on_scene_changed)
	# Reset hoàn toàn khi SceneTree sẵn sàng
	get_tree().tree_changed.connect(_on_tree_changed)

# Reset toàn bộ state khi tree thay đổi (game start/restart)
func _on_tree_changed() -> void:
	pass  # Có thể mở rộng nếu cần

# Farm snapshot để persist giữa các scene
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
	_is_via_portal = portal_id != ""

	# Chụp pos player hiện tại TRƯỚC khi load scene mới (chỉ khi player thực sự di chuyển,
	# không phải vừa teleport từ portal sang).
	_capture_current_player_position()
	_player_has_moved = false

	# Reset hoàn toàn farm snapshot khi chuyển scene KHÔNG phải farm
	# Để tránh state cũ ảnh hưởng
	if not scene_path.contains("farm"):
		_farm_snapshot.clear()
		print("[SceneManager] Cleared farm snapshot for non-farm scene")

	# Chuyển scene
	if use_transition:
		# Có fade: bắt đầu animation fade
		_start_fade_to_black(scene_path)
	else:
		# Không fade: load trực tiếp → emit scene_changing ở đây
		# (vì _load_scene không emit nữa)
		var old_path: String = ""
		var current: Node = get_tree().current_scene
		if current != null:
			old_path = current.scene_file_path
		scene_changing.emit(old_path, scene_path)
		_load_scene(scene_path)


# =============================================================================
# PUBLIC API — để player thông báo khi thực sự di chuyển (không phải teleport)
# =============================================================================

func notify_player_moved() -> void:
	_player_has_moved = true


# =============================================================================
# PLAYER POSITION CAPTURE / RESTORE
# =============================================================================

func _capture_current_player_position() -> void:
	if not _player_has_moved:
		return
	var tree := get_tree()
	if tree == null:
		return
	var player := tree.get_first_node_in_group("player")
	if player == null or not (player is Node2D):
		return
	var cur_scene := tree.current_scene
	if cur_scene == null:
		return
	# Key = scene path tuyệt đối của scene đang rời đi
	var key := cur_scene.scene_file_path
	if key == "":
		return
	_last_player_positions[key] = (player as Node2D).global_position
	print("[SceneManager] Saved player pos for %s: %s" % [key, str(_last_player_positions[key])])


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
	# Emit scene_changing ở đây (trước _load_scene) vì _load_scene không emit nữa.
	# Đây là điểm duy nhất _load_scene được gọi sau fade — cả fade và non-fade đều đi qua đây.
	var old_scene_path: String = ""
	var current: Node = get_tree().current_scene
	if current != null:
		old_scene_path = current.scene_file_path
	scene_changing.emit(old_scene_path, scene_path)
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
	# Snapshot farm state from current scene BEFORE removing it (nếu có farm)
	_persist_farm_state()

	# =================================================================
	# LOAD SCENE MỚI
	# =================================================================
	# Với design mới: NPCs attach trực tiếp vào player's scene, không còn
	# preload scene riêng. Mỗi lần player đến scene → tạo instance mới.
	# Scene cũ được queue_free khi player rời đi.
	var packed := load(scene_path)
	if packed == null:
		push_error("[SceneManager] Failed to load: %s" % scene_path)
		return
	var new_scene: Node = packed.instantiate()
	if new_scene == null:
		push_error("[SceneManager] Instantiate failed: %s" % scene_path)
		return

	# Lấy root node
	var root := get_tree().root

	# =================================================================
	# XÓA SCENE CŨ
	# =================================================================
	_free_current_scene_except_persistent()

	# =================================================================
	# THÊM SCENE MỚI
	# =================================================================
	root.add_child(new_scene)
	get_tree().current_scene = new_scene

	# Emit scene_changed ĐỂ NPCManager attach NPC vào scene mới (nếu reuse thì
	# NPC đã attached; nếu scene mới thì NPCManager sẽ attach sau).
	# Emit trước fade-in để NPCManager sync kịp thời.
	scene_changed.emit(scene_path)

	# =================================================================
	# KHÔI PHỤC FARM DATA NẾU SCENE MỚI CÓ FARM
	# =================================================================
	_restore_farm_state_for_new_scene(new_scene)

	# =================================================================
	# ĐẶT PLAYER THEO PRIORITY:
	#   1) Saved position (player thực sự di chuyển ở scene này trước đó)
	#   2) Portal target (nếu vừa chuyển qua portal)
	#   3) Bed (nếu flag knockout_spawn_at_bed)
	#   4) PlayerSpawn Marker2D (F5 playtest trực tiếp scene này)
	#   5) Scene-default position từ .tscn (giữ nguyên pos gốc)
	# =================================================================
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		push_error("[SceneManager] No player found in scene!")
		return

	if not player.has_method("force_position"):
		push_error("[SceneManager] Player missing force_position method!")
		return

	var spawn_pos := _pick_spawn_position(new_scene, scene_path)
	player.force_position(spawn_pos)
	_is_via_portal = false
	print("[SceneManager] Spawned player at %s" % str(spawn_pos))

	# Sau khi spawn, reset flag: player mới ở scene mới, phải di chuyển thật thì mới capture lại.
	# Nhưng KHÔNG clear saved-pos: ta vẫn muốn giữ pos cuối lần trước ở scene này.
	_player_has_moved = false

	# Xóa farm snapshot nếu đây là scene đầu tiên (F5) hoặc scene không phải farm
	_farm_snapshot.clear()
	print("[SceneManager] Cleared farm snapshot for fresh load")


# =============================================================================
# HÀM PICK SPAWN POSITION
# =============================================================================
# Áp dụng priority: saved > portal > bed > PlayerSpawn marker > scene-default.

func _pick_spawn_position(new_scene: Node, scene_path: String) -> Vector2:
	# Ưu tiên 0: Bed nếu flag knockout đang active (giữ behavior cũ)
	if GameState.get_flag("knockout_spawn_at_bed", false):
		GameState.set_flag("knockout_spawn_at_bed", false)
		var bed := _find_bed_in_scene(new_scene)
		if bed != null:
			print("[SceneManager] Spawn: knockout at bed")
			return bed.global_position + Vector2(0, 16)

	# Ưu tiên 1: Portal target nếu vừa chuyển qua portal
	if _pending_portal_id != "":
		var portal := _find_portal_in_scene(new_scene, _pending_portal_id)
		if portal != null:
			print("[SceneManager] Spawn: portal '%s'" % _pending_portal_id)
			_pending_portal_id = ""
			return portal.global_position
		else:
			push_warning("[SceneManager] Portal '%s' not found in %s" % [_pending_portal_id, scene_path])
			_pending_portal_id = ""

	# Ưu tiên 2: Saved position (chỉ khi KHÔNG qua portal → đây là A→B→A flow)
	if not _is_via_portal and _last_player_positions.has(scene_path):
		var saved: Vector2 = _last_player_positions[scene_path]
		print("[SceneManager] Spawn: saved pos for %s" % scene_path)
		return saved

	# Ưu tiên 3: PlayerSpawn Marker2D (F5 playtest trực tiếp)
	var marker := _find_player_spawn_marker(new_scene)
	if marker != null:
		print("[SceneManager] Spawn: PlayerSpawn marker")
		return marker.global_position

	# Ưu tiên 4: Scene-default pos — giữ pos hiện tại của player trong scene .tscn
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player is Node2D:
		print("[SceneManager] Spawn: scene-default")
		return (player as Node2D).global_position
	print("[SceneManager] Spawn: scene-default zero (player missing)")
	return Vector2.ZERO


func _find_player_spawn_marker(scene: Node) -> Node2D:
	# Tìm Marker2D tên "PlayerSpawn" hoặc bất kỳ Node2D nào trong group "player_spawn"
	for child in scene.find_children("*", "Marker2D", true, false):
		if child.name == "PlayerSpawn":
			return child
	for child in scene.find_children("*", "Node2D", true, false):
		if child.is_in_group("player_spawn"):
			return child
	return null


# =============================================================================
# PUBLIC API — lấy scene instance đang active cho scene_path
# =============================================================================
# Dùng bởi NPCManager để lấy scene thực sự SceneManager dùng làm current_scene
# (reuse từ NPC preload hoặc scene mới). Đảm bảo NPCManager attach NPC vào
# scene thực sự, không phải scene persistent cũ đã bị free.
func get_loaded_scene(scene_path: String) -> Node:
	if scene_path == "":
		return null
	if _loaded_scenes.has(scene_path):
		var cached: Variant = _loaded_scenes[scene_path]
		if cached != null and is_instance_valid(cached) and cached.is_inside_tree():
			return cached as Node
		_loaded_scenes.erase(scene_path)
	return null


# =============================================================================
# DEBUG — trace all scene instances in tree
# =============================================================================
func debug_print_all_scenes_in_tree() -> void:
	var tree := get_tree()
	if tree == null or tree.root == null:
		print("[SceneManager] debug: tree is null")
		return
	print("[SceneManager] === All scenes in tree (root children) ===")
	for i in range(tree.root.get_child_count()):
		var child: Node = tree.root.get_child(i)
		var valid := is_instance_valid(child)
		var in_tree := valid and child.is_inside_tree()
		var queued := valid and child.is_queued_for_deletion()
		var is_current := valid and tree.current_scene != null and child == tree.current_scene
		print("  [%d] name=%s path=%s valid=%s in_tree=%s queued=%s is_current=%s" % [
			i, str(child.name), child.scene_file_path if "scene_file_path" in child else "?",
			str(valid), str(in_tree), str(queued), str(is_current)])
	print("[SceneManager] ===========================================")


# =============================================================================
# HÀM LẤY SCENE HIỆN TẠI AN TOÀN (_get_current_scene_safe)
# =============================================================================
# Wrapper an toàn cho get_tree().current_scene — tránh crash khi tree chưa ready.
func _get_current_scene_safe() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.current_scene


# =============================================================================
# HÀM FREE SCENE CŨ (_free_current_scene_except_persistent)
# =============================================================================
# Xóa scene hiện tại khỏi tree. Scene mới đã được tạo trong _load_scene.
# NPCs trong scene cũ đã được detach trong _on_scene_changing.
func _free_current_scene_except_persistent() -> void:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return
	var current: Node = tree.current_scene
	if current == null:
		return
	# Skip nếu scene đang chờ xóa (prevent crash nếu gọi 2 lần).
	if current.is_queued_for_deletion():
		return
	# Xóa scene cũ bình thường.
	var old_path: String = current.scene_file_path
	tree.root.remove_child(current)
	current.queue_free()
	print("[SceneManager] Freed scene: %s" % old_path)


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

func _find_bed_in_scene(scene: Node) -> Node:
	return scene.find_child("Bed", true, false)


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
	# Chỉ restore farm state nếu scene mới CÓ farm manager VÀ có farm snapshot
	if _farm_snapshot.is_empty():
		return

	# Đợi một frame để các node con hoàn thành _ready
	var tree := get_tree()
	if tree == null:
		return
	await tree.process_frame

	var farm: Node = new_scene.get_tree().get_first_node_in_group("farm_manager")
	if farm == null:
		print("[SceneManager] No farm_manager in this scene, skipping farm restore")
		return

	if not farm.has_method("deserialize"):
		push_error("[SceneManager] farm_manager missing deserialize method!")
		return

	farm.deserialize(_farm_snapshot)
	print("[SceneManager] Restored %d farm cells." % int(_farm_snapshot.get("cells", []).size()))

	# Trigger crop visual manager rebuild
	var crop_visuals: Node = new_scene.get_tree().get_first_node_in_group("crop_visual_manager")
	if crop_visuals != null:
		if crop_visuals.has_method("on_farm_data_loaded"):
			crop_visuals.on_farm_data_loaded()
		elif crop_visuals.has_method("rebuild_all"):
			crop_visuals.rebuild_all()

	# Trigger soil visual refresh
	var plot: Node = new_scene.get_tree().get_first_node_in_group("farm_plot")
	if plot != null and plot.has_method("refresh_soil_visuals"):
		plot.refresh_soil_visuals()
