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
# NPC chỉ được attach vào viewport nếu schedule scene trùng map Player; mọi NPC
# khác vẫn giữ instance trong PersistentNPCScenes và tiếp tục simulate.
#
# Hook:
#   - SceneManager.scene_changed → chỉ rehome NPC đang ở viewport Player.
#   - TimeManager.time_changed → tick schedule liên tục; NPC tự handoff tại portal.
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
		if sm.has_signal("persistent_npc_handed_off") and not sm.persistent_npc_handed_off.is_connected(_on_persistent_npc_handed_off):
			sm.persistent_npc_handed_off.connect(_on_persistent_npc_handed_off)
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
	# Apply step hiện tại trước khi scene runtime bắt đầu tick. NPC được đưa vào
	# background world theo schedule; Player scene chỉ là viewport quan sát.
	_apply_initial_schedule_for_all()
	# SceneTree is still constructing the initial map during autoload startup;
	# defer all add_child/reparent operations until the setup phase is complete.
	call_deferred("_sync_attach_all")
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
	# Nếu scene hiện tại đã đặt sẵn instance NPC (ví dụ shopkeeper trong
	# inside_shop_map), dùng instance đó thay vì tạo bản thứ hai tại spawn_pos.
	var existing: Node2D = _find_existing_npc_in_current_scene(npc_id)
	if existing != null:
		instance.queue_free()
		instance = existing
	else:
		# Runtime instance starts detached; it is attached only by schedule sync.
		instance.position = Vector2.ZERO
	# Gọi _build_default_schedule() khi instance chưa vào tree.
	if not instance.is_inside_tree() and instance.has_method("_build_default_schedule"):
		instance.call("_build_default_schedule")
	_npcs[npc_id] = {
		"id": npc_id,
		"scene_path": scene_path,
		"default_scene": default_scene,
		"instance": instance,
		"current_scene": "",
		"spawned": false,
		"start_pos": spawn_pos,
		"route_id": "",
		"route_index": -1,
		"route_progress": {},
		"last_simulated_day": 1,
		"last_simulated_time": 6.0,
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
func _find_existing_npc_in_current_scene(npc_id: String) -> Node2D:
	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		return null
	var group_name: String = "npc_%s" % npc_id
	for candidate: Node in tree.get_nodes_in_group(group_name):
		if candidate is Node2D and is_instance_valid(candidate) and tree.current_scene.is_ancestor_of(candidate):
			return candidate as Node2D
	return null

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
	# NPC luôn được simulate từ registry; Player chỉ quyết định scene nào nhìn thấy.
	var entry: Dictionary = _npcs[npc_id]
	# Runtime registry is authoritative. Scene-authored NPCs are removed here;
	# otherwise they become a second NPC at the scene default (often 0,0).
	var placed: Node2D = _find_existing_npc_in_current_scene(npc_id)
	var managed: Node2D = _get_valid_instance(npc_id)
	if placed != null and placed != managed:
		placed.queue_free()
	var inst: Node2D = _get_valid_instance(npc_id)
	if inst == null:
		print("[NPCManager] _sync_one '%s': instance is null" % npc_id)
		return
	var schedule: Array[Dictionary] = []
	if inst.has_method("get_schedule"):
		var raw_schedule: Variant = inst.call("get_schedule")
		if raw_schedule is Array:
			for raw_step in raw_schedule:
				if raw_step is Dictionary:
					schedule.append(raw_step)
	if schedule.is_empty() and npc_id == "shopkeeper":
		var shopkeeper_scene: String = "res://scenes/maps/inside_shop_map.tscn"
		schedule = [{"time": 0.0, "scene": shopkeeper_scene, "pos": Vector2(360, 68), "state": 2}]
	# Tìm scene đích theo schedule (hoặc default).
	var target_scene: String = ""
	var step_pos: Vector2 = entry.get("start_pos", Vector2.ZERO)
	var step_route_id: String = ""
	var selected_step: Dictionary = {}
	if schedule.is_empty():
		target_scene = entry.get("default_scene", "")
		print("[NPCManager] _sync_one '%s': schedule empty, using default_scene=%s" % [npc_id, target_scene])
	else:
		selected_step = _pick_step(schedule, GameState.current_time)
		target_scene = selected_step.get("scene", "")
		if target_scene == "":
			target_scene = entry.get("default_scene", "")
		var raw_step_pos: Variant = selected_step.get("pos", entry.get("start_pos", Vector2.ZERO))
		step_pos = raw_step_pos as Vector2 if raw_step_pos is Vector2 else entry.get("start_pos", Vector2.ZERO)
		step_route_id = str(selected_step.get("route_id", ""))
		entry["route_id"] = step_route_id
		print("[NPCManager] _sync_one '%s': target_scene=%s, step=%s, pos=%s" % [npc_id, target_scene, selected_step.get("action", "?"), str(step_pos)])

	# Khi bootstrap ở giữa một route (ví dụ load/save lúc 07:00), schedule
	# có thể đang ở step đích với route_id rỗng. Không được attach NPC thẳng
	# vào scene đích vì như vậy sẽ bỏ qua đoạn đi từ House -> Farm -> Town.
	# Tìm route step gần nhất trước step hiện tại có destination đúng với
	# target_scene, rồi khởi động từ waypoint nguồn của route đó.
	if inst.get_parent() == null and step_route_id == "":
		var route_bootstrap: Dictionary = _find_route_bootstrap(schedule, selected_step, target_scene)
		if not route_bootstrap.is_empty():
			step_route_id = str(route_bootstrap.get("route_id", ""))
			var bootstrap_step: Dictionary = route_bootstrap.get("step", {})
			target_scene = str(bootstrap_step.get("scene", target_scene))
			var bootstrap_pos: Variant = bootstrap_step.get("pos", step_pos)
			if bootstrap_pos is Vector2:
				step_pos = bootstrap_pos
			print("[NPCManager] Bootstrap '%s' through route '%s' from %s" % [npc_id, step_route_id, target_scene])
	# Nếu NPC đã attach đúng scene rồi → không re-attach và không teleport.
	# NPC instance sẽ nhận target mới qua tick_schedule() và tự đi bằng AI.
	var actual_host_scene: String = _get_npc_host_scene_path(inst)
	if entry.get("spawned", false) and actual_host_scene == target_scene:
		if inst.get_parent() != null and inst.has_method("tick_schedule"):
			inst.call("tick_schedule", GameState.current_time)
		if inst.has_method("get_route_progress"):
			entry["route_progress"] = inst.call("get_route_progress")
		return
	# Nếu NPC đã có parent (đang mô phỏng), manager không được teleport nó theo
	# scene của schedule. Chỉ npc.gd được quyền handoff sau khi chạm portal.
	# Manager chỉ attach instance detached lúc bootstrap.
	if target_scene != "" and inst.get_parent() == null:
		_attach_npc(npc_id, target_scene, step_pos, step_route_id)


func _find_route_bootstrap(schedule: Array[Dictionary], selected: Dictionary, selected_scene: String) -> Dictionary:
	var selected_index: int = schedule.find(selected)
	if selected_index <= 0:
		return {}
	for index: int in range(selected_index - 1, -1, -1):
		var candidate: Dictionary = schedule[index]
		var route_id: String = str(candidate.get("route_id", ""))
		if route_id == "":
			continue
		var route_manager: Node = get_node_or_null("/root/NPCRouteManager")
		if route_manager == null or not route_manager.has_method("get_route"):
			continue
		var route: Array = route_manager.call("get_route", route_id)
		if route.size() < 2:
			continue
		var destination: Dictionary = route[route.size() - 1]
		if str(destination.get("scene", "")) == selected_scene:
			return {"route_id": route_id, "step": candidate}
	return {}


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

func _attach_npc(npc_id: String, scene_path: String, spawn_pos: Vector2, route_id: String = "") -> void:
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
	if entry.get("spawned", false) and inst.get_parent() != null and _get_npc_host_scene_path(inst) == scene_path:
		if inst.has_method("tick_schedule"):
			inst.call("tick_schedule", GameState.current_time)
		return
	# Không detach instance persistent chỉ vì target schedule đổi scene.
	# NPC tự đi tới source portal; handoff được thực hiện bởi npc.gd.
	# Tìm player's current scene — NPC attach vào scene player đang ở,
	# KHÔNG phải scene riêng của NPC (NPC không còn preload scene riêng).
	# Nếu player KHÔNG đang ở scene_path → không attach (NPC chưa xuất hiện).
	var current_scene := tree.current_scene
	if current_scene == null:
		return
	var current_scene_path: String = current_scene.scene_file_path
	# Nếu instance đã nằm trong đúng scene nhưng metadata bị lệch, giữ nguyên
	# vị trí hiện tại và chỉ cập nhật target schedule — tuyệt đối không teleport.
	if inst.get_parent() == current_scene and current_scene_path == scene_path:
		entry["current_scene"] = scene_path
		entry["spawned"] = true
		if inst.has_method("tick_schedule"):
			inst.call("tick_schedule", GameState.current_time)
		return
	# Route được thực thi bởi NPC: NPC phải đi tới source portal trước.
	# Route không được bị bỏ qua khi target scene khác scene Player hiện tại;
	# NPC vẫn được giữ trong background và tiếp tục physics.
	# Manager tuyệt đối không handoff ngay theo schedule, nếu không sẽ teleport
	# NPC khỏi scene hiện tại và làm mất phần hành trình mà Player có thể theo dõi.
	if current_scene_path != scene_path:
		# A route-in-transit NPC must never be attached to the Player scene just
		# because the Player entered the route's destination map. It becomes
		# visible only after the NPC handoff has actually reached that map.
		if inst.get_parent() != null and route_id != "":
			return
		# Only bootstrapping may choose an initial position. During normal play the
		# persistent instance is already hosted by a background world and must not
		# be recreated/snap-moved when the Player enters another map.
		if inst.get_parent() == null:
			var initial_scene: String = scene_path
			var initial_position: Vector2 = spawn_pos
			if route_id != "":
				var route_manager: Node = get_node_or_null("/root/NPCRouteManager")
				if route_manager != null and route_manager.has_method("get_waypoint"):
					var first_waypoint: Variant = route_manager.call("get_waypoint", route_id, 0)
					if first_waypoint is Dictionary:
						initial_scene = str(first_waypoint.get("scene", initial_scene))
						var raw_initial_position: Variant = first_waypoint.get("position", initial_position)
						if raw_initial_position is Vector2:
							initial_position = raw_initial_position
			var scene_manager: Node = get_node_or_null("/root/SceneManager")
			if scene_manager != null and scene_manager.has_method("handoff_persistent_npc"):
				inst.global_position = initial_position
				var initial_portal_id: String = ""
				if route_id != "" and inst.has_method("get_destination_portal_id"):
					initial_portal_id = inst.call("get_destination_portal_id")
				if scene_manager.call("handoff_persistent_npc", inst, initial_scene, initial_portal_id):
					entry["current_scene"] = initial_scene
					entry["spawned"] = true
					return
		# NPC đã ở background scene: không reattach theo Player. Route physics
		# tiếp tục chạy tại parent hiện tại; registry lấy scene thật từ parent.
		# Player/scene transitions never use Bed or spawn positions for NPCs.
		if route_id != "" and inst.has_method("tick_schedule"):
			inst.call("tick_schedule", GameState.current_time)
		var actual_scene_path: String = _get_npc_host_scene_path(inst)
		if actual_scene_path != "":
			entry["current_scene"] = actual_scene_path
		entry["spawned"] = inst.get_parent() != null
		return
	# Chỉ rehome hoặc attach khi Player thật sự đang ở đúng map lịch trình.
	if inst.get_parent() != current_scene:
		# Rehome preserves the NPC's current world position for every background
		# root (NPCWorld_*) and never replaces it with the schedule target. The
		# NPC must walk there using velocity after becoming visible.
		var saved_global_position: Vector2 = inst.global_position
		if inst.get_parent() != null:
			inst.get_parent().remove_child(inst)
		current_scene.add_child(inst)
		inst.global_position = saved_global_position
		# Keep the logical destination on the instance, but never use the source
		# scene's coordinates as a destination spawn.
		inst.set_meta("world_scene_path", scene_path)
	entry["current_scene"] = scene_path
	entry["spawned"] = true
	if inst.has_method("get_route_progress"):
		entry["route_progress"] = inst.call("get_route_progress")
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
func _on_persistent_npc_handed_off(npc: Node2D, scene_path: String) -> void:
	if npc == null or not is_instance_valid(npc):
		return
	var actual_scene_path: String = _get_npc_host_scene_path(npc)
	if actual_scene_path == "":
		actual_scene_path = scene_path
	for npc_id: String in _npcs:
		var entry: Dictionary = _npcs[npc_id]
		if entry.get("instance", null) == npc:
			entry["current_scene"] = actual_scene_path
			entry["spawned"] = npc.get_parent() != null
			if npc.has_method("get_route_progress"):
				entry["route_progress"] = npc.call("get_route_progress")
			var progress: Variant = entry["route_progress"]
			if progress is Dictionary:
				entry["route_index"] = int(progress.get("waypoint_index", -1))
			break

func _on_scene_changing(_old_scene_path: String, _new_scene_path: String) -> void:
	# Player transition and NPC transition are independent. This callback only
	# preserves NPCs already visible in the outgoing scene; it must never send
	# them to _new_scene_path or invoke a second portal transition.
	# NPC ở PersistentNPCScenes không thuộc player scene và không được detach.
	# Chỉ detach NPC thực sự đang là child của scene sắp bị giải phóng.
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
		var inst: Variant = entry.get("instance", null)
		# Parent is authoritative: detach any managed NPC actually inside the
		# outgoing Player scene, even if registry metadata was updated early.
		if inst == null or not is_instance_valid(inst):
			continue
		if tree.current_scene == null or not tree.current_scene.is_ancestor_of(inst):
			continue
		if tree.current_scene.scene_file_path != _old_scene_path:
			continue
		if inst.get_parent() != null:
			if inst.has_method("_on_detached_from_scene"):
				inst.call("_on_detached_from_scene")
			# Player chuyển scene không được chuyển NPC sang _new_scene_path.
			# NPC này chưa chạm portal của nó, nên chỉ đưa nó vào background của
			# chính scene cũ để tiếp tục mô phỏng độc lập.
			var scene_manager: Node = get_node_or_null("/root/SceneManager")
			if scene_manager != null and scene_manager.has_method("handoff_persistent_npc"):
				if scene_manager.call("handoff_persistent_npc", inst, _old_scene_path, ""):
					entry["spawned"] = true
					entry["current_scene"] = _old_scene_path
					entry["route_progress"] = inst.call("get_route_progress") if inst.has_method("get_route_progress") else entry.get("route_progress", {})
					continue
			inst.get_parent().remove_child(inst)
		entry["spawned"] = false
		entry["current_scene"] = ""
		entry["route_progress"] = inst.call("get_route_progress") if inst.has_method("get_route_progress") else entry.get("route_progress", {})
		print("[NPCManager] Detached NPC '%s' from scene '%s' (about to be freed)." % [npc_id, _old_scene_path])


# Callback từ SceneManager.scene_changed — emit SAU khi scene mới đã được
# add vào tree. Lúc này an toàn để sync + attach NPC vào scene mới.
func _on_scene_changed(_scene_path: String) -> void:
	# Do not resync schedules here: scene changes must only reveal the one
	# persistent instance whose authoritative host is this scene. Resyncing can
	# attach the same NPC to every Player scene during the transition.
	# Scene mới phải hoàn tất _ready trước khi dọn authored NPC và rehome.
	call_deferred("_remove_authored_npc_duplicates")
	call_deferred("_rehome_visible_npcs")
	# A deferred handoff can complete after the first callback; retry from a
	# timer-free idle chain so the NPC is visible immediately on scene entry.
	call_deferred("_rehome_visible_npcs_late")

func _rehome_visible_npcs_late() -> void:
	call_deferred("_rehome_visible_npcs")

func _remove_authored_npc_duplicates() -> void:
	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		return
	for npc_id: String in _npcs:
		var managed: Node2D = _get_valid_instance(npc_id)
		var group_name: String = "npc_%s" % npc_id
		for candidate: Node in tree.get_nodes_in_group(group_name):
			if candidate is Node2D and candidate != managed and tree.current_scene.is_ancestor_of(candidate):
				candidate.queue_free()

func _try_rehome_single_npc(npc: Node2D, target_scene_path: String) -> void:
	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null or npc == null or not is_instance_valid(npc):
		return
	if tree.current_scene.scene_file_path != target_scene_path:
		return
	# The NPC arrived while Player was already in this map; rehome immediately.
	_rehome_visible_npcs()

func _rehome_visible_npcs() -> void:
	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		return
	var visible_scene: Node = tree.current_scene
	var visible_path: String = visible_scene.scene_file_path
	for npc_id: String in _npcs:
		var entry: Dictionary = _npcs[npc_id]
		var raw: Variant = entry.get("instance", null)
		if raw == null or not is_instance_valid(raw):
			continue
		var inst: Node2D = raw as Node2D
		var actual_scene_path: String = _get_npc_host_scene_path(inst)
		if inst.get_parent() == visible_scene:
			# Already visible in the active Player scene; never use stale metadata.
			actual_scene_path = visible_path
		# Parent identity is authoritative. Route progress is deliberately not used
		# for visibility: while a route is crossing a portal it may already point to
		# the destination before the NPC has actually been reparented.
		if actual_scene_path != visible_path:
			continue
		# Do not apply the schedule before rehome. At 22:00 this used to turn the
		# portal arrival into the sleep target before the Player could observe it.
		if entry.get("spawned", false) and inst.get_parent() == visible_scene:
			inst.visible = true
			inst.modulate = Color.WHITE
			# NPC body dùng layer 2: vẫn va chạm với world layer 1 nhưng
			# không thể đẩy/kéo Player (Player cũng dùng mask world layer 1).
			# InteractionArea riêng vẫn ở layer 2 để raycast/[E] hoạt động.
			inst.collision_layer = 2
			inst.collision_mask = 1
			if inst.has_node("InteractionArea"):
				var area: Area2D = inst.get_node("InteractionArea")
				area.monitoring = true
				area.monitorable = true
			if visible_scene is CanvasItem:
				(visible_scene as CanvasItem).visible = true
				(visible_scene as CanvasItem).modulate = Color.WHITE
			continue
		# Only reparent from background persistent scenes, never from active Player scene.
		var parent: Node = inst.get_parent()
		if parent == null:
			continue
		var is_background: bool = (parent.name.begins_with("NPCWorld_") or parent.name == "PersistentNPCScenes")
		if not is_background:
			# NPC is already in an active scene; do not steal it from there.
			continue
		if parent.name == "PersistentNPCScenes":
			var background_map: Node = parent
			if background_map is CanvasItem:
				(background_map as CanvasItem).visible = false
		var saved_global_position: Vector2 = inst.global_position
		var old_parent: Node = inst.get_parent()
		if old_parent != null:
			old_parent.remove_child(inst)
		# The NPC must become a direct child of the active Player scene. Do not
		# leave it under a hidden NPCWorld root after a schedule handoff.
		visible_scene.add_child(inst)
		inst.set_meta("world_scene_path", visible_path)
		# Preserve the portal arrival position. NPC physics must walk toward the
		# schedule target; rehome must never teleport it to that target.
		inst.global_position = saved_global_position
		inst.visible = true
		inst.modulate = Color.WHITE
		# Giữ layer body NPC tách khỏi Player sau khi rehome vào map đang mở.
		inst.collision_layer = 2
		inst.collision_mask = 1
		if inst.has_node("InteractionArea"):
			var interaction_area: Area2D = inst.get_node("InteractionArea")
			interaction_area.monitoring = true
			interaction_area.monitorable = true
		if visible_scene is CanvasItem:
			(visible_scene as CanvasItem).visible = true
			(visible_scene as CanvasItem).modulate = Color.WHITE
		entry["spawned"] = true
		entry["current_scene"] = visible_path
		# Never reapply the schedule during rehome. At 20:00 the active step
		# starts Farm -> House transit; applying it here would snap the NPC to the
		# sleep target and make the next scene appear at the bed.
		# A portal handoff has already established the NPC's arrival position.
		# Never apply a sleep/bed schedule position during scene rehome.
		if inst.has_method("get_route_progress"):
			var visible_progress: Variant = inst.call("get_route_progress")
			if visible_progress is Dictionary and str(visible_progress.get("route_id", "")) != "":
				continue
		# Player scene is the only visible world after rehome.
		if visible_scene is CanvasItem:
			(visible_scene as CanvasItem).visible = true


func _on_hour_elapsed(_hour: int) -> void:
	# Mỗi giờ refresh schedule; movement/handoff do NPC physics xử lý.
	tick_all_schedules(GameState.current_time)
	_reapply_schedules_to_persistent_npcs()


func reset_npcs_for_sleep() -> void:
	# Ngủ là checkpoint cưỡng chế: mọi NPC phải kết thúc ngày tại nhà/giường.
	for npc_id: String in _npcs:
		var raw: Variant = _npcs[npc_id].get("instance", null)
		if raw == null or not is_instance_valid(raw) or npc_id != "neighbor":
			continue
		var npc: Node2D = raw as Node2D
		var house_scene := "res://scenes/maps/marcus_house_map.tscn"
		var manager: Node = get_node_or_null("/root/SceneManager")
		if manager != null and manager.has_method("handoff_persistent_npc"):
			if npc.get_parent() != null:
				npc.get_parent().remove_child(npc)
			manager.call("handoff_persistent_npc", npc, house_scene, "")
		if npc.get_parent() != null:
			npc.global_position = Vector2(80, 50)
		if npc.has_method("clear_route"):
			npc.call("clear_route")
		if npc.has_method("stop_walking"):
			npc.call("stop_walking")
		npc.set_meta("world_scene_path", house_scene)
		_npcs[npc_id]["current_scene"] = house_scene
		_npcs[npc_id]["spawned"] = true

func _on_day_changed(_new_day: int) -> void:
	# Rebuild dynamic schedules (Day 1 intro state) before ticking new day.
	for npc_id: String in _npcs:
		var raw: Variant = _npcs[npc_id].get("instance", null)
		if raw != null and is_instance_valid(raw) and raw.has_method("_build_default_schedule"):
			raw.call("_build_default_schedule")
		if raw != null and is_instance_valid(raw) and raw.has_method("apply_current_step"):
			raw.call("apply_current_step")
	tick_all_schedules(GameState.current_time)
	_reapply_schedules_to_persistent_npcs()

func _reapply_schedules_to_persistent_npcs() -> void:
	for npc_id: String in _npcs:
		var entry: Dictionary = _npcs[npc_id]
		var raw: Variant = entry.get("instance", null)
		if raw != null and is_instance_valid(raw) and raw.has_method("apply_current_step"):
			raw.call("apply_current_step")


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
		if inst.has_method("get_route_progress"):
			entry["route_progress"] = inst.call("get_route_progress")
			var progress: Variant = entry["route_progress"]
			if progress is Dictionary:
				entry["route_index"] = int(progress.get("waypoint_index", -1))
		entry["last_simulated_day"] = GameState.current_day
		entry["last_simulated_time"] = current_time
	# Time simulation must never reparent NPCs based on Player's current scene.
	# Rehome is performed only by the explicit scene_changed lifecycle callback.


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

func export_runtime_state() -> Dictionary:
	var result: Dictionary = {}
	for npc_id: String in _npcs:
		var entry: Dictionary = _npcs[npc_id]
		var inst: Variant = entry.get("instance", null)
		if inst != null and is_instance_valid(inst) and inst.has_method("get_runtime_state"):
			result[npc_id] = inst.call("get_runtime_state")
		else:
			result[npc_id] = {"route": entry.get("route_progress", {})}
		if result[npc_id] is Dictionary:
			result[npc_id]["last_simulated_day"] = entry.get("last_simulated_day", GameState.current_day)
			result[npc_id]["last_simulated_time"] = entry.get("last_simulated_time", GameState.current_time)
	return result

func import_runtime_state(data: Dictionary) -> void:
	for npc_id: String in data:
		if not _npcs.has(npc_id):
			continue
		var entry: Dictionary = _npcs[npc_id]
		var raw_state: Variant = data[npc_id]
		if raw_state is not Dictionary:
			continue
		var inst: Variant = entry.get("instance", null)
		if inst != null and is_instance_valid(inst) and inst.has_method("restore_runtime_state"):
			inst.call("restore_runtime_state", raw_state)
		var route_state: Variant = raw_state.get("route", {})
		entry["route_progress"] = route_state if route_state is Dictionary else {}
		entry["last_simulated_day"] = int(raw_state.get("last_simulated_day", GameState.current_day))
		entry["last_simulated_time"] = float(raw_state.get("last_simulated_time", GameState.current_time))
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


func _get_npc_host_scene_path(npc: Node2D) -> String:
	if npc == null or not is_instance_valid(npc):
		return ""
	if npc.has_meta("world_scene_path"):
		return str(npc.get_meta("world_scene_path"))
	var current: Node = npc
	while current.get_parent() != null:
		current = current.get_parent()
		if current.has_meta("world_scene_path"):
			return str(current.get_meta("world_scene_path"))
		if current.scene_file_path != "" and not current.name.begins_with("NPCWorld_"):
			return current.scene_file_path
	return ""

func _get_current_scene_path() -> String:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return ""
	return tree.current_scene.scene_file_path
