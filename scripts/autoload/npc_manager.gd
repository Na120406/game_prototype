extends Node
# =============================================================================
# NPC MANAGER (Quản lý NPC toàn cục)
# =============================================================================
# Mỗi NPC chỉ tồn tại 1 instance duy nhất xuyên suốt game session. Khi player
# di chuyển sang scene khác (hoặc khi giờ trong game đổi qua mốc schedule),
# NPCManager sẽ:
#   1. Tính step khớp với current_time.
#   2. Nếu step.scene == current_scene_path → spawn (attach) NPC vào scene
#      hiện tại tại step.pos.
#   3. Ngược lại → detach NPC khỏi scene hiện tại (NPC vẫn tồn tại trong
#      manager, chỉ không có mặt trong tree).
#
# Schedule step mở rộng: thêm field `scene` (path scene tuyệt đối). Step nào
# không có `scene` sẽ dùng default_scene của NPC (set trong lúc đăng ký).
#
# Hook:
#   - SceneManager.scene_changed → gọi sync_all() để respawn/despawn tất cả NPC.
#   - TimeManager.hour_elapsed → gọi sync_all() để NPC chuyển scene khi đổi giờ.
# =============================================================================

# =============================================================================
# TÍN HIỆU (SIGNALS)
# =============================================================================
# Phát khi NPC được spawn (attach) vào scene hiện tại.
signal npc_spawned(npc_id: String, scene_path: String)
# Phát khi NPC bị despawn (detach) khỏi scene.
signal npc_despawned(npc_id: String, scene_path: String)

# =============================================================================
# CẤU TRÚC DỮ LIỆU
# =============================================================================
# Mỗi NPC được lưu trong Dictionary:
#   {
#     "id": "neighbor",                 # npc_id duy nhất
#     "scene_path": "res://...",        # packed scene path để instantiate
#     "default_scene": "res://...",     # scene mặc định nếu step không ghi rõ
#     "instance": Node2D,               # packed instance (luôn tồn tại)
#     "current_scene": "res://...",     # scene hiện đang attach ("" nếu detached)
#     "spawned": bool,                  # true nếu đang ở trong tree
#     "start_pos": Vector2,             # vị trí spawn ban đầu (khi schedule rỗng)
#   }
#
# Lịch trình lấy từ NPC instance.schedule (mảng các Dictionary có `time`, `state`,
# `action`, `pos`, `scene`).
# =============================================================================

var _npcs: Dictionary = {}
# Key = npc_id, value = Dictionary như trên.

# Registry các NPC đăng ký khi game start. Định nghĩa tập trung tại đây để dễ
# quản lý — mỗi NPC cần:
#   - id: ID duy nhất (khớp với npc_id trong NPC scene).
#   - scene_path: packed scene path để load NPC.
#   - default_scene: scene NPC thuộc về (NPCManager spawn NPC ở scene này nếu
#     schedule không chỉ định rõ scene).
#   - spawn_pos: vị trí fallback khi schedule rỗng.
#   - npc_id_in_scene: ID dùng để gọi NPCManager.get_npc_instance("xxx").
const NPC_REGISTRY: Array[Dictionary] = [
	{
		"id": "neighbor",
		"scene_path": "res://scenes/npc/neighbor.tscn",
		"default_scene": "res://scenes/maps/marcus_farm_map.tscn",
		"spawn_pos": Vector2(375, 200),
	},
	{
		"id": "shopkeeper",
		"scene_path": "res://scenes/npc/shopkeeper.tscn",
		"default_scene": "res://scenes/maps/inside_shop_map.tscn",
		"spawn_pos": Vector2(360, 68),
	},
]

# =============================================================================
# HÀM KHỞI TẠO (_ready)
# =============================================================================

