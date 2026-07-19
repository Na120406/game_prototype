extends Node
# =============================================================================
# FAMILY REGISTRY (Đăng ký Gia đình)
# =============================================================================
# Chức năng: Quản lý thông tin các gia đình và thành viên trong làng
#
# Mỗi gia đình gồm:
#   - Thông tin gia đình (tên, địa điểm, công việc)
#   - Danh sách thành viên (sống/chết, vai trò)
#   - Trạng thái gia đình (INTACT, REDUCED, SCATTERED, EXTINCT)
#
# Tính năng:
#   - Theo dõi sống/chết của thành viên
#   - Kế thừa chức vụ khi head chết
#   - Quản lý cửa hàng/doanh nghiệp gia đình
#   - Lưu/load trạng thái gia đình
#
# CÁCH SỬ DỤNG:
#   FamilyRegistry.get_family("shopkeeper_family") - lấy thông tin gia đình
#   FamilyRegistry.get_alive_members("shopkeeper_family") - lấy thành viên sống
#   FamilyRegistry.is_business_operational("shopkeeper_family") - kiểm tra cửa hàng
# =============================================================================

# =============================================================================
# ENUM - TRẠNG THÁI GIA ĐÌNH
# =============================================================================

enum FamilyStatus {
	INTACT,     # Gia đình đầy đủ (bình thường)
	REDUCED,    # Gia đình giảm (mất 1 thành viên)
	SCATTERED,  # Gia đình tan vỡ (còn nhiều người nhưng không đầy đủ)
	EXTINCT     # Gia đình tuyệt tự (không còn ai)
}


# =============================================================================
# CÁC BIẾN
# =============================================================================

# Lưu trữ tất cả gia đình
# Key: family_id, Value: Dictionary thông tin gia đình
var families: Dictionary = {}


# =============================================================================
# HÀM KHỞI TẠO (_ready)
# =============================================================================

func _ready() -> void:
	_build_initial_families()  # Tạo dữ liệu gia đình ban đầu
	print("[FamilyRegistry] Ready — %d families registered." % families.size())


# =============================================================================
# HÀM TẠO DỮ LIỆU GIA ĐÌNH BAN ĐẦU (_build_initial_families)
# =============================================================================

func _build_initial_families() -> void:
	families = {
		# =================================================================
		# GIA ĐÌNH SHOPKEEPER (VOSS)
		# =================================================================
		"shopkeeper_family": {
			"id": "shopkeeper_family",
			"name": "The Shopkeeper's Family",
			"surname": "Voss",
			"status": FamilyStatus.INTACT,
			"members": [
				# Ông Voss (cha) - chủ cửa hàng
				{
					"id": "shopkeeper_father",
					"name": "Old Voss",
					"role": "father",
					"alive": true,                    # Đang sống
					"at_home": true,                  # Đang ở nhà
					"personality": "cautious",        # Tính cách: cẩn thận
					"dialogue_id": "shopkeeper_father_normal",
					"successor": "shopkeeper_son",     # Kế thừa: Voss con
					"scene_path": "res://scenes/npc/shopkeeper_father.tscn",
				},
				# Voss con (con trai)
				{
					"id": "shopkeeper_son",
					"name": "Young Voss",
					"role": "son",
					"alive": true,
					"at_home": true,
					"personality": "reckless",        # Tính cách: liều lĩnh
					"dialogue_id": "shopkeeper_son_normal",
					"successor": "",                   # Không có người kế thừa
					"scene_path": "res://scenes/npc/shopkeeper_son.tscn",
				},
			],
			"current_head": "shopkeeper_father",   # Người đứng đầu hiện tại
			"home_location": Vector2(240, 320),    # Vị trí nhà
			"business_name": "Voss General Store", # Tên cửa hàng
		},
		
		# =================================================================
		# GIA ĐÌNH NÔNG DÂN (MILLER)
		# =================================================================
		"farmer_family": {
			"id": "farmer_family",
			"name": "The Miller Family",
			"surname": "Miller",
			"status": FamilyStatus.INTACT,
			"members": [
				# Bà Martha (mẹ) - chủ trang trại
				{
					"id": "farmer_mother",
					"name": "Martha Miller",
					"role": "mother",
					"alive": true,
					"at_home": true,
					"personality": "cautious",
					"dialogue_id": "farmer_mother_normal",
					"successor": "",
					"scene_path": "res://scenes/npc/farmer_mother.tscn",
				},
				# Eliza (con gái)
				{
					"id": "farmer_daughter",
					"name": "Eliza Miller",
					"role": "daughter",
					"alive": true,
					"at_home": true,
					"personality": "normal",
					"dialogue_id": "farmer_daughter_normal",
					"successor": "",
					"scene_path": "res://scenes/npc/farmer_daughter.tscn",
				},
			],
			"current_head": "farmer_mother",
			"home_location": Vector2(480, 180),
			"business_name": "Miller Farm",
		},
		
		# =================================================================
		# ẨN SĨ (HERMIT)
		# =================================================================
		"hermit_family": {
			"id": "hermit_family",
			"name": "The Hermit",
			"surname": "",
			"status": FamilyStatus.INTACT,
			"members": [
				{
					"id": "hermit",
					"name": "Old Hanz",
					"role": "hermit",
					"alive": true,
					"at_home": true,
					"personality": "old",
					"dialogue_id": "hermit_normal",
					"successor": "",
					"scene_path": "res://scenes/npc/hermit.tscn",
				},
			],
			"current_head": "hermit",
			"home_location": Vector2(600, 400),
			"business_name": "",
		},
	}


