extends "res://scripts/npc/npc.gd"
# =============================================================================
# NEIGHBOR NPC (Marcus)
# =============================================================================
# NPC "Old Marcus" — hàng xóm sống ở khu marcus_farm_map (bên phải town).
#
# Thông số được load từ ConfigManager (resources/config/npc_config.json)
#
# NPCManager quản lý 1 instance duy nhất của Marcus. Lịch trình quyết định:
#   - Marcus ở scene nào theo từng giờ.
#   - Marcus đứng ở đâu trong sceneaaa đó.
#   - Marcus đang làm gì (state + action).
#
# LỊCH TRÌNH NGÀY 1 (DAY 1 INTRO FLOW):a
#   Trước khi player rời nhà lần đầu (sáng 6:00+):
#     06:00-… marcus_at_player_house_map (đứng TRƯỚC cửa nhà PLAYER đợi
#     player ra khỏi nhà → auto-cutscene dialogue "neighbor").
#
#   Player rời nhà TRƯỚC 11:00 → auto-cutscene → Marcus rebuild schedule:
#     - Chuyển sang town từ lúc gặp → 11:00 (Marcus đợi player ở town).
#     - 11:00+ → về marcus_farm_map (theo schedule bình thường).
#
#   Player rời nhà SAU 11:00 → auto-cutscene → Marcus KHÔNG đổi scene vì
#     schedule hiện tại (>= 11:00) đã là marcus_farm_map. Marcus theo schedule
#     bình thường luôn.
#
#   Sau khi gặp player (marcus_met_day1 = true):
#     06:00-21:59 marcus_farm_map (sinh hoạt quanh farm)
#     22:00-05:59 marcus_house_map (ngủ trong nhà)
#
# NGÀY >= 2: schedule luôn là marcus_farm_map / marcus_house_map, không còn
# logic chờ ở nhà player.
#
# Tương tác:
#   - day == 1, lần đầu: auto-trigger dialogue khi player rời nhà (cutscene).
#     Cũng có thể interact bằng [E] nếu Marcus vẫn đứng gần player.
#   - day >= 2: chọn dialogue dựa trên quest state (như cũ).
# =============================================================================

# Vị trí mặc định (sẽ được load từ ConfigManager)
var home_position: Vector2 = Vector2(375, 200)
var farm_work_position: Vector2 = Vector2(160, 200)
var open_area_position: Vector2 = Vector2(250, 170)
var house_sleep_position: Vector2 = Vector2(80, 50)
var town_position: Vector2 = Vector2(430, 90)
var player_house_door_position: Vector2 = Vector2(85, 200)
var marcus_farm_entry_position: Vector2 = Vector2(40, 200)

# Scene paths (load from ConfigManager)
var SCENE_MARCUS_FARM: String = "res://scenes/maps/marcus_farm_map.tscn"
var SCENE_MARCUS_HOUSE: String = "res://scenes/maps/marcus_house_map.tscn"
var SCENE_TOWN: String = "res://scenes/maps/town_map.tscn"
var SCENE_PLAYER_FARM: String = "res://scenes/maps/farm_map.tscn"
var SCENE_INSIDE_HOUSE: String = "res://scenes/maps/inside_house_map.tscn"

# Giờ cutoff cho day 1 intro (load from ConfigManager)
var _intro_deadline_hour: float = 11.0

# Cờ nội bộ — Marcus đã hoàn thành intro day 1 chưa. Sau khi intro → set
# flag marcus_met_day1 và rebuild schedule. Lưu local để không gọi rebuild lặp.
var has_met_player_day1: bool = false

# Flag dùng để suppress dialogue khi cutscene KHÔNG nên trigger (ví dụ player
# reload scene hoặc test). Set false để tắt auto-cutscene (ví dụ debug).
@export var enable_auto_intro: bool = true


