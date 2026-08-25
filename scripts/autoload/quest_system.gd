extends Node
# =============================================================================
# QUEST SYSTEM (Hệ thống Nhiệm vụ)
# =============================================================================
# Chức năng: Quản lý nhiệm vụ (quests) trong game
#
# Các loại quest:
#   - escort: Hộ tống NPC đến địa điểm
#   - delivery: Giao hàng/vật phẩm
#   - investigation: Điều tra/khám phá
#   - social: Tham gia sự kiện
#
# Luồng quest:
#   1. NPC đưa ra quest -> player nhận (accept_quest)
#   2. Player hoàn thành mục tiêu
#   3. Gọi complete_quest -> nhận thưởng
#
# CÁCH SỬ DỤNG:
#   QuestSystem.accept_quest("deliver_medicine") - nhận quest
#   QuestSystem.complete_quest("deliver_medicine") - hoàn thành
#   QuestSystem.is_quest_active("deliver_medicine") - kiểm tra đang làm
# =============================================================================

# =============================================================================
# TÍN HIỆU (SIGNALS)
# =============================================================================

# Phát ra khi nhận quest mới
signal quest_accepted(quest_id: String, context: Dictionary)

# Phát ra khi hoàn thành quest
signal quest_completed(quest_id: String)

# Phát ra khi quest thất bại
signal quest_failed(quest_id: String)

# Phát ra khi không thể nhận quest vì item trùng lặp
signal quest_rejected_duplicate_item(item_id: String, quest_id: String)


# =============================================================================
# CÁC BIẾN THEO DÕI QUEST
# =============================================================================

# Các quest đang làm
var active_quests: Array[Dictionary] = []

# Các quest đã hoàn thành
var completed_quests: Array[String] = []

# Các quest đã thất bại
var failed_quests: Array[String] = []

# =============================================================================
# HỆ THỐNG CACHE QUEST HÀNG NGÀY (cho bảng tin)
# =============================================================================
# Lưu quests hiển thị trên bảng tin theo ngày.
# Chỉ reset khi sang ngày mới, không phải mỗi lần mở bảng.

var _daily_board_quests: Dictionary = {}  # {npc_id: Array[quest]}
var _daily_board_quest_day: int = -1     # Ngày đã cache quests
var _daily_board_has_quests: Dictionary = {}  # {npc_id: bool} - đã roll có quest trong ngày

# =============================================================================
# HỆ THỐNG QUEST NGẪU NHIÊN THEO CÂY TRỒNG
# =============================================================================
# Các loại cây trồng CÓ THỰC trong game (dựa trên resource definitions)
const FARM_CROPS: Array[String] = [
	"wheat",    # Lúa mì (seed: seed_wheat, harvest: wheat)
	"corn",     # Ngô (seed: seed_corn, harvest: corn)
	"tomato",   # Cà chua (seed: seed_tomato, harvest: tomato)
	"potato",   # Khoai tây (seed: seed_potato, harvest: potato)
	"turnip",   # Củ cải (seed: seed_turnip, harvest: turnip)
]

# Phần thưởng theo số lượng: amount → gold reward
const GOLD_REWARD_BY_AMOUNT: Dictionary = {
	1: 25,
	2: 50,
	3: 75,
	4: 100,
	5: 125,
}

# Relationship reward theo số lượng (ceiling of gold/20)
const RELATIONSHIP_REWARD_BY_AMOUNT: Dictionary = {
	1: 2,
	2: 3,
	3: 4,
	4: 5,
	5: 6,
}

# Tên hiển thị của cây trồng (theo item_id trong resources)
const CROP_DISPLAY_NAMES: Dictionary = {
	"wheat": "Wheat",
	"corn": "Corn",
	"tomato": "Tomato",
	"potato": "Potato",
	"turnip": "Turnip",
}

# Mapping từ harvest item_id → crop_type (để so sánh quest)
# Ví dụ: "tomato_harvest" → "tomato"
const HARVEST_TO_CROP: Dictionary = {
	"wheat_harvest": "wheat",
	"corn_harvest": "corn",
	"tomato_harvest": "tomato",
	"potato_harvest": "potato",
	"turnip_harvest": "turnip",
}

