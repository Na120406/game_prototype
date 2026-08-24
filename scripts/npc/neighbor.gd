extends "res://scripts/npc/npc.gd"
# =============================================================================
# NEIGHBOR NPC (Marcus)
# =============================================================================
# NPC "Old Marcus" — hàng xóm sống ở khu marcus_farm_map (bên phải town).
#
# NPCManager quản lý 1 instance duy nhất của Marcus. Lịch trình quyết định:
#   - Marcus ở scene nào theo từng giờ.
#   - Marcus đứng ở đâu trong scene đó.
#   - Marcus đang làm gì (state + action).
#
# LỊCH TRÌNH NGÀY 1 (DAY 1 INTRO FLOW):
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

@export var home_position: Vector2 = Vector2(375, 200)
# Vị trí cửa nhà Marcus trong marcus_farm_map.
@export var farm_work_position: Vector2 = Vector2(160, 200)
# Vị trí giữa garden beds — Marcus làm vườn.
@export var house_sleep_position: Vector2 = Vector2(225, 145)
# Vị trí giường ngủ trong marcus_house_map.
@export var town_position: Vector2 = Vector2(430, 90)
# Vị trí Marcus ở town_map (cạnh portal ToMarcusFarm).
@export var player_house_door_position: Vector2 = Vector2(85, 200)
# Vị trí Marcus đứng TRƯỚC cửa nhà PLAYER trong farm_map khi chờ gặp day 1.
# Cách cửa (60, 146) vài pixel về phía nam để Marcus không block portal.
@export var marcus_farm_entry_position: Vector2 = Vector2(40, 200)
# Vị trí Marcus ở rìa trái marcus_farm_map (nơi portal ToTown) khi vừa đi
# từ town về farm sau 11:00.

# Paths scene — dùng constant để dễ refactor.
const SCENE_MARCUS_FARM := "res://scenes/maps/marcus_farm_map.tscn"
const SCENE_MARCUS_HOUSE := "res://scenes/maps/marcus_house_map.tscn"
const SCENE_TOWN := "res://scenes/maps/town_map.tscn"
const SCENE_PLAYER_FARM := "res://scenes/maps/farm_map.tscn"
const SCENE_INSIDE_HOUSE := "res://scenes/maps/inside_house_map.tscn"

# Giờ cutoff cho day 1 intro. Nếu player rời nhà TRƯỚC giờ này → Marcus
# chuyển sang town sau dialogue. Nếu SAU → Marcus giữ schedule marcus_farm
# (không đổi scene).
const INTRO_DEADLINE_HOUR: float = 11.0

# Cờ nội bộ — Marcus đã hoàn thành intro day 1 chưa. Sau khi intro → set
# flag marcus_met_day1 và rebuild schedule. Lưu local để không gọi rebuild lặp.
var has_met_player_day1: bool = false

# Flag dùng để suppress dialogue khi cutscene KHÔNG nên trigger (ví dụ player
# reload scene hoặc test). Set false để tắt auto-cutscene (ví dụ debug).
@export var enable_auto_intro: bool = true


func _ready() -> void:
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


# Schedule được build linh hoạt dựa trên 3 trạng thái:
#   - day == 1 + chưa gặp player     → _schedule_waiting_at_player_house (đứng
#     trước cửa nhà player).
#   - day == 1 + đã gặp + cutscene chuyển sang town (chỉ khi gặp trước 11:00)
#     → _schedule_after_intro_to_town (town → 11:00, farm sau 11:00).
#   - Còn lại (day >= 2, day 1 sau 11:00, day 1 đã gặp sau 11:00)
#     → _schedule_in_farm (sinh hoạt quanh farm).
func _build_default_schedule() -> void:
	if GameState.current_day == 1 and not has_met_player_day1:
		_schedule_waiting_at_player_house()
		return
	if GameState.current_day == 1 and GameState.get_flag("marcus_at_town_post_intro", false):
		_schedule_after_intro_to_town()
		return
	_schedule_in_farm()