func _ready() -> void:
	# Kết nối signals — chỉ connect 1 lần, idempotent.
	var sm := _get_scene_manager()
	if sm != null:
		if not sm.scene_changing.is_connected(_on_scene_changing):
			# scene_changing emit TRƯỚC khi scene cũ bị free → detach NPC kịp.
			sm.scene_changing.connect(_on_scene_changing)
		if not sm.scene_changed.is_connected(_on_scene_changed):
			# scene_changed emit SAU khi scene mới ready → sync NPC vào scene mới.
			sm.scene_changed.connect(_on_scene_changed)
	var tm := _get_time_manager()
	if tm != null:
		if not tm.hour_elapsed.is_connected(_on_hour_elapsed):
			tm.hour_elapsed.connect(_on_hour_elapsed)
		# Listen time_changed để tick NPC schedule độc lập với player.
		# time_changed phát mỗi frame khi current_time thay đổi đáng kể (>0.001)
		# → tick_schedule sẽ tự skip nếu chưa tới step mới.
		if not tm.time_changed.is_connected(_on_time_changed):
			tm.time_changed.connect(_on_time_changed)
	# GameState.day_changed cũng cần trigger sync (Marcus có thể ở scene khác sau
	# khi qua ngày).
	if not GameState.day_changed.is_connected(_on_day_changed):
		GameState.day_changed.connect(_on_day_changed)
	# Đăng ký tất cả NPC trong registry.
	_register_all_npcs_from_registry()
	# Apply step hiện tại cho từng NPC (set state + desired_pos dựa trên
	# GameState.current_time lúc start). Sau đó attach NPC vào scene đúng.
	_apply_initial_schedule_for_all()
	_sync_attach_all()
	print("[NPCManager] Ready — %d NPCs registered." % _npcs.size())


func _register_all_npcs_from_registry() -> void:
	for entry in NPC_REGISTRY:
		var npc_id: String = entry.get("id", "")
		var scene_path: String = entry.get("scene_path", "")
		var default_scene: String = entry.get("default_scene", "")
		var spawn_pos: Vector2 = entry.get("spawn_pos", Vector2.ZERO)
		if npc_id == "" or scene_path == "":
			push_warning("[NPCManager] NPC_REGISTRY entry thiếu id hoặc scene_path — bỏ qua.")
			continue
		register_npc(npc_id, scene_path, default_scene, spawn_pos)


# =============================================================================
# API ĐĂNG KÝ NPC (register_npc)
# =============================================================================
# Đăng ký một NPC với manager. NPC sẽ được instantiate 1 lần (ngoài tree) và
# gắn vào scene khi schedule khớp.
#
# Tham số:
#   npc_id: String - ID duy nhất của NPC (ví dụ: "neighbor", "shopkeeper")
#   scene_path: String - packed scene path để load NPC (ví dụ: "res://scenes/npc/neighbor.tscn")
#   default_scene: String - scene mặc định NPC "thuộc về" khi step không ghi rõ
#   spawn_pos: Vector2 - vị trí fallback nếu schedule rỗng
func register_npc(npc_id: String, scene_path: String, default_scene: String, spawn_pos: Vector2 = Vector2.ZERO) -> bool:
	if _npcs.has(npc_id):
		push_warning("[NPCManager] NPC '%s' đã được đăng ký — bỏ qua." % npc_id)
		return false
	if not ResourceLoader.exists(scene_path):
		push_error("[NPCManager] Scene NPC '%s' không tồn tại: %s" % [npc_id, scene_path])
		return false
	var packed: PackedScene = load(scene_path)
	if packed == null:
		push_error("[NPCManager] Load packed scene thất bại: %s" % scene_path)
		return false
	var instance: Node = packed.instantiate()
	if instance == null:
		push_error("[NPCManager] Instantiate NPC '%s' thất bại." % npc_id)
		return false
	# NPC instance phải là Node2D (CharacterBody2D kế thừa Node2D) — kiểm tra.
	if not (instance is Node2D):
		push_error("[NPCManager] NPC '%s' không phải Node2D." % npc_id)
		instance.queue_free()
		return false
	# Gọi _build_default_schedule() VÌ packed.instantiate() KHÔNG gọi _ready()
	# (NPC chưa trong tree). Schedule cần được build ngay sau instantiate để
	# _sync_one có dữ liệu schedule đúng khi gọi get_schedule().
	if instance.has_method("_build_default_schedule"):
		instance.call("_build_default_schedule")
	_npcs[npc_id] = {
		"id": npc_id,
		"scene_path": scene_path,
		"default_scene": default_scene,
		"instance": instance,
		"current_scene": "",
		"spawned": false,
		"start_pos": spawn_pos,
	}
	print("[NPCManager] Registered NPC '%s' (default scene: %s)." % [npc_id, default_scene])
	return true