# =============================================================================
# HÀM CONVERT HARVEST ITEM → CROP TYPE
# =============================================================================
# Chuyển đổi item_id harvest (như "tomato_harvest") sang crop_type (như "tomato")
# Dùng để so sánh khi kiểm tra quest delivery
#
# Tham số:
#   item_id: String - item_id cần convert (vd: "tomato_harvest")
#
# Trả về: crop_type nếu tìm thấy, ngược lại trả về item_id gốc

func harvest_to_crop_type(item_id: String) -> String:
	return HARVEST_TO_CROP.get(item_id, item_id)


# Convert crop type (vd "tomato") sang harvest item id (vd "tomato_harvest").
# Nếu item_id đã là harvest (vd "tomato_harvest") thì trả về nguyên.
func crop_to_harvest(item_id: String) -> String:
	if item_id.ends_with("_harvest"):
		return item_id
	for harvest_id: String in HARVEST_TO_CROP:
		if HARVEST_TO_CROP[harvest_id] == item_id:
			return harvest_id
	return item_id

# Định nghĩa tất cả quest có trong game
var quest_definitions: Dictionary = {}


# =============================================================================
# HÀM KHỞI TẠO (_ready)
# =============================================================================

func _ready() -> void:
	_build_quest_library()  # Xây dựng thư viện quest
	print("[QuestSystem] Ready — %d quests available." % quest_definitions.size())


# =============================================================================
# HÀM XÂY DỰNG THƯ VIỆN QUEST (_build_quest_library)
# =============================================================================
# Định nghĩa tất cả quest có trong game
# Mỗi quest gồm:
#   - id: mã quest
#   - name: tên quest
#   - description: mô tả
#   - giver: NPC đưa quest
#   - type: loại quest
#   - reward: phần thưởng

func _build_quest_library() -> void:
	quest_definitions = {
		# =================================================================
		# QUEST HỘ TỐNG
		# =================================================================
		"escort_voss_mountain": {
			"id": "escort_voss_mountain",
			"name": "Mountain Walk",
			"description": "Old Voss is heading up the mountain. He seems uneasy about going alone.",
			"giver": "shopkeeper_father",
			"type": "escort",                      # Loại: hộ tống
			"target_npc": "shopkeeper_father",     # NPC cần hộ tống
			"target_location": "mountain_path",    # Địa điểm đến
			"reward": {"item": "old_key", "amount": 1},  # Phần thưởng: chìa khóa
			"fail_conditions": ["npc_died_without_player"],  # Điều kiện thất bại
			"chain_interaction": "shopkeeper_mountain",     # Chain sự kiện liên quan
			"intervention_effect": "player_escorted",
		},

		# =================================================================
		# QUEST GIAO HÀNG
		# =================================================================
		"deliver_medicine": {
			"id": "deliver_medicine",
			"name": "Medicine Delivery",
			"description": "Martha Miller needs medicine delivered to Old Voss before his mountain trip.",
			"giver": "farmer_mother",
			"type": "delivery",
			"target_npc": "shopkeeper_father",
			"reward": {"item": "coin", "amount": 50},
			"chain_interaction": "shopkeeper_mountain",
		},

		# =================================================================
		# QUEST ĐIỀU TRA
		# =================================================================
		"investigate_noise": {
			"id": "investigate_noise",
			"name": "Strange Sounds",
			"description": "Villagers have been hearing strange sounds at night near the forest edge.",
			"giver": "hermit",
			"type": "investigation",
			"target_location": "forest_edge",
			"reward": {"item": "lore_fragment", "amount": 1},
			"chain_interaction": "harvest_blight",
		},

		# =================================================================
		# QUEST SỰ KIỆN
		# =================================================================
		"attend_festival": {
			"id": "attend_festival",
			"name": "Village Festival",
			"description": "The annual village festival is tomorrow. Everyone is invited.",
			"giver": "shopkeeper_father",
			"type": "social",
			"target_location": "village_square",
			"chain_interaction": "festival_day",
			"fail_conditions": ["player_absent", "festival_cancelled"],
		},
	}