# =============================================================================
# HÀM LẤY THÔNG TIN GIA ĐÌNH (get_family)
# =============================================================================

func get_family(family_id: String) -> Dictionary:
	return families.get(family_id, {})


# =============================================================================
# HÀM LẤY HEAD GIA ĐÌNH (get_current_family_head)
# =============================================================================

func get_current_family_head(family_id: String) -> String:
	var family: Dictionary = families.get(family_id, {})
	if family.is_empty():
		return ""
	return family.get("current_head", "")


# =============================================================================
# HÀM LẤY THÀNH VIÊN (get_family_members)
# =============================================================================

func get_family_members(family_id: String) -> Array:
	var family: Dictionary = families.get(family_id, {})
	return family.get("members", [])


# =============================================================================
# HÀM LẤY THÀNH VIÊN SỐNG (get_alive_members)
# =============================================================================

func get_alive_members(family_id: String) -> Array:
	var members: Array = get_family_members(family_id)
	# Filter: chỉ lấy alive = true
	return members.filter(func(m: Dictionary) -> bool: return m.get("alive", false))


# =============================================================================
# HÀM ĐÁNH DẤU THÀNH VIÊN CHẾT (mark_family_member_dead)
# =============================================================================

func mark_family_member_dead(member_id: String, family_id: String) -> bool:
	var family: Dictionary = families.get(family_id, {})
	if family.is_empty():
		return false

	var members: Array = family["members"]
	for i: int in range(members.size()):
		var m_id: String = members[i].get("id", "")
		if m_id == member_id:
			members[i]["alive"] = false
			var dead_member: Dictionary = members[i]
			_on_member_death(family_id, dead_member)
			return true
	return false


# =============================================================================
# HÀM XỬ LÝ KHI THÀNH VIÊN CHẾT (_on_member_death)
# =============================================================================

func _on_member_death(family_id: String, dead_member: Dictionary) -> void:
	var family: Dictionary = families[family_id]
	var member_id: String = dead_member.get("id", "")

	# Nếu người chết là head gia đình -> tìm người kế thừa
	if family.get("current_head", "") == member_id:
		var successor_id: String = dead_member.get("successor", "")
		if successor_id != "":
			_promote_successor(family_id, member_id, successor_id)
		else:
			_promote_next_oldest(family_id, member_id)

	# Cập nhật trạng thái gia đình
	var alive: Array = get_alive_members(family_id)
	var alive_count: int = alive.size()
	if alive_count == 0:
		family["status"] = FamilyStatus.EXTINCT
	elif alive_count == 1:
		family["status"] = FamilyStatus.REDUCED
	else:
		family["status"] = FamilyStatus.SCATTERED

	# Lưu vào GameState
	var status_key: String = FamilyStatus.keys()[family["status"]]
	GameState.set_flag("family_%s_status" % family_id, status_key)
	var family_name: String = family.get("name", family_id)
	print("[FamilyRegistry] %s is now %s" % [family_name, family["status"]])


# =============================================================================
# HÀM THĂNG CHỨC NGƯỜI KẾ THỪA (_promote_successor)
# =============================================================================

func _promote_successor(family_id: String, old_id: String, new_id: String) -> void:
	families[family_id]["current_head"] = new_id
	var members: Array = families[family_id]["members"]
	for member_raw: Variant in members:
		var member: Dictionary = member_raw
		if member.get("id", "") == new_id:
			member["at_home"] = true
			GameState.set_flag("npc_%s_new_head" % new_id, true)
			GameState.set_flag("npc_%s_succeeded_from" % new_id, old_id)
			break


# =============================================================================
# HÀM THĂNG CHỨC NGƯỜI GIÀ NHẤT (_promote_next_oldest)
# =============================================================================

func _promote_next_oldest(family_id: String, dead_id: String) -> void:
	var alive_members: Array = get_alive_members(family_id)
	if alive_members.is_empty():
		return
	var new_head_id: String = alive_members[0].get("id", "")
	families[family_id]["current_head"] = new_head_id


# =============================================================================
# HÀM THAY THẾ THÀNH VIÊN (replace_family_member)
# =============================================================================

func replace_family_member(family_id: String, old_id: String, new_id: String) -> bool:
	var family: Dictionary = families.get(family_id, {})
	if family.is_empty():
		return false

	var members: Array = family["members"]
	for i: int in range(members.size()):
		var m_id: String = members[i].get("id", "")
		if m_id == old_id:
			members[i]["alive"] = false
			members[i]["at_home"] = false

	family["current_head"] = new_id
	GameState.set_flag("npc_%s_new_head" % new_id, true)
	GameState.set_flag("npc_%s_succeeded_from" % new_id, old_id)

	print("[FamilyRegistry] Replaced %s with %s in family %s" % [old_id, new_id, family_id])
	return true