# =============================================================================
# API LẤY NPC (get_npc_instance)
# =============================================================================
# Trả về instance của NPC (Node2D hoặc null nếu chưa đăng ký / đã bị free).
# Dùng cho scripts khác (counter.gd, player.gd...) tham chiếu NPC mà không cần
# biết NPC có đang trong scene hay không.
#
# An toàn với freed object: dùng `instance_from_id` hoặc check `is_instance_valid`
# TRƯỚC khi cast — tránh "Trying to cast a freed object" error.
func get_npc_instance(npc_id: String) -> Node2D:
	return _get_valid_instance(npc_id)


# Helper nội bộ — trả về instance hợp lệ (Node2D) hoặc null. Luôn kiểm tra
# is_instance_valid trước khi cast để tránh runtime error khi NPC đã bị free.
func _get_valid_instance(npc_id: String) -> Node2D:
	if not _npcs.has(npc_id):
		return null
	var raw: Variant = _npcs[npc_id].get("instance", null)
	if raw == null:
		return null
	# raw là Object — nếu đã free, is_instance_valid trả false. Cast `as Node2D`
	# trên freed object sẽ crash với "Trying to cast a freed object", nên check
	# is_instance_valid TRƯỚC khi cast.
	if not is_instance_valid(raw):
		return null
	return raw as Node2D


# Trả về NPC instance đang thực sự có mặt trong scene hiện tại (không detached).
# Counter sẽ dùng hàm này để kiểm tra Shopkeeper có đang ở gần không.
func get_active_npc_in_current_scene(npc_id: String) -> Node2D:
	if not _npcs.has(npc_id):
		return null
	var entry: Dictionary = _npcs[npc_id]
	if not entry.get("spawned", false):
		return null
	var inst := _get_valid_instance(npc_id)
	if inst == null:
		return null
	var cur_scene := _get_current_scene_path()
	if entry.get("current_scene", "") != cur_scene:
		return null
	return inst


# =============================================================================
# SCENE INSTANCE CACHE — track các scene đã load để attach NPC vào scene đúng
# =============================================================================
# Với design mới: NPCs attach trực tiếp vào player's current_scene. Khi player
# chuyển scene → scene cũ được queue_free → NPCManager detaches NPCs.
#
# Cache này chủ yếu dùng để tìm player's current_scene nhanh.
var _loaded_scenes: Dictionary = {}


# Tìm scene node trong tree có scene_file_path khớp. Trả null nếu chưa load.
# Chỉ cần tìm player's current_scene.
func _find_loaded_scene(scene_path: String) -> Node:
	if scene_path == "":
		return null
	var tree := get_tree()
	if tree == null or tree.root == null:
		return null
	# Chỉ cần kiểm tra current_scene của player.
	var current := tree.current_scene
	if current != null and is_instance_valid(current) and current.is_inside_tree():
		if not current.is_queued_for_deletion() and current.scene_file_path == scene_path:
			_loaded_scenes[scene_path] = current
			return current
	return null


# Refresh cache — quét toàn bộ scene instances đang active trong tree.
# Gọi khi scene load mới hoặc sync_all.
func _refresh_scene_cache() -> void:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return
	# Clear cache entries không còn valid.
	for scene_path in _loaded_scenes.keys():
		var node: Variant = _loaded_scenes[scene_path]
		if node == null or not is_instance_valid(node) or not node.is_inside_tree():
			_loaded_scenes.erase(scene_path)
			continue
		# Skip scene đang chờ xóa — không dùng được nữa.
		if node as Node:
			if (node as Node).is_queued_for_deletion():
				_loaded_scenes.erase(scene_path)
	# Scan root để tìm scene mới (chưa có trong cache).
	for child in tree.root.get_children():
		if child is Node and child.scene_file_path != "":
			# Skip queued for deletion.
			if child.is_queued_for_deletion():
				continue
			var sp: String = child.scene_file_path
			if not _loaded_scenes.has(sp):
				_loaded_scenes[sp] = child