func _ready() -> void:
	# Load config from ConfigManager
	_load_config_from_manager()

	# Đồng bộ has_met_player_day1 từ GameState flag (để handle load save)
	has_met_player_day1 = GameState.get_flag("neighbor_met_day1", false)
	
	# move_speed lấy từ base npc.gd (mặc định 85 px/s).
	# Gọi _ready của base npc.gd → add_to_group + schedule build.
	super._ready()
	# Subscribe SceneManager signals để auto-trigger cutscene.
	var sm := _get_scene_manager()
	if sm != null:
		if not sm.scene_changing.is_connected(_on_scene_changing_marcus):
			sm.scene_changing.connect(_on_scene_changing_marcus)
		if not sm.scene_changed.is_connected(_on_scene_changed_marcus):
			sm.scene_changed.connect(_on_scene_changed_marcus)


func _load_config_from_manager() -> void:
	var cm := _get_config_manager()
	if cm == null:
		push_warning("[Neighbor] ConfigManager not found, using defaults")
		return
	
	# Load scene paths - CHỈ ghi đè nếu config có giá trị (không empty)
	var scene_marcus_farm = cm.get_scene_path("marcus_farm")
	var scene_marcus_house = cm.get_scene_path("marcus_house")
	var scene_town = cm.get_scene_path("town")
	var scene_player_farm = cm.get_scene_path("player_farm")
	var scene_inside_house = cm.get_scene_path("inside_house")
	
	if scene_marcus_farm != "": SCENE_MARCUS_FARM = scene_marcus_farm
	if scene_marcus_house != "": SCENE_MARCUS_HOUSE = scene_marcus_house
	if scene_town != "": SCENE_TOWN = scene_town
	if scene_player_farm != "": SCENE_PLAYER_FARM = scene_player_farm
	if scene_inside_house != "": SCENE_INSIDE_HOUSE = scene_inside_house
	
	# Load neighbor positions - CHỈ ghi đè nếu config có giá trị
	var cfg_home = cm.get_npc_position("neighbor", "home_position")
	var cfg_farm_work = cm.get_npc_position("neighbor", "farm_work_position")
	var cfg_house_sleep = cm.get_npc_position("neighbor", "house_sleep_position")
	var cfg_town = cm.get_npc_position("neighbor", "town_position")
	var cfg_player_door = cm.get_npc_position("neighbor", "player_house_door_position")
	var cfg_marcus_entry = cm.get_npc_position("neighbor", "marcus_farm_entry_position")
	
	if cfg_home != Vector2.ZERO: home_position = cfg_home
	if cfg_farm_work != Vector2.ZERO: farm_work_position = cfg_farm_work
	if cfg_house_sleep != Vector2.ZERO: house_sleep_position = cfg_house_sleep
	if cfg_town != Vector2.ZERO: town_position = cfg_town
	if cfg_player_door != Vector2.ZERO: player_house_door_position = cfg_player_door
	if cfg_marcus_entry != Vector2.ZERO: marcus_farm_entry_position = cfg_marcus_entry
	
	# Load intro deadline hour
	_intro_deadline_hour = cm.get_intro_deadline_hour()
	
	print("[Neighbor] Config loaded - SCENE_PLAYER_FARM: '%s'" % SCENE_PLAYER_FARM)
	
	# Rebuild schedule với config đã load
	_build_default_schedule()


func _get_config_manager() -> Node:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("ConfigManager")