# =============================================================================
# HÀM NHẬN QUEST (accept_quest)
# =============================================================================
# Player nhận một quest từ NPC hoặc bảng tin
#
# Tham số:
#   quest_id: String - mã quest cần nhận
#   quest_data: Dictionary (optional) - dữ liệu quest, dùng cho dynamic quests
#
# Trả về: true nếu nhận thành công

func accept_quest(quest_id: String, quest_data: Dictionary = {}) -> bool:
	# Kiểm tra đã nhận quest này chưa
	for q: Dictionary in active_quests:
		var existing_id: String = q.get("id", "")
		if existing_id == quest_id:
			print("[QuestSystem] Quest %s already active." % quest_id)
			return false

	var quest: Dictionary

	# Kiểm tra quest tĩnh có trong definitions
	if quest_definitions.has(quest_id):
		var quest_def: Dictionary = quest_definitions[quest_id]
		quest = quest_def.duplicate()

		# Kiểm tra không cho nhận quest với item trùng lặp (delivery quest)
		var qtype: String = quest.get("type", "")
		if qtype == "delivery":
			var req_item: String = quest.get("required_item", "")
			if req_item != "" and has_active_quest_with_item(req_item):
				print("[QuestSystem] Cannot accept %s - already have active delivery quest with item '%s'" % [quest_id, req_item])
				quest_rejected_duplicate_item.emit(req_item, quest_id)
				return false

		# Tính deadline ngẫu nhiên từ 2-3 ngày
		var days_min: int = quest_def.get("days_to_complete_min", 2)
		var days_max: int = quest_def.get("days_to_complete_max", 3)
		var days_range: int = days_max - days_min + 1
		var deadline_days: int = days_min + (randi() % days_range)
		quest["deadline_day"] = GameState.current_day + deadline_days
		print("[QuestSystem] Quest %s deadline: day %d (%d days)" % [quest_id, quest["deadline_day"], deadline_days])

		# Đăng ký intervention nếu có
		if quest_def.has("chain_interaction"):
			var chain_id: String = quest_def.get("chain_interaction", "")
			if quest_def.has("intervention_effect"):
				var effect: String = quest_def.get("intervention_effect", "")
				_register_intervention(quest_id, chain_id, effect)
	elif quest_data.is_empty():
		# Không có trong definitions và không có quest_data
		push_error("[QuestSystem] Unknown quest: %s" % quest_id)
		return false
	else:
		# Dynamic quest - dùng quest_data trực tiếp
		quest = quest_data.duplicate()
		# Tính deadline cho dynamic quest
		var days_min: int = quest.get("days_to_complete_min", 2)
		var days_max: int = quest.get("days_to_complete_max", 3)
		var days_range: int = days_max - days_min + 1
		var deadline_days: int = days_min + (randi() % days_range)
		quest["deadline_day"] = GameState.current_day + deadline_days

	# Thêm thông tin chung
	quest["id"] = quest_id
	quest["accepted_day"] = GameState.current_day
	quest["status"] = "active"

	# Thêm vào danh sách quest đang làm
	active_quests.append(quest)

	print("[QuestSystem] Quest %s added to active_quests. Total active: %d" % [quest_id, active_quests.size()])
	for q: Dictionary in active_quests:
		print("  - Quest: id=%s, giver=%s, type=%s, item=%s, amount=%d" % [
			q.get("id", ""),
			q.get("giver", ""),
			q.get("type", ""),
			q.get("required_item", ""),
			int(q.get("required_amount", 0))
		])

	# Phát tín hiệu
	quest_accepted.emit(quest_id, quest)
	print("[QuestSystem] Quest accepted: %s" % quest_id)
	return true


# =============================================================================
# HÀM HOÀN THÀNH QUEST (complete_quest)
# =============================================================================
# Hoàn thành một quest và trao thưởng
#
# Tham số:
#   quest_id: String - mã quest đã hoàn thành
#
# Trả về: true nếu thành công