# Marcus đợi trước cửa nhà player suốt ngày (1 step tĩnh, time = 0 để luôn
# active). NPCManager sẽ attach Marcus vào farm_map (PLAYER's farm, không
# phải marcus_farm_map) và NPC đứng ở player_house_door_position.
func _schedule_waiting_at_player_house() -> void:
	schedule = [
		{"time": 0.0, "state": NPCState.WAKING, "action": "wait_at_player_house", "scene": SCENE_PLAYER_FARM, "pos": player_house_door_position},
	]


# Schedule NGAY SAU intro (chỉ trigger khi gặp player trước INTRO_DEADLINE_HOUR).
# Marcus đứng ở town cho tới 11:00, sau 11:00 trở về marcus_farm_map.
# Lưu ý: step ở 11:00 chuyển từ town → marcus_farm (vị trí marcus_farm_entry)
# để Marcus "đi bộ" từ town về farm thay vì teleport.
func _schedule_after_intro_to_town() -> void:
	schedule = [
		{"time": 0.0, "state": NPCState.WAKING, "action": "waiting_in_town", "scene": SCENE_TOWN, "pos": town_position},
		# 11:00 — Marcus rời town, đi về marcus_farm_map. Đặt ở rìa trái
		# farm (gần portal ToTown) để Marcus "vừa đến" từ town.
		{"time": INTRO_DEADLINE_HOUR, "state": NPCState.WALKING, "action": "go_home_from_town", "scene": SCENE_MARCUS_FARM, "pos": marcus_farm_entry_position},
		# 12:00 — Marcus bắt đầu làm vườn tại farm của mình.
		{"time": 12.0, "state": NPCState.WORKING, "action": "tend_garden", "scene": SCENE_MARCUS_FARM, "pos": farm_work_position},
		{"time": 17.0, "state": NPCState.WALKING, "action": "go_home", "scene": SCENE_MARCUS_FARM, "pos": home_position},
		{"time": 20.0, "state": NPCState.IDLE, "action": "chat_door", "scene": SCENE_MARCUS_FARM, "pos": home_position},
		{"time": 22.0, "state": NPCState.SLEEPING, "action": "sleep", "scene": SCENE_MARCUS_HOUSE, "pos": house_sleep_position},
	]


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
	stop_walking()
	is_interacting = true
	talk_count += 1
	npc_dialogue_started.emit()
	print("[NPC] %s interacted with player (talk count: %d, day: %d)." % [npc_name, talk_count, GameState.current_day])

	var chosen_id: String = _pick_dialogue_id()
	print("[Neighbor] Chosen dialogue: %s" % chosen_id)
	DialogueManager.start_dialogue(chosen_id, npc_name, npc_id)
	DialogueManager.dialogue_ended.connect(_on_dm_ended, CONNECT_ONE_SHOT)


# Callback khi dialogue kết thúc. Day 1 lần đầu:
#   - Nếu current_time < INTRO_DEADLINE_HOUR (11:00): Marcus chuyển sang town
#     cho tới 11:00, sau 11:00 về farm (schedule _schedule_after_intro_to_town).
#   - Nếu current_time >= 11:00: Marcus giữ _schedule_in_farm (đang ở farm
#     theo schedule, không teleport vì step hiện tại đã khớp farm).
func _on_dm_ended() -> void:
	is_interacting = false
	npc_dialogue_finished.emit()
	if GameState.current_day <= 1 and not has_met_player_day1:
		has_met_player_day1 = true
		GameState.set_flag("neighbor_met_day1", true)
		var ct := GameState.current_time
		if ct < INTRO_DEADLINE_HOUR:
			# Trước 11:00 → Marcus chuyển sang town (chờ player ở town), sau
			# 11:00 về farm.
			GameState.set_flag("marcus_at_town_post_intro", true)
			_schedule_after_intro_to_town()
			print("[NPC] %s: intro complete before %.1f → moving to town until %.1f, then farm." % [npc_name, INTRO_DEADLINE_HOUR, INTRO_DEADLINE_HOUR])
		else:
			# Sau 11:00 → Marcus đã đang ở farm theo schedule, giữ nguyên.
			GameState.set_flag("marcus_at_town_post_intro", false)
			_schedule_in_farm()
			print("[NPC] %s: intro complete after %.1f → staying at marcus_farm per normal schedule." % [npc_name, INTRO_DEADLINE_HOUR])
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
	if old_path == SCENE_INSIDE_HOUSE:
		_was_inside_house = true