# Schedule được build linh hoạt dựa trên 3 trạng thái:
#   - day == 1 + CHƯA gặp player (flag neighbor_met_day1 = false) → _schedule_waiting_at_player_house (đứng
#     trước cửa nhà player).
#   - day == 1 + ĐÃ gặp + cutscene chuyển sang town (flag marcus_at_town_post_intro = true) → _schedule_after_intro_to_town (town → 11:00, farm sau 11:00).
#   - Còn lại (day >= 2, day 1 sau 11:00, day 1 đã gặp sau 11:00) → _schedule_in_farm (sinh hoạt quanh farm).
func _build_default_schedule() -> void:
	var schedule_name: String = "daily_from_house"
	if GameState.current_day == 1 and not GameState.get_flag("neighbor_met_day1", false):
		schedule_name = "waiting_at_player_house"
	elif GameState.current_day == 1 and GameState.get_flag("marcus_at_town_post_intro", false):
		schedule_name = "after_intro_to_town"
	elif GameState.current_day >= 2:
		# Dùng cùng daily route xuyên suốt mọi ngày; không chuyển sang
		# schedule in_farm rút gọn vì nó thiếu các bước portal Farm/Town.
		schedule_name = "daily_from_house"
	var configured_schedule: Array = ConfigManager.get_npc_daily_schedule(npc_id, schedule_name)
	if not configured_schedule.is_empty():
		schedule = _convert_configured_schedule(configured_schedule)
		return
	# Kiểm tra flag trong GameState (persistent) thay vì biến local
	# để đảm bảo schedule đúng khi load save
	if GameState.current_day == 1 and not GameState.get_flag("neighbor_met_day1", false):
		_schedule_waiting_at_player_house()
		return
	if GameState.current_day == 1 and GameState.get_flag("marcus_at_town_post_intro", false):
		_schedule_after_intro_to_town()
		return
	# Từ ngày 2 trở đi dùng cùng daily route liên tục, bắt đầu từ
	# Marcus House sau khi ngủ qua đêm rồi đi ra bằng portal.
	_schedule_daily_from_house()


func _schedule_daily_from_house() -> void:
	schedule = [
		# Bản fallback này phải khớp npc_schedule_config.json; JSON là nguồn cấu hình chính.
		{"time": 6.0, "state": NPCState.WALKING, "action": "leave_house", "scene": SCENE_MARCUS_HOUSE, "pos": Vector2(420, 146), "route_id": "marcus_house_to_farm"},
		{"time": 6.1, "state": NPCState.IDLE, "action": "stay_at_marcus_farm", "scene": SCENE_MARCUS_FARM, "pos": open_area_position},
		{"time": 8.0, "state": NPCState.WALKING, "action": "visit_town", "scene": SCENE_MARCUS_FARM, "pos": Vector2(20, 135), "route_id": "marcus_farm_to_town"},
		{"time": 8.2, "state": NPCState.WALKING, "action": "walk_away_from_town_portal", "scene": SCENE_TOWN, "pos": Vector2(430, 110)},
		{"time": 8.3, "state": NPCState.IDLE, "action": "walk_in_town", "scene": SCENE_TOWN, "pos": Vector2(430, 110)},
		{"time": 10.0, "state": NPCState.WALKING, "action": "visit_shop", "scene": SCENE_TOWN, "pos": Vector2(95, 105), "route_id": "town_to_shop"},
		{"time": 11.0, "state": NPCState.WALKING, "action": "walk_away_from_shop_portal", "scene": "res://scenes/maps/inside_shop_map.tscn", "pos": Vector2(210, 200)},
		{"time": 11.1, "state": NPCState.IDLE, "action": "shop_break", "scene": "res://scenes/maps/inside_shop_map.tscn", "pos": Vector2(210, 200)},
		{"time": 12.0, "state": NPCState.WALKING, "action": "leave_shop", "scene": "res://scenes/maps/inside_shop_map.tscn", "pos": Vector2(20, 135), "route_id": "shop_to_town"},
		{"time": 12.2, "state": NPCState.WALKING, "action": "leave_town", "scene": SCENE_TOWN, "pos": town_position, "route_id": "town_to_marcus_farm"},
		{"time": 13.2, "state": NPCState.WORKING, "action": "work", "scene": SCENE_MARCUS_FARM, "pos": open_area_position},
		{"time": 17.0, "state": NPCState.WALKING, "action": "go_home", "scene": SCENE_MARCUS_FARM, "pos": home_position},
		{"time": 20.0, "state": NPCState.WALKING, "action": "go_to_bed", "scene": SCENE_MARCUS_HOUSE, "pos": house_sleep_position, "route_id": "marcus_farm_to_house"},
		{"time": 22.0, "state": NPCState.SLEEPING, "action": "sleep", "scene": SCENE_MARCUS_HOUSE, "pos": house_sleep_position},
	]


# Marcus đợi trước cửa nhà player suốt ngày (1 step tĩnh, time = 0 để luôn
# active). NPCManager sẽ attach Marcus vào farm_map (PLAYER's farm, không
# phải marcus_farm_map) và NPC đứng ở player_house_door_position.
func _schedule_waiting_at_player_house() -> void:
	schedule = [
		{"time": 0.0, "state": NPCState.WAKING, "action": "wait_at_player_house", "scene": SCENE_PLAYER_FARM, "pos": player_house_door_position},
	]