func complete_quest(quest_id: String) -> bool:
	# Tìm quest trong danh sách active
	var quest_idx: int = _find_active_quest(quest_id)
	if quest_idx < 0:
		return false

	# Lấy quest và xóa khỏi active
	var quest: Dictionary = active_quests[quest_idx]
	active_quests.remove_at(quest_idx)

	# Kiểm tra quest có repeatable không
	var is_repeatable: bool = quest.get("repeatable", false)
	if is_repeatable:
		# Repeatable quest: xóa khỏi completed để có thể nhận lại
		completed_quests.erase(quest_id)
		print("[QuestSystem] Repeatable quest completed: %s (available again)" % quest_id)
	else:
		# Quest thường: thêm vào completed
		completed_quests.append(quest_id)

	# =================================================================
	# TRAO PHẦN THƯỞNG
	# =================================================================
	var reward: Dictionary = quest.get("reward", {})
	var giver: String = quest.get("giver", "")

	if reward.has("gold"):
		GameState.gold += int(reward.get("gold", 0))
	if reward.has("relationship") and giver != "":
		GameState.modify_relationship(giver, int(reward.get("relationship", 0)))
	if reward.has("item"):
		var item: String = reward.get("item", "")
		var amount: int = reward.get("amount", 1)
		GameState.add_item(item, amount)

	# Phát tín hiệu
	quest_completed.emit(quest_id)
	print("[QuestSystem] Quest completed: %s" % quest_id)
	return true


# =============================================================================
# HÀM THẤT BẠI QUEST (fail_quest)
# =============================================================================
# Quest thất bại do không hoàn thành kịp thời
#
# Tham số:
#   quest_id: String - mã quest thất bại
#   reason: String - lý do thất bại

func fail_quest(quest_id: String, reason: String) -> bool:
	var quest_idx: int = _find_active_quest(quest_id)
	if quest_idx < 0:
		return false

	var quest: Dictionary = active_quests[quest_idx]
	active_quests.remove_at(quest_idx)
	failed_quests.append(quest_id)

	# =================================================================
	# PENALTY KHI THẤT BẠI: Relationship giảm = relationship thưởng / 2 (làm tròn lên)
	# =================================================================
	var reward: Dictionary = quest.get("reward", {})
	var giver: String = quest.get("giver", "")
	if reward.has("relationship") and giver != "":
		var penalty: int = ceili(float(reward.get("relationship", 0)) / 2.0)
		if penalty > 0:
			GameState.modify_relationship(giver, -penalty)
			print("[QuestSystem] Quest failed: %s - relationship with %s decreased by %d" % [quest_id, giver, penalty])

	# Đặt cờ thất bại
	GameState.set_flag("quest_%s_failed" % quest_id, true)
	GameState.set_flag("quest_%s_fail_reason" % quest_id, reason)

	quest_failed.emit(quest_id)
	print("[QuestSystem] Quest failed: %s (%s)" % [quest_id, reason])
	return true


# =============================================================================
# HÀM ĐĂNG KÝ INTERVENTION (_register_intervention)
# =============================================================================
# Ghi nhận player đã can thiệp vào chain sự kiện

func _register_intervention(quest_id: String, chain_id: String, effect: String) -> void:
	GameState.set_flag("quest_%s_intervention_%s" % [quest_id, chain_id], true)


# =============================================================================
# HÀM KIỂM TRA INTERVENTION (check_intervention)
# =============================================================================

func check_intervention(quest_id: String, chain_id: String) -> bool:
	return GameState.get_flag("quest_%s_intervention_%s" % [quest_id, chain_id], false)


# =============================================================================
# HÀM XỬ LÝ KẾT QUẢ CHAIN (on_event_outcome)
# =============================================================================
# Xử lý khi chain sự kiện kết thúc
# Cập nhật quest tương ứng