# =============================================================================
# ĐỒNG BỘ TẤT CẢ NPC VỚI SCENE HIỆN TẠI + GIỜ HIỆN TẠI (sync_all)
# =============================================================================
# Duyệt từng NPC đã đăng ký → tính step khớp current_time → spawn ở scene
# theo schedule (KHÔNG phải scene của player). NPC tồn tại độc lập với vị trí
# player — khi player đi đến scene của NPC thì sẽ thấy NPC đang đứng ở đó.
func sync_all() -> void:
	if _npcs.is_empty():
		return
	_refresh_scene_cache()
	for npc_id in _npcs.keys():
		_sync_one(npc_id)


# Đồng bộ 1 NPC cụ thể. NPC chỉ attach vào player's current_scene khi player
# đang ở scene của NPC (schedule/default_scene). Nếu player chưa đến scene của
# NPC → NPC không xuất hiện (spawned=false).
func _sync_one(npc_id: String) -> void:
	if not _npcs.has(npc_id):
		return
	var entry: Dictionary = _npcs[npc_id]
	var inst := _get_valid_instance(npc_id)
	if inst == null:
		print("[NPCManager] _sync_one '%s': instance is null" % npc_id)
		return
	var schedule: Array = []
	if inst.has_method("get_schedule"):
		schedule = inst.call("get_schedule")
	# Tìm scene đích theo schedule (hoặc default).
	var target_scene: String = ""
	var step_pos: Vector2 = entry.get("start_pos", Vector2.ZERO)
	if schedule.is_empty():
		target_scene = entry.get("default_scene", "")
		print("[NPCManager] _sync_one '%s': schedule empty, using default_scene=%s" % [npc_id, target_scene])
	else:
		var step: Dictionary = _pick_step(schedule, GameState.current_time)
		target_scene = step.get("scene", "")
		if target_scene == "":
			target_scene = entry.get("default_scene", "")
		step_pos = step.get("pos", entry.get("start_pos", Vector2.ZERO))
		print("[NPCManager] _sync_one '%s': target_scene=%s, step=%s, pos=%s" % [npc_id, target_scene, step.get("action", "?"), str(step_pos)])
	# Nếu NPC đã attach đúng scene rồi → không cần re-attach.
	if entry.get("spawned", false) and entry.get("current_scene", "") == target_scene:
		return
	# Nếu target_scene khác scene đang attach → detach trước.
	if entry.get("spawned", false) and entry.get("current_scene", "") != target_scene:
		_detach_npc(npc_id, entry.get("current_scene", ""))
	# Attach vào target_scene.
	if target_scene != "":
		_attach_npc(npc_id, target_scene, step_pos)


# =============================================================================
# TÌM STEP KHỚP current_time
# =============================================================================
# Schedule là mảng đã sắp xếp theo `time` tăng dần. Trả về step có time lớn
# nhất mà <= current_time.
#
# Trường hợp đặc biệt — current_time < step[0].time (ví dụ 0:00–5:59 với
# schedule bắt đầu từ 6:00): trả về step CUỐI cùng trong ngày. Lý do: NPC vừa
# "sleep" ở step cuối (22:00+) — sáng sớm hôm sau player vẫn đang ở scene của
# step sleep (marcus_house_map). Nếu trả step[0] (scene=marcus_farm_map) →
# NPC bị detach khỏi house → biến mất giữa đêm.
#
# Logic đúng: step cuối luôn có time lớn nhất, và current_time wrap về 0-24
# mỗi ngày. Vậy step cuối là "trạng thái hiện tại" của NPC khi đang ở ranh
# giới giữa ngày hôm trước và ngày mới.
func _pick_step(schedule: Array, current_time: float) -> Dictionary:
	if schedule.is_empty():
		return {}
	var last_step: Dictionary = {}
	for s in schedule:
		var t: float = float(s.get("time", 0.0))
		if current_time >= t:
			last_step = s
		else:
			break
	# current_time < step[0].time → dùng step cuối (NPC đang ở trạng thái
	# step cuối của ngày hôm trước, sẽ chuyển sang step[0] khi tới time của nó).
	if last_step.is_empty():
		last_step = schedule[schedule.size() - 1]
	return last_step


# =============================================================================
# ATTACH / DETACH NPC VỚI SCENE TREE
# =============================================================================