# =============================================================================
# HÀM THÊM THÀNH VIÊN (add_family_member)
# =============================================================================

func add_family_member(family_id: String, member_data: Dictionary) -> bool:
	var family: Dictionary = families.get(family_id, {})
	if family.is_empty():
		return false
	var members: Array = family["members"]
	members.append(member_data)
	return true


# =============================================================================
# HÀM XÓA THÀNH VIÊN (remove_family_member)
# =============================================================================

func remove_family_member(family_id: String, member_id: String) -> bool:
	var family: Dictionary = families.get(family_id, {})
	if family.is_empty():
		return false
	var members: Array = family["members"]
	for i: int in range(members.size()):
		var m_id: String = members[i].get("id", "")
		if m_id == member_id:
			members.remove_at(i)
			return true
	return false


# =============================================================================
# HÀM KIỂM TRA TUYỆT TỰ (_is_family_extinct)
# =============================================================================

func is_family_extinct(family_id: String) -> bool:
	var family: Dictionary = families.get(family_id, {})
	if family.is_empty():
		return true
	return family.get("status", FamilyStatus.INTACT) == FamilyStatus.EXTINCT


# =============================================================================
# HÀM LẤY TRẠNG THÁI GIA ĐÌNH (get_family_status)
# =============================================================================

func get_family_status(family_id: String) -> String:
	var family: Dictionary = families.get(family_id, {})
	if family.is_empty():
		return "unknown"
	var status_key: String = FamilyStatus.keys()[family.get("status", FamilyStatus.INTACT)]
	return status_key


# =============================================================================
# HÀM LẤY TẤT CẢ GIA ĐÌNH (get_all_families)
# =============================================================================

func get_all_families() -> Array:
	return families.keys()


# =============================================================================
# HÀM LẤY THÔNG TIN DOANH NGHIỆP (get_family_business)
# =============================================================================

func get_family_business(family_id: String) -> Dictionary:
	var family: Dictionary = families.get(family_id, {})
	if family.is_empty():
		return {}
	return {
		"name": family.get("business_name", ""),
		"location": family.get("home_location", Vector2.ZERO),
		"current_head": family.get("current_head", ""),
		"status": family.get("status", FamilyStatus.INTACT),
	}


# =============================================================================
# HÀM KIỂM TRA DOANH NGHIỆP CÒN HOẠT ĐỘNG (is_business_operational)
# =============================================================================

func is_business_operational(family_id: String) -> bool:
	var business: Dictionary = get_family_business(family_id)
	if business.is_empty():
		return false
	if business.get("status", FamilyStatus.INTACT) == FamilyStatus.EXTINCT:
		return false
	var head_id: String = business.get("current_head", "")
	var family: Dictionary = families.get(family_id, {})
	var members: Array = family.get("members", [])
	for member_raw: Variant in members:
		var member: Dictionary = member_raw
		var m_id: String = member.get("id", "")
		var alive: bool = member.get("alive", false)
		if m_id == head_id and alive:
			return true
	return false


# =============================================================================
# HÀM LẤY SCENE CHO HEAD HIỆN TẠI (get_scene_for_current_head)
# =============================================================================

func get_scene_for_current_head(family_id: String) -> String:
	var head_id: String = get_current_family_head(family_id)
	var family: Dictionary = families.get(family_id, {})
	var members: Array = family.get("members", [])
	for member_raw: Variant in members:
		var member: Dictionary = member_raw
		if member.get("id", "") == head_id:
			return member.get("scene_path", "")
	return ""


# =============================================================================
# HÀM LẤY DIALOGUE CHO HEAD HIỆN TẠI (get_dialogue_for_current_head)
# =============================================================================

func get_dialogue_for_current_head(family_id: String) -> String:
	var head_id: String = get_current_family_head(family_id)
	var family: Dictionary = families.get(family_id, {})
	var members: Array = family.get("members", [])
	for member_raw: Variant in members:
		var member: Dictionary = member_raw
		if member.get("id", "") == head_id:
			var dialogue_id: String = member.get("dialogue_id", "generic_greeting")
			var status: String = GameState.get_flag("family_%s_status" % family_id, "")
			if status == "REDUCED":
				return dialogue_id + "_grief"
			return dialogue_id
	return "generic_greeting"


# =============================================================================
# HÀM LƯU TRẠNG THÁI GIA ĐÌNH (serialize_families)
# =============================================================================

func serialize_families() -> Dictionary:
	var serialized: Dictionary = {}
	for family_id: String in families:
		serialized[family_id] = families[family_id].duplicate(true)
	return serialized


# =============================================================================
# HÀM LOAD TRẠNG THÁI GIA ĐÌNH (load_families)
# =============================================================================

func load_families(data: Dictionary) -> void:
	families = data.duplicate(true)