# scene_changed — check trigger cutscene (1 frame sau để NPC sync ổn định).
func _on_scene_changed_marcus(_scene_path: String) -> void:
	call_deferred("_check_intro_trigger")


# Thực sự check + trigger cutscene.
func _check_intro_trigger() -> void:
	if not _should_trigger_intro_cutscene():
		return
	_intro_attach_handled = true
	_was_inside_house = false
	print("[NPC] %s: auto-trigger intro cutscene (player left house)." % npc_name)
	# Snap NPC về đúng pos trước cửa nhà player.
	position = player_house_door_position
	_target_pos = position
	stop_walking()
	is_interacting = true
	talk_count += 1
	npc_dialogue_started.emit()
	DialogueManager.start_dialogue("neighbor", npc_name, npc_id)
	DialogueManager.dialogue_ended.connect(_on_dm_ended, CONNECT_ONE_SHOT)


# Check điều kiện trigger cutscene (gọi ngay + gọi lại sau defer).
func _should_trigger_intro_cutscene() -> bool:
	if not enable_auto_intro:
		return false
	if GameState.current_day != 1:
		return false
	if has_met_player_day1:
		return false
	if GameState.get_flag("neighbor_met_day1", false):
		return false
	if DialogueManager.is_active:
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
	if not _was_inside_house:
		return false
	# Player hiện đang ở farm_map.
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return false
	if tree.current_scene.scene_file_path != SCENE_PLAYER_FARM:
		return false
	return true


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

	if GameState.current_day <= 1:
		return "neighbor"

	# Kiểm tra có quest delivery active không
	var delivery_quest: Dictionary = QuestSystem.get_active_delivery_quest_for_npc(npc_id)
	print("[Neighbor] delivery_quest is_empty=%s" % delivery_quest.is_empty())

	if not delivery_quest.is_empty():
		var quest_id: String = delivery_quest.get("id", "")
		var required_item: String = delivery_quest.get("required_item", "")
		var required_amount: int = int(delivery_quest.get("required_amount", 1))

		# CHỈ check item trên hotbar slot đang select (player phải cầm item quest trên tay)
		var selected_item: Dictionary = GameState.get_selected_hotbar_item()
		var selected_id: String = selected_item.get("id", "")
		var selected_amount: int = int(selected_item.get("amount", 0))
		var selected_crop_type: String = QuestSystem.harvest_to_crop_type(selected_id)

		print("=== QUEST DELIVERY CHECK ===")
		print("  Quest ID: %s" % quest_id)
		print("  Quest needs: %s x%d" % [required_item, required_amount])
		print("  Selected slot: id='%s', amount=%d, crop_type='%s'" % [selected_id, selected_amount, selected_crop_type])
		print("  Match? %s" % str(selected_crop_type == required_item and selected_amount >= required_amount))
		print("===========================")

		# Chỉ trigger delivery khi slot hotbar đang select khớp quest
		if selected_crop_type == required_item and selected_amount >= required_amount:
			print("[Neighbor] >>> Returning neighbor_delivery")
			return "neighbor_delivery"

		print("[Neighbor] >>> Returning neighbor_still_need")
		return "neighbor_still_need"

	var available: Array = QuestSystem.get_available_quests_for_npc(npc_id)
	if not available.is_empty():
		return "neighbor_day2_plus"

	return "neighbor_idle"


# Lấy step hiện tại + apply cho NPC. Base class đã có `apply_current_step()` —
# chỉ gọi nó. (KHÔNG cần duplicate logic.)
func _apply_current_step_state() -> void:
	apply_current_step()