func _attach_npc(npc_id: String, scene_path: String, spawn_pos: Vector2) -> void:
	if not _npcs.has(npc_id):
		return
	var entry: Dictionary = _npcs[npc_id]
	var inst := _get_valid_instance(npc_id)
	if inst == null:
		return
	var tree := get_tree()
	if tree == null or tree.root == null:
		return
	# Nếu đã attach ở đúng scene rồi → KHÔNG snap pos.
	if entry.get("spawned", false) and entry.get("current_scene", "") == scene_path:
		return
	# Nếu đang attach ở scene khác → detach trước.
	if entry.get("spawned", false) and inst.get_parent() != null:
		inst.get_parent().remove_child(inst)
	# Tìm player's current scene — NPC attach vào scene player đang ở,
	# KHÔNG phải scene riêng của NPC (NPC không còn preload scene riêng).
	# Nếu player KHÔNG đang ở scene_path → không attach (NPC chưa xuất hiện).
	var current_scene := tree.current_scene
	if current_scene == null:
		return
	var current_scene_path := current_scene.scene_file_path
	# Player phải đang ở scene mà NPC "thuộc về" mới attach.
	if current_scene_path != scene_path:
		# Scene chưa load / player chưa đến → NPC chưa xuất hiện.
		# Đánh dấu entry["current_scene"] = scene_path để track desired scene
		# (nhưng spawned = false vì chưa attach).
		entry["current_scene"] = scene_path
		entry["spawned"] = false
		print("[NPCManager] NPC '%s' not spawned: player in %s, NPC belongs to %s" % [npc_id, current_scene_path, scene_path])
		return
	# Player đang ở scene của NPC → attach NPC vào current scene.
	current_scene.add_child(inst)
	inst.global_position = spawn_pos
	entry["current_scene"] = scene_path
	entry["spawned"] = true
	# Reset NPC state để nó không còn "walk" từ scene cũ.
	if inst.has_method("_on_attached_to_scene"):
		inst.call("_on_attached_to_scene")
	npc_spawned.emit(npc_id, scene_path)
	print("[NPCManager] Spawned NPC '%s' in player scene at %s." % [npc_id, str(spawn_pos)])


func _detach_npc(npc_id: String, cur_scene_path: String) -> void:
	if not _npcs.has(npc_id):
		return
	var entry: Dictionary = _npcs[npc_id]
	if not entry.get("spawned", false):
		return
	var inst := _get_valid_instance(npc_id)
	if inst != null and inst.get_parent() != null:
		# Gọi hook trước khi detach để NPC dừng walk, save state.
		if inst.has_method("_on_detached_from_scene"):
			inst.call("_on_detached_from_scene")
		inst.get_parent().remove_child(inst)
	entry["spawned"] = false
	entry["current_scene"] = ""
	npc_despawned.emit(npc_id, cur_scene_path)
	print("[NPCManager] Despawned NPC '%s' from %s." % [npc_id, cur_scene_path])


# =============================================================================
# CALLBACKS TỪ SCENEMANAGER + TIMEMANAGER
# =============================================================================

# Callback từ SceneManager.scene_changing — emit NGAY TRƯỚC khi scene cũ bị
# Godot free. PHẢI detach tất cả NPC đang attached khỏi scene cũ ở đây, nếu
# không Godot sẽ free NPC cùng scene cũ → entry["instance"] trỏ vào freed
# object → "Trying to assign invalid previously freed instance" warning.
#
# Lưu ý: signal này đồng bộ (sync), KHÔNG dùng call_deferred — phải detach
# TRƯỚC khi SceneManager gọi root.remove_child(scene_cũ) ở dòng tiếp theo.
func _on_scene_changing(_old_scene_path: String, _new_scene_path: String) -> void:
	# Detach ALL NPCs attached ở scene CŨ CỦA PLAYER trước khi scene bị remove.
	# NPCs giờ attach TRỰC TIẾP vào player's scene (không còn preload scene riêng),
	# nên khi player rời scene → tất cả NPC trong scene đó phải được detach.
	#
	# Logic:
	#   - Lấy current_scene sắp bị remove (từ _old_scene_path).
	#   - Detach tất cả NPC có entry["current_scene"] == _old_scene_path.
	#   - Điều này đảm bảo NPC không bị free cùng scene cũ.
	var tree := get_tree()
	if tree == null:
		return
	for npc_id in _npcs.keys():
		var entry: Dictionary = _npcs[npc_id]
		if entry.get("current_scene", "") != _old_scene_path:
			continue
		var inst: Variant = entry.get("instance", null)
		if inst == null or not is_instance_valid(inst):
			continue
		if inst.get_parent() != null:
			if inst.has_method("_on_detached_from_scene"):
				inst.call("_on_detached_from_scene")
			inst.get_parent().remove_child(inst)
		entry["spawned"] = false
		entry["current_scene"] = ""
		print("[NPCManager] Detached NPC '%s' from scene '%s' (about to be freed)." % [npc_id, _old_scene_path])


