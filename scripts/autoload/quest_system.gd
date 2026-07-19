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


# =============================================================================
# CÁC BIẾN THEO DÕI QUEST
# =============================================================================

# Các quest đang làm
var active_quests: Array[Dictionary] = []

# Các quest đã hoàn thành
var completed_quests: Array[String] = []

# Các quest đã thất bại
var failed_quests: Array[String] = []

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
# Player nhận một quest từ NPC
#
# Tham số:
#   quest_id: String - mã quest cần nhận
#
# Trả về: true nếu nhận thành công

func accept_quest(quest_id: String) -> bool:
	# Kiểm tra quest có tồn tại không
	if not quest_definitions.has(quest_id):
		push_error("[QuestSystem] Unknown quest: %s" % quest_id)
		return false

	# Kiểm tra đã nhận quest này chưa
	for quest: Dictionary in active_quests:
		var existing_id: String = quest.get("id", "")
		if existing_id == quest_id:
			return false  # Đã nhận rồi

	# Lấy định nghĩa quest
	var quest_def: Dictionary = quest_definitions[quest_id]
	
	# Tạo bản sao quest (để không sửa định nghĩa gốc)
	var quest: Dictionary = quest_def.duplicate()
	quest["accepted_day"] = GameState.current_day  # Ngày nhận
	quest["status"] = "active"
	
	# Thêm vào danh sách quest đang làm
	active_quests.append(quest)

	# Đăng ký intervention nếu có
	if quest_def.has("chain_interaction"):
		var chain_id: String = quest_def.get("chain_interaction", "")
		if quest_def.has("intervention_effect"):
			var effect: String = quest_def.get("intervention_effect", "")
			_register_intervention(quest_id, chain_id, effect)

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
	
	# Thêm vào danh sách completed
	completed_quests.append(quest_id)

	# =================================================================
	# TRAO PHẦN THƯỞNG
	# =================================================================
	var reward: Dictionary = quest.get("reward", {})
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