# Schedule NGAY SAU intro (chỉ trigger khi gặp player trước _intro_deadline_hour).
# Marcus đứng ở town cho tới 11:00, sau 11:00 trở về marcus_farm_map.
# Lưu ý: step ở 11:00 chuyển từ town → marcus_farm (vị trí marcus_farm_entry)
# để Marcus "đi bộ" từ town về farm thay vì teleport.
func _schedule_after_intro_to_town() -> void:
	schedule = [
		# Sau intro, Marcus phải đến Town và ở đó từ 08:00 đến 12:00.
		{"time": 7.0, "state": NPCState.WALKING, "action": "leave_player_farm", "scene": SCENE_PLAYER_FARM, "pos": Vector2(790, 300), "route_id": "farm_to_town"},
		{"time": 7.1, "state": NPCState.WALKING, "action": "arrive_in_town", "scene": SCENE_TOWN, "pos": Vector2(430, 110), "route_id": "farm_to_town"},
		# 12:00: rời Town qua portal và đi về Marcus Farm.
		{"time": 12.0, "state": NPCState.WALKING, "action": "return_to_marcus_farm", "scene": SCENE_TOWN, "pos": town_position, "route_id": "town_to_marcus_farm"},
		# 12:00–20:00: ở Marcus Farm.
		{"time": 12.1, "state": NPCState.WALKING, "action": "stay_at_marcus_farm", "scene": SCENE_MARCUS_FARM, "pos": home_position},
		{"time": 20.0, "state": NPCState.WALKING, "action": "go_to_bed", "scene": SCENE_MARCUS_HOUSE, "pos": house_sleep_position, "route_id": "marcus_farm_to_house"},
		# 22:00–06:00: ngủ trong Marcus House.
		{"time": 22.0, "state": NPCState.SLEEPING, "action": "sleep", "scene": SCENE_MARCUS_HOUSE, "pos": house_sleep_position},
	]