func on_event_outcome(chain_id: String, outcome: String) -> void:
	# Duyệt các quest đang làm
	for quest: Dictionary in active_quests:
		var interaction: String = quest.get("chain_interaction", "")
		if interaction != chain_id:
			continue

		var qtype: String = quest.get("type", "")
		var qid: String = quest.get("id", "")

		# Xử lý theo kết quả
		match outcome:
			"safe":
				if qtype == "escort":
					complete_quest(qid)
			"injured":
				if qtype == "escort":
					complete_quest(qid)
			"dead":
				if qtype == "escort":
					var fail_reason: String = "The person you were supposed to protect died."
					if check_intervention(qid, chain_id):
						fail_reason = "Despite your escort, something went terribly wrong."
					fail_quest(qid, fail_reason)


# =============================================================================
# HÀM KIỂM TRA QUEST ĐANG LÀM (is_quest_active)
# =============================================================================

func is_quest_active(quest_id: String) -> bool:
	for quest: Dictionary in active_quests:
		var existing_id: String = quest.get("id", "")
		if existing_id == quest_id:
			return true
	return false


# =============================================================================
# HÀM KIỂM TRA QUEST ĐÃ HOÀN THÀNH (is_quest_completed)
# =============================================================================

func is_quest_completed(quest_id: String) -> bool:
	return quest_id in completed_quests


# =============================================================================
# HÀM KIỂM TRA QUEST THẤT BẠI (is_quest_failed)
# =============================================================================

func is_quest_failed(quest_id: String) -> bool:
	return quest_id in failed_quests


# =============================================================================
# HÀM TÌM QUEST TRONG ACTIVE (_find_active_quest)
# =============================================================================

func _find_active_quest(quest_id: String) -> int:
	for i: int in range(active_quests.size()):
		var existing_id: String = active_quests[i].get("id", "")
		if existing_id == quest_id:
			return i
	return -1


# =============================================================================
# HÀM LẤY DANH SÁCH QUEST ĐANG LÀM (get_active_quests)
# =============================================================================

func get_active_quests() -> Array:
	return active_quests.duplicate()


# =============================================================================
# HÀM LẤY ĐỊNH NGHĨA QUEST (get_quest_definition)
# =============================================================================

func get_quest_definition(quest_id: String) -> Dictionary:
	return quest_definitions.get(quest_id, {})


# =============================================================================
# HÀM LẤY QUEST CÓ THỂ NHẬN (get_available_quests)
# =============================================================================
# Các quest chưa nhận, chưa hoàn thành, chưa thất bại

func get_available_quests() -> Array:
	var available: Array = []
	for quest_id: String in quest_definitions:
		if not is_quest_active(quest_id) and not is_quest_completed(quest_id) and not is_quest_failed(quest_id):
			available.append(quest_definitions[quest_id])
	return available


# =============================================================================
# HÀM KIỂM TRA CÓ QUEST HỘ TỐNG CHO NPC (has_active_escort_quest)
# =============================================================================

func has_active_escort_quest(target_npc: String) -> bool:
	for quest: Dictionary in active_quests:
		var targ: String = quest.get("target_npc", "")
		var qtype: String = quest.get("type", "")
		if targ == target_npc and qtype == "escort":
			return true
	return false


# =============================================================================
# HÀM LỌC QUEST THEO NPC (get_active_quests_for_npc / get_available_quests_for_npc)
# =============================================================================
# Dùng bởi neighbor.gd để chọn dialogue phù hợp với quest state.

func get_active_quests_for_npc(npc_id: String) -> Array:
	var result: Array = []
	for quest: Dictionary in active_quests:
		var giver: String = quest.get("giver", "")
		if giver == npc_id:
			result.append(quest)
	return result


func get_available_quests_for_npc(npc_id: String) -> Array:
	var result: Array = []
	for quest_id: String in quest_definitions:
		var quest: Dictionary = quest_definitions[quest_id]
		var giver: String = quest.get("giver", "")
		if giver != npc_id:
			continue
		if is_quest_active(quest_id) or is_quest_completed(quest_id) or is_quest_failed(quest_id):
			continue
		result.append(quest)
	return result


# =============================================================================
# HÀM KIỂM TRA QUEST VỚI ITEM TRÙNG LẶP (has_active_quest_with_item)
# =============================================================================
# Kiểm tra xem có quest delivery nào đang active với cùng required_item không
# Dùng để không cho nhận 2 quest với cùng item
#
# Tham số:
#   item_id: String - item cần kiểm tra
#
# Trả về: true nếu đã có quest active với item này