# Callback từ SceneManager.scene_changed — emit SAU khi scene mới đã được
# add vào tree. Lúc này an toàn để sync + attach NPC vào scene mới.
func _on_scene_changed(_scene_path: String) -> void:
	# Đợi 1 frame để scene mới ready (NPC spawn phải tìm tree.current_scene).
	call_deferred("_reapply_after_scene_change")


# Được gọi SAU scene mới ready (call_deferred). Tick schedule lại + sync attach
# NPC vào scene mới (CHỈ những NPC cần attach — sync tự skip NPC đã attached
# đúng scene).
func _reapply_after_scene_change() -> void:
	var ct := GameState.current_time
	tick_all_schedules(ct)
	sync_all()


func _on_hour_elapsed(_hour: int) -> void:
	# Mỗi giờ → check schedule có NPC nào chuyển scene không.
	sync_all()


func _on_day_changed(_new_day: int) -> void:
	# Qua ngày mới → có thể NPC chuyển scene. Sync luôn.
	sync_all()


# Callback từ TimeManager.time_changed — chỉ tick schedule. NPC tự cập nhật
# state + desired_pos qua tick_schedule (xem npc.gd._apply_step). KHÔNG gọi
# sync_all ở đây vì NPC tự walk tới desired_pos trong scene attached. sync_all
# chỉ cần khi scene thay đổi hoặc giờ wrap (hour_elapsed/day_changed) — vì
# NPC có thể cần attach/detach scene mới.
func _on_time_changed(current_time: float, _is_day: bool) -> void:
	tick_all_schedules(current_time)


# Tick schedule cho từng NPC đã đăng ký. NPC tự cập nhật state + desired_pos.
# NPC KHÔNG cần attached để tick (state là invariant).
#
# Lưu ý: dùng Variant (không ép kiểu Node) khi lấy entry.get("instance") để
# tránh "Trying to assign invalid previously freed instance" warning trong
# editor. Type cast sang Node có thể trigger warning ngay cả khi sau đó có
# is_instance_valid check — vì warning phát ra lúc type assignment.
func tick_all_schedules(current_time: float) -> void:
	if _npcs.is_empty():
		return
	for npc_id in _npcs.keys():
		var entry: Dictionary = _npcs[npc_id]
		var inst: Variant = entry.get("instance", null)
		if inst == null or not is_instance_valid(inst):
			continue
		if inst.has_method("tick_schedule"):
			inst.call("tick_schedule", current_time)


# Apply step hiện tại cho tất cả NPC lúc khởi động. Set state + desired_pos
# theo GameState.current_time hiện tại TRƯỚC khi attach vào scene.
func _apply_initial_schedule_for_all() -> void:
	if _npcs.is_empty():
		return
	for npc_id in _npcs.keys():
		var entry: Dictionary = _npcs[npc_id]
		var inst: Variant = entry.get("instance", null)
		if inst == null or not is_instance_valid(inst):
			continue
		if inst.has_method("apply_current_step"):
			inst.call("apply_current_step")


# Attach từng NPC vào scene khớp step hiện tại (nếu scene đó đang là
# current_scene). Lúc startup chưa có scene hiện tại → sync_all sẽ được gọi
# lại khi SceneManager.scene_changed emit.
func _sync_attach_all() -> void:
	sync_all()


# =============================================================================
# HELPERS
# =============================================================================

func _get_scene_manager() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("SceneManager")


func _get_time_manager() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("TimeManager")


func _get_current_scene_path() -> String:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return ""
	return tree.current_scene.scene_file_path