func _convert_configured_schedule(configured: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in configured:
		if entry is Dictionary:
			var step: Dictionary = {
				"time": float(entry.get("time", 0.0)),
				"state": _parse_state(str(entry.get("state", "idle"))),
				"action": str(entry.get("action", "")),
				"scene": str(entry.get("scene", SCENE_MARCUS_FARM)),
				"pos": _parse_position(entry.get("pos", {})),
				"route_id": str(entry.get("route_id", ""))
			}
			result.append(step)
	return result

func _parse_state(state_name: String) -> int:
	match state_name.to_lower():
		"idle": return NPCState.IDLE
		"walking": return NPCState.WALKING
		"working": return NPCState.WORKING
		"sleeping": return NPCState.SLEEPING
		"waking": return NPCState.WAKING
		_: return NPCState.IDLE

func _parse_position(pos_data: Variant) -> Vector2:
	if pos_data is Dictionary:
		return Vector2(float(pos_data.get("x", 0.0)), float(pos_data.get("y", 0.0)))
	return Vector2.ZERO


func _schedule_in_farm() -> void:
	schedule = [
		{"time": 6.0,  "state": NPCState.WAKING,   "action": "wake_up",        "scene": SCENE_MARCUS_FARM, "pos": home_position},
		{"time": 8.0,  "state": NPCState.WALKING,  "action": "go_to_farm",     "scene": SCENE_MARCUS_FARM, "pos": farm_work_position},
		{"time": 11.0, "state": NPCState.IDLE,     "action": "go_home_early",  "scene": SCENE_MARCUS_FARM, "pos": home_position},
		{"time": 12.0, "state": NPCState.WORKING,  "action": "tend_garden",    "scene": SCENE_MARCUS_FARM, "pos": farm_work_position},
		{"time": 17.0, "state": NPCState.WALKING,  "action": "go_home",        "scene": SCENE_MARCUS_FARM, "pos": home_position},
		{"time": 20.0, "state": NPCState.IDLE,     "action": "chat_door",      "scene": SCENE_MARCUS_FARM, "pos": home_position},
		{"time": 22.0, "state": NPCState.SLEEPING, "action": "sleep",          "scene": SCENE_MARCUS_HOUSE, "pos": house_sleep_position},
	]


func _schedule_in_town() -> void:
	schedule = [
		{"time": 6.0,  "state": NPCState.WAKING,   "action": "wake_up",        "scene": SCENE_TOWN, "pos": town_position},
		{"time": 8.0,  "state": NPCState.IDLE,     "action": "chat_in_town",   "scene": SCENE_TOWN, "pos": town_position},
		{"time": 12.0, "state": NPCState.IDLE,     "action": "lunch_break",    "scene": SCENE_TOWN, "pos": town_position},
		{"time": 13.0, "state": NPCState.IDLE,     "action": "chat_in_town",   "scene": SCENE_TOWN, "pos": town_position},
		{"time": 18.0, "state": NPCState.IDLE,     "action": "go_home_evening","scene": SCENE_TOWN, "pos": town_position},
		{"time": 20.0, "state": NPCState.IDLE,     "action": "chat_door",      "scene": SCENE_TOWN, "pos": town_position},
		{"time": 22.0, "state": NPCState.SLEEPING, "action": "sleep",          "scene": SCENE_MARCUS_HOUSE, "pos": house_sleep_position},
	]


# Override `interact` để chọn dialogue phù hợp với ngày + quest state.
# Day 1 lần đầu: dùng dialogue "neighbor" intro (giống cutscene logic —
# không auto-walk, chỉ play dialogue rồi rebuild schedule).
func interact(player: Node) -> void:
	print("[Neighbor] interact() called, is_interacting=%s" % is_interacting)
	if is_interacting:
		return

	# Cancel cinematic intro if player presses E manually
	GameState.cinematic_intro_state = GameState.CINEMATIC_NONE

	# Lock player movement khi dialogue bắt đầu
	GameState.player_movement_locked = true

	stop_walking()
	is_interacting = true
	talk_count += 1
	npc_dialogue_started.emit()
	print("[NPC] %s interacted with player (talk count: %d, day: %d)." % [npc_name, talk_count, GameState.current_day])

	var chosen_id: String = _pick_dialogue_id()
	print("[Neighbor] Chosen dialogue: %s" % chosen_id)
	if not DialogueManager.dialogue_ended.is_connected(_on_dm_ended):
		DialogueManager.dialogue_ended.connect(_on_dm_ended, CONNECT_ONE_SHOT)
	DialogueManager.start_dialogue(chosen_id, npc_name, npc_id)
	if not DialogueManager.is_active:
		is_interacting = false
		GameState.player_movement_locked = false
		# start_dialogue() có thể thất bại vì file/UI; tránh giữ one-shot cũ
		# cho lần nói chuyện kế tiếp.
		if DialogueManager.dialogue_ended.is_connected(_on_dm_ended):
			DialogueManager.dialogue_ended.disconnect(_on_dm_ended)


# Callback khi dialogue kết thúc. Day 1 lần đầu:
#   - Nếu current_time < _intro_deadline_hour (11:00): Marcus chuyển sang town
#     cho tới 11:00, sau 11:00 về farm (schedule _schedule_after_intro_to_town).
#   - Nếu current_time >= 11:00: Marcus giữ _schedule_in_farm (đang ở farm
#     theo schedule, không teleport vì step hiện tại đã khớp farm).
func _on_dm_ended() -> void:
	is_interacting = false
	npc_dialogue_finished.emit()

	# DialogueManager đã giải phóng lock cutscene sau khi dialogue kết thúc.
	# Giữ fallback này cho trường hợp dialogue bị đóng từ UI ngoài luồng.
	GameState.player_movement_locked = false
	GameState.cinematic_intro_state = GameState.CINEMATIC_NONE

	if GameState.current_day <= 1 and not has_met_player_day1:
		has_met_player_day1 = true
		GameState.set_flag("neighbor_met_day1", true)
		var ct := GameState.current_time
		if ct < _intro_deadline_hour:
			# Trước 11:00 → Marcus chuyển sang town (chờ player ở town), sau
			# 11:00 về farm.
			GameState.set_flag("marcus_at_town_post_intro", true)
			_schedule_after_intro_to_town()
			# Cutscene có thể kết thúc muộn khi Marcus đã được chuyển sang
			# marcus_farm_map. Khi đó farm_to_town bắt đầu ở farm_map và khiến
			# NPC chạy thẳng về (790,300), thường là góc dưới phải.
			# Luôn dùng route farm_to_town cho đoạn 08:00–11:00 của ngày 1,
			# giống trường hợp skip nhanh đã được kiểm chứng ổn định.
			for step: Dictionary in schedule:
				if str(step.get("route_id", "")) == "marcus_farm_to_town":
					step["route_id"] = "farm_to_town"
			_apply_schedule_now()
			print("[NPC] %s: intro complete before %.1f → route to town, then normal farm schedule." % [npc_name, _intro_deadline_hour])
		else:
			# Sau 11:00 → Marcus đã đang ở farm theo schedule, giữ nguyên.
			GameState.set_flag("marcus_at_town_post_intro", false)
			_schedule_in_farm()
			print("[NPC] %s: intro complete after %.1f → staying at marcus_farm per normal schedule." % [npc_name, _intro_deadline_hour])
		_sync_now()


# =============================================================================
# AUTO-TRIGGER CUTSCENE — subscribe SceneManager signals
# =============================================================================
# Khi player rời inside_house_map (scene_changing) → set _was_inside_house.
# Khi scene_changed emit → defer check trigger cutscene (chỉ trigger khi
# player vừa rời nhà VÀ đến farm_map + day=1 chưa gặp).
#
# KHÔNG hook vào _on_attached_to_scene nữa vì scene có thể reuse/swap chứ
# không phải attach mới — signal scene_changed là điểm chung duy nhất.
# =============================================================================
var _intro_attach_handled: bool = false
var _was_inside_house: bool = false


# scene_changing — track player vừa rời inside_house.
func _on_scene_changing_marcus(old_path: String, _new_path: String) -> void:
	print("[Neighbor] _on_scene_changing_marcus: old=%s, new=%s" % [old_path, _new_path])
	if old_path == SCENE_INSIDE_HOUSE:
		_was_inside_house = true
		print("[Neighbor] _was_inside_house set to TRUE")


# scene_changed — check trigger cutscene (1 frame sau để NPC sync ổn định).
func _on_scene_changed_marcus(_scene_path: String) -> void:
	print("[Neighbor] _on_scene_changed_marcus called for: %s" % _scene_path)
	# Check GameState flag nếu signal không hoạt động
	if GameState.just_left_inside_house:
		print("[Neighbor] Detected via GameState.just_left_inside_house flag")
		_was_inside_house = true

	# Gọi sync deferred để đảm bảo NPCManager đã sync trước
	# Sau đó mới check trigger cutscene
	call_deferred("_delayed_intro_check")


# Được gọi deferred sau _on_scene_changed_marcus để đảm bảo NPCManager đã sync
func _delayed_intro_check() -> void:
	# NPCManager already performs the authoritative scene sync on scene_changed.
	# A second sync here re-runs the 20:00 go_to_bed step and can reattach Marcus
	# to the old Farm state while the Player is entering Marcus House.
	_check_intro_trigger()


# Thực sự check + trigger cutscene với cinematic intro.
func _check_intro_trigger() -> void:
	# Reset flag ngay để tránh trigger lại
	GameState.just_left_inside_house = false

	if not _should_trigger_intro_cutscene():
		return
	# Khóa ngay khi trigger, trước delay/auto-walk/dialogue.
	_intro_attach_handled = true
	_was_inside_house = false
	print("[NPC] %s: starting cinematic intro (player left house)." % npc_name)

	# Lock player movement ngay lập tức
	GameState.player_movement_locked = true

	# Snap NPC về đúng pos trước cửa nhà player.
	position = player_house_door_position
	_target_pos = position
	stop_walking()

	# Tính vị trí cho player đứng bên trái NPC (từ ConfigManager)
	var cm := _get_config_manager()
	var offset: Vector2 = Vector2(-50, 0)
	if cm != null and cm.has_method("get_cinematic_player_offset"):
		offset = cm.get_cinematic_player_offset()
	var player_target_pos: Vector2 = position + offset
	print("[NPC] Player will walk to: %s (offset: %s)" % [str(player_target_pos), str(offset)])

	# Delay từ ConfigManager
	var delay: float = 1.5
	if cm != null and cm.has_method("get_cinematic_delay"):
		delay = cm.get_cinematic_delay()
	await get_tree().create_timer(delay).timeout

	# Kiểm tra lại điều kiện (player có thể đã làm gì đó)
	if GameState.current_day != 1 or has_met_player_day1 or DialogueManager.is_active:
		print("[NPC] Intro cancelled - conditions changed")
		GameState.player_movement_locked = false
		GameState.cinematic_intro_state = GameState.CINEMATIC_NONE
		return

	# Bắt đầu cinematic walk
	var player: Node = get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("start_cinematic_intro"):
		player.start_cinematic_intro(player_target_pos)
		player.cinematic_walk_complete.connect(_on_player_reached_npc_for_intro)
		print("[NPC] Player cinematic walk started")
	else:
		# Fallback: không tìm thấy player, trigger dialogue ngay
		_start_intro_dialogue()


# Called when player reaches NPC position during cinematic intro
func _on_player_reached_npc_for_intro() -> void:
	print("[NPC] Player reached NPC position, starting dialogue")
	var player: Node = get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("cancel_cinematic_intro"):
		player.cancel_cinematic_intro()
	if player != null:
		player.cinematic_walk_complete.disconnect(_on_player_reached_npc_for_intro)

	# Bắt đầu dialogue
	_start_intro_dialogue()


# Bắt đầu dialogue intro
func _start_intro_dialogue() -> void:
	is_interacting = true
	talk_count += 1
	npc_dialogue_started.emit()
	GameState.cinematic_intro_state = GameState.CINEMATIC_WAITING_DIALOGUE
	if not DialogueManager.dialogue_ended.is_connected(_on_dm_ended):
		DialogueManager.dialogue_ended.connect(_on_dm_ended, CONNECT_ONE_SHOT)
	DialogueManager.start_dialogue("neighbor", npc_name, npc_id)
	if not DialogueManager.is_active:
		# Nếu không mở được JSON/UI, không để Player bị khóa vĩnh viễn.
		is_interacting = false
		GameState.cinematic_intro_state = GameState.CINEMATIC_NONE
		GameState.player_movement_locked = false
		if DialogueManager.dialogue_ended.is_connected(_on_dm_ended):
			DialogueManager.dialogue_ended.disconnect(_on_dm_ended)


# Check điều kiện trigger cutscene (gọi ngay + gọi lại sau defer).
func _should_trigger_intro_cutscene() -> bool:
	# Check NPC is valid and in tree
	if not is_inside_tree():
		return false
	if not is_instance_valid(self):
		return false

	if not enable_auto_intro:
		return false
	if GameState.current_day != 1:
		return false
	if has_met_player_day1:
		return false
	if GameState.get_flag("neighbor_met_day1", false):
		return false
	if DialogueManager != null and DialogueManager.is_active:
		return false
	if is_interacting:
		return false
	if _intro_attach_handled:
		return false
	# Schedule phải là waiting.
	if schedule.is_empty():
		return false
	if schedule[0].get("action", "") != "wait_at_player_house":
		return false
	# Player phải vừa rời inside_house_map (không phải teleport từ scene khác).
	if not _was_inside_house and not GameState.just_left_inside_house:
		_was_inside_house = false  # Reset nếu không phải vừa rời nhà
		return false
	# Player hiện đang ở farm_map.
	var scene_tree := get_tree()
	if scene_tree == null or scene_tree.current_scene == null:
		return false
	if scene_tree.current_scene.scene_file_path != SCENE_PLAYER_FARM:
		_was_inside_house = false  # Reset nếu không đúng scene
		return false
	return true


func _apply_schedule_now() -> void:
	# Bỏ toàn bộ route/cache cũ sau cutscene. Nếu giữ route của schedule trước,
	# lúc intro kết thúc muộn NPC có thể lấy waypoint của marcus_farm_map và đi
	# chéo sai hướng thay vì rời farm_map của người chơi.
	_last_schedule_time = -1.0
	_schedule_target_scene = ""
	_arrived_route_id = ""
	_completed_route_id = ""
	route_progress.clear()
	clear_route()
	tick_schedule(GameState.current_time)

func _sync_now() -> void:
	var mgr := _get_npc_manager()
	if mgr != null and mgr.has_method("sync_all"):
		mgr.call("sync_all")


func _get_npc_manager() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("NPCManager")


func _get_scene_manager() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("SceneManager")


func _pick_dialogue_id() -> String:
	print("[Neighbor] _pick_dialogue_id() called, day=%d, npc_id=%s" % [GameState.current_day, npc_id])

	# Kiểm tra quest active trước mọi nhánh thoại ngày 1/ngày 2.
	# Không để talk_count hoặc thoại intro che mất quest đã nhận.
	var delivery_quest: Dictionary = QuestSystem.get_active_delivery_quest_for_npc(npc_id)
	var has_active_delivery: bool = not delivery_quest.is_empty()
	if GameState.current_day <= 1 and talk_count <= 1 and not has_active_delivery:
		return "neighbor"

	print("[Neighbor] delivery_quest is_empty=%s npc_id=%s" % [delivery_quest.is_empty(), npc_id])
	if has_active_delivery:
		var quest_id: String = str(delivery_quest.get("id", ""))
		var ready: bool = QuestSystem.can_complete_delivery_quest(quest_id)
		print("[Neighbor] Quest %s active; ready_to_deliver=%s" % [quest_id, ready])
		if ready:
			return "neighbor_delivery"
		return "neighbor_still_need"

	var available: Array = QuestSystem.get_available_quests_for_npc(npc_id)
	if not available.is_empty():
		return "neighbor_day2_plus"

	# Kiểm tra bảng tin có quest hôm nay không (CHỈ từ day 2 trở lên)
	if GameState.current_day >= 2 and QuestSystem.has_quests_today(npc_id):
		print("[Neighbor] Board has quests today → neighbor_day2_plus")
		return "neighbor_day2_plus"

	# Dialogue idle theo thời gian trong ngày
	return _pick_idle_by_time()


func _pick_idle_by_time() -> String:
	# Random idle dialogue dựa trên giờ hiện tại
	# Mỗi file JSON idle chứa DUY NHẤT 1 dòng thoại → tránh NPC đọc hết tất cả
	# các câu khi player tương tác. Chọn ngẫu nhiên 1 file trong mốc giờ.
	#
	# Sáng: 6:00 - 11:59
	# Chiều: 12:00 - 17:59
	# Tối: 18:00 - 21:59
	var current_time: float = GameState.current_time
	var wrapped_hour: float = fposmod(current_time, 24.0)

	var dialogues: Array = []
	if wrapped_hour >= 6.0 and wrapped_hour < 12.0:
		# Sáng
		dialogues = [
			"neighbor_idle_morning",
			"neighbor_idle_morning_2",
			"neighbor_idle_morning_3",
			"neighbor_idle"
		]
	elif wrapped_hour >= 12.0 and wrapped_hour < 18.0:
		# Chiều
		dialogues = [
			"neighbor_idle_afternoon",
			"neighbor_idle_afternoon_2",
			"neighbor_idle_afternoon_3",
			"neighbor_idle"
		]
	else:
		# Tối (18:00 - 21:59) — fallback khi giờ ngoài khoảng
		dialogues = [
			"neighbor_idle_evening",
			"neighbor_idle_evening_2",
			"neighbor_idle_evening_3",
			"neighbor_idle"
		]

	return dialogues[randi() % dialogues.size()]


# Lấy step hiện tại + apply cho NPC. Base class đã có `apply_current_step()` —
# chỉ gọi nó. (KHÔNG cần duplicate logic.)
func _apply_current_step_state() -> void:
	apply_current_step()