func has_active_quest_with_item(item_id: String) -> bool:
	# Convert harvest item (vd "tomato_harvest") sang crop type (vd "tomato")
	var crop_type: String = harvest_to_crop_type(item_id)
	for quest: Dictionary in active_quests:
		var qtype: String = quest.get("type", "")
		if qtype == "delivery":
			var req_item: String = quest.get("required_item", "")
			if req_item == crop_type:
				return true
	return false


# =============================================================================
# HÀM KIỂM TRA QUEST HẾT HẠN (check_expired_quests)
# =============================================================================
# Gọi mỗi khi sang ngày mới (advance_day). Kiểm tra tất cả active quests,
# nếu deadline_day < current_day thì fail quest.
# Trả về số quest đã bị hủy.

func check_expired_quests() -> int:
	var expired_count: int = 0
	var to_expire: Array = []

	# Tìm các quest đã hết hạn
	for quest: Dictionary in active_quests:
		var deadline: int = quest.get("deadline_day", 0)
		if deadline > 0 and GameState.current_day > deadline:
			to_expire.append({"id": quest.get("id", ""), "deadline": deadline})

	# Hủy từng quest hết hạn
	for item: Dictionary in to_expire:
		var quest_id: String = item.get("id", "")
		var deadline: int = item.get("deadline", 0)
		var fail_reason: String = "Quest expired. Deadline was day %d." % deadline
		fail_quest(quest_id, fail_reason)
		expired_count += 1

	if expired_count > 0:
		print("[QuestSystem] %d quest(s) expired on day %d." % [expired_count, GameState.current_day])

	return expired_count


# =============================================================================
# HÀM LẤY THÔNG TIN DEADLINE QUEST (get_quest_deadline)
# =============================================================================

func get_quest_deadline(quest_id: String) -> Dictionary:
	for quest: Dictionary in active_quests:
		if quest.get("id", "") == quest_id:
			var deadline: int = quest.get("deadline_day", 0)
			var days_left: int = maxi(deadline - GameState.current_day, 0)
			return {"deadline": deadline, "days_left": days_left}
	return {"deadline": 0, "days_left": 0}


# =============================================================================
# HÀM TẠO QUEST NGẪU NHIÊN (generate_random_delivery_quest)
# =============================================================================
# Tạo quest giao hàng ngẫu nhiên với cây trồng random (1-5 items)
# Trả về Dictionary quest mới, KHÔNG lưu vào definitions (chỉ dùng 1 lần rồi bỏ)

func generate_random_delivery_quest(npc_id: String) -> Dictionary:
	var crop_type: String = FARM_CROPS[randi() % FARM_CROPS.size()]
	var required_amount: int = (randi() % 5) + 1  # 1-5

	var crop_name: String = CROP_DISPLAY_NAMES.get(crop_type, crop_type.capitalize())
	var quest_name: String = "Deliver %d %s" % [required_amount, crop_name]
	var quest_desc: String = "Deliver %d %s to %s." % [required_amount, crop_name, npc_id.capitalize()]

	var quest: Dictionary = {
		"id": "dynamic_delivery_%s_%d" % [npc_id, Time.get_unix_time_from_system()],
		"name": quest_name,
		"description": quest_desc,
		"giver": npc_id,
		"type": "delivery",
		"required_item": crop_type,
		"required_amount": required_amount,
		"days_to_complete_min": 2,
		"days_to_complete_max": 3,
		"reward": {
			"gold": GOLD_REWARD_BY_AMOUNT.get(required_amount, 25),
			"relationship": RELATIONSHIP_REWARD_BY_AMOUNT.get(required_amount, 2),
		},
		"repeatable": true,
		"is_dynamic": true,  # Đánh dấu là quest động
		"crop_name": crop_name,  # Lưu tên cây cho dialogue
		"amount": required_amount,
	}
	return quest


# =============================================================================
# HÀM LẤY QUEST NGẪU NHIÊN CHO NPC (get_random_quest_for_npc)
# =============================================================================
# Trả về 1 quest ngẫu nhiên (delivery) cho NPC. Dùng cho bảng tin.

func get_random_quest_for_npc(npc_id: String) -> Dictionary:
	return generate_random_delivery_quest(npc_id)


# =============================================================================
# HÀM LẤY QUEST CHO BẢNG TIN (get_quests_for_board)
# =============================================================================
# Trả về danh sách quest hiển thị trên bảng tin.
# Chỉ reset khi sang ngày mới (dựa trên GameState.current_day).
# Bao gồm: quest tĩnh có sẵn + 1-2 quest ngẫu nhiên (delivery)

func get_quests_for_board(npc_id: String) -> Array:
	# Kiểm tra nếu cần reset cache (sang ngày mới)
	if _daily_board_quest_day != GameState.current_day:
		_regenerate_daily_quests()

	# Trả về quests đã cache cho NPC này
	if _daily_board_quests.has(npc_id):
		return _daily_board_quests[npc_id]
	return []


# =============================================================================
# HÀM TÁI TẠO QUEST HÀNG NGÀY (_regenerate_daily_quests)
# =============================================================================

func _regenerate_daily_quests() -> void:
	_daily_board_quests.clear()
	_daily_board_has_quests.clear()
	_daily_board_quest_day = GameState.current_day

	# Tạo quests cho tất cả NPC có bảng tin
	# Hiện tại chỉ có "neighbor"
	var npcs_with_boards: Array[String] = ["neighbor"]

	for npc_id: String in npcs_with_boards:
		# Roll xác suất xuất hiện quest (chỉ roll 1 lần mỗi ngày)
		var chance: float = GameState.base_quest_chance + GameState.quest_appearance_bonus
		var rolled: bool = randf() <= chance

		if not rolled:
			# Roll thất bại → không có quest hôm nay
			_daily_board_has_quests[npc_id] = false
			_daily_board_quests[npc_id] = []
			continue

		# Roll thành công → có quest hôm nay
		_daily_board_has_quests[npc_id] = true

		var result: Array = []

		# 1. Lấy các quest tĩnh (không phải dynamic) còn available
		var available_static: Array = get_available_quests_for_npc(npc_id)
		for q: Dictionary in available_static:
			if not q.get("is_dynamic", false):
				result.append(q)

		# 2. Thêm 1-2 quest ngẫu nhiên (delivery) mỗi ngày
		var random_quest_count: int = 1 + (randi() % 2)  # 1-2
		for _i: int in range(random_quest_count):
			result.append(generate_random_delivery_quest(npc_id))

		_daily_board_quests[npc_id] = result

	print("[QuestSystem] Daily quests regenerated for day %d" % GameState.current_day)


# =============================================================================
# HÀM KIỂM TRA CÓ QUEST TRONG NGÀY (has_quests_today)
# =============================================================================
# Trả về true nếu hôm nay bảng tin có quest (sau khi roll)

func has_quests_today(npc_id: String) -> bool:
	# Kiểm tra nếu cần reset cache (sang ngày mới)
	if _daily_board_quest_day != GameState.current_day:
		_regenerate_daily_quests()

	if _daily_board_has_quests.has(npc_id):
		return _daily_board_has_quests[npc_id]
	return false


# =============================================================================
# HÀM LẤY QUEST GIAO HÀNG ĐANG LÀM (get_active_delivery_quest_for_npc)
# =============================================================================
# Trả về quest delivery đang active cho NPC nếu có

func get_active_delivery_quest_for_npc(npc_id: String) -> Dictionary:
	print("[QuestSystem] get_active_delivery_quest_for_npc(%s) called" % npc_id)
	print("[QuestSystem] active_quests count: %d" % active_quests.size())

	for quest: Dictionary in active_quests:
		var giver: String = quest.get("giver", "")
		var qtype: String = quest.get("type", "")
		var qid: String = quest.get("id", "")
		print("[QuestSystem] Checking quest: giver='%s' == npc_id='%s' ? %s" % [giver, npc_id, giver == npc_id])
		print("[QuestSystem] Checking quest: type='%s' == 'delivery' ? %s" % [qtype, qtype == "delivery"])

		if giver == npc_id and qtype == "delivery":
			print("[QuestSystem] FOUND delivery quest for %s: %s" % [npc_id, qid])
			return quest

	print("[QuestSystem] No delivery quest found for %s" % npc_id)
	return {}


# =============================================================================
# HÀM KIỂM TRA ĐỦ VẬT PHẨM CHƯA (has_required_items)
# =============================================================================
# Kiểm tra player có đủ vật phẩm cho quest delivery không

func has_required_items(quest_id: String) -> bool:
	for quest: Dictionary in active_quests:
		if quest.get("id", "") == quest_id:
			var required_item: String = quest.get("required_item", "")
			var required_amount: int = int(quest.get("required_amount", 0))
			var player_amount: int = GameState.get_item_count(required_item)
			return player_amount >= required_amount
	return false


# =============================================================================
# HÀM HOÀN THÀNH GIAO HÀNG (complete_delivery_quest)
# =============================================================================
# Trả về true nếu thành công. Consume items từ inventory.

func complete_delivery_quest(quest_id: String) -> bool:
	var quest_idx: int = _find_active_quest(quest_id)
	if quest_idx < 0:
		print("[QuestSystem] complete_delivery_quest: quest %s NOT FOUND in active" % quest_id)
		return false

	var quest: Dictionary = active_quests[quest_idx]

	# Kiểm tra đủ item chưa
	var required_item: String = quest.get("required_item", "")  # crop type vd "tomato"
	var required_amount: int = int(quest.get("required_amount", 0))
	# Convert sang harvest id (vd "tomato_harvest") để so sánh/match với hotbar
	var harvest_id: String = crop_to_harvest(required_item)
	var slot: Dictionary = GameState.get_selected_hotbar_item()
	var slot_id: String = slot.get("id", "")
	var slot_amount: int = int(slot.get("amount", 0))
	print("[QuestSystem] complete_delivery_quest(%s): need %d x %s (harvest: %s)" % [quest_id, required_amount, required_item, harvest_id])
	print("[QuestSystem] Selected slot: id='%s' amount=%d" % [slot_id, slot_amount])
	if slot_id != harvest_id or slot_amount < required_amount:
		print("[QuestSystem] NOT ENOUGH or WRONG item in selected slot")
		return false

	# Trừ items từ hotbar slot đang select
	var remove_ok: bool = GameState.remove_item(harvest_id, required_amount)
	print("[QuestSystem] remove_item returned: %s" % str(remove_ok))
	if not remove_ok:
		print("[QuestSystem] FAILED to remove items")
		return false

	# Hoàn thành quest (sẽ xử lý reward)
	active_quests.remove_at(quest_idx)

	var is_repeatable: bool = quest.get("repeatable", false)
	if is_repeatable:
		completed_quests.erase(quest_id)
	else:
		completed_quests.append(quest_id)

	# Trao phần thưởng
	var reward: Dictionary = quest.get("reward", {})
	var giver: String = quest.get("giver", "")

	print("[QuestSystem] Reward: %s, giver: %s" % [str(reward), giver])
	if reward.has("gold"):
		var gold_amt: int = int(reward.get("gold", 0))
		var gold_before: int = GameState.gold
		GameState.gold += gold_amt
		print("[QuestSystem] GOLD: %d -> %d (+%d)" % [gold_before, GameState.gold, gold_amt])
	if reward.has("relationship") and giver != "":
		var rel_amt: int = int(reward.get("relationship", 0))
		GameState.modify_relationship(giver, rel_amt)
		print("[QuestSystem] RELATIONSHIP: %s +%d" % [giver, rel_amt])
	if reward.has("item"):
		var item: String = reward.get("item", "")
		var amount: int = reward.get("amount", 1)
		GameState.add_item(item, amount)
		print("[QuestSystem] ITEM: +%d x %s" % [amount, item])

	quest_completed.emit(quest_id)
	print("[QuestSystem] Delivery quest completed: %s" % quest_id)
	return true
