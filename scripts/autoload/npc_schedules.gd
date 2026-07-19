extends Node
# =============================================================================
# NPC SCHEDULES (Lịch trình NPC)
# =============================================================================
# Chức năng: Quản lý lịch trình của NPC (Dwarf Fortress style)
#
# Tính năng:
#   - Mỗi NPC có lịch trình riêng theo ngày trong tuần
#   - Lịch trình xác định NPC đi đâu, làm gì
#   - Dùng cho hệ thống world simulation khi player không online
#
# CẤU TRÚC LỊCH TRÌNH:
#   - day_of_week: ngày trong tuần (0-6, Chủ Nhật = 0)
#   - departure_time: giờ bắt đầu
#   - return_time: giờ về
#   - type: loại hoạt động
#   - chain_id: sự kiện liên quan
#
# CÁCH SỬ DỤNG:
#   NPCSchedules.get_todays_schedule("shopkeeper_father") - lấy lịch hôm nay
#   NPCSchedules.get_all_schedules_for_day(5) - xem ai có lịch thứ 7
# =============================================================================

# =============================================================================
# CÁC BIẾN
# =============================================================================

# Lưu trữ lịch trình của tất cả NPC
# Key: NPC ID, Value: Array các lịch trình
var schedules: Dictionary = {}


# =============================================================================
# HÀM KHỞI TẠO (_ready)
# =============================================================================

func _ready() -> void:
	_build_default_schedules()
	print("[NPCSchedules] Ready — %d schedules loaded." % schedules.size())


# =============================================================================
# HÀM XÂY DỰNG LỊCH TRÌNH MẶC ĐỊNH (_build_default_schedules)
# =============================================================================
# Định nghĩa lịch trình cho các NPC mặc định

func _build_default_schedules() -> void:
	schedules = {
		# =================================================================
		# ÔNG VOSS (Shopkeeper Father) - Đi núi vào thứ 7
		# =================================================================
		"shopkeeper_father": [
			{
				"id": "mountain_trip",           # Mã lịch trình
				"day_of_week": 5,                 # Thứ 7 (0=CN, 1=T2...)
				"type": "mountain",               # Loại: đi núi
				"departure_time": 7.0,            # Đi lúc 7:00 sáng
				"return_time": 18.0,             # Về lúc 18:00
				"risk_activity": "mountain_trip",  # Hoạt động nguy hiểm
				"description": "Voss climbs the mountain every Saturday.",
				"chain_id": "shopkeeper_mountain",  # Chain sự kiện
				"required_quest": "",             # Không cần quest
			},
		],
		
		# =================================================================
		# BÀ MARTHA (Farmer Mother) - Đi chợ vào thứ 3
		# =================================================================
		"farmer_mother": [
			{
				"id": "market_day",
				"day_of_week": 2,                 # Thứ 3
				"type": "market",
				"departure_time": 8.0,
				"return_time": 15.0,
				"risk_activity": "river_crossing",  # Qua sông nguy hiểm
				"description": "Martha goes to the market every Tuesday.",
				"chain_id": "",
				"required_quest": "",
			},
		],
		
		# =================================================================
		# ÔNG HANZ (Hermit) - Đi rừng vào thứ 4
		# =================================================================
		"hermit": [
			{
				"id": "forest_walk",
				"day_of_week": 3,                 # Thứ 4
				"type": "forest",
				"departure_time": 6.0,            # Đi sớm 6:00
				"return_time": 17.0,
				"risk_activity": "forest_walk",
				"description": "Old Hanz walks into the forest every Wednesday.",
				"chain_id": "",
				"required_quest": "",
			},
		],
		
		# =================================================================
		# VOSS CON (Shopkeeper Son) - Đi ban đêm thứ 5
		# =================================================================
		"shopkeeper_son": [
			{
				"id": "night_walk",
				"day_of_week": 4,                 # Thứ 5
				"type": "night",
				"departure_time": 21.0,          # Đi lúc 21:00 (9 giờ tối)
				"return_time": 23.0,
				"risk_activity": "night_walk",
				"description": "Young Voss wanders at night.",
				"chain_id": "",
				"required_quest": "",
			},
		],
	}


# =============================================================================
# HÀM LẤY TẤT CẢ LỊCH TRÌNH NPC (get_schedules)
# =============================================================================
# Lấy tất cả lịch trình của một NPC
#
# Tham số:
#   npc_id: String - mã NPC
#
# Trả về: Array các lịch trình

func get_schedules(npc_id: String) -> Array:
	var raw: Array = schedules.get(npc_id, [])
	return raw


# =============================================================================
# HÀM LẤY LỊCH TRÌNH HÔM NAY (get_todays_schedule)
# =============================================================================
# Lấy các lịch trình sẽ xảy ra HÔM NAY cho một NPC
# Chỉ trả về lịch trình chưa bắt đầu (departure_time > current_time)
#
# Tham số:
#   npc_id: String - mã NPC
#
# Trả về: Array các lịch trình hôm nay

func get_todays_schedule(npc_id: String) -> Array:
	# Lấy tất cả lịch trình NPC
	var all_schedules: Array = get_schedules(npc_id)
	
	# Tính ngày trong tuần hiện tại (0-6)
	var current_day_of_week: int = (GameState.current_day - 1) % 7
	var current_time: float = GameState.current_time

	var todays: Array = []
	
	# Duyệt các lịch trình
	for schedule: Dictionary in all_schedules:
		var day_of_week: int = schedule.get("day_of_week", -1)
		var departure_time: float = schedule.get("departure_time", 0.0)
		
		# Lịch trình hôm nay VÀ chưa bắt đầu
		if day_of_week == current_day_of_week and departure_time > current_time:
			todays.append(schedule)

	return todays


# =============================================================================
# HÀM KIỂM TRA CÓ LỊCH SẮP TỚI (has_upcoming_schedule)
# =============================================================================
# Kiểm tra NPC có lịch trình sắp tới không
#
# Tham số:
#   npc_id: String - mã NPC
#   within_hours: float - trong bao nhiêu giờ tới (mặc định 24)
#
# Trả về: true nếu có lịch trình sắp tới

func has_upcoming_schedule(npc_id: String, within_hours: float = 24.0) -> bool:
	return not get_todays_schedule(npc_id).is_empty()


# =============================================================================
# HÀM THÊM LỊCH TRÌNH (add_schedule)
# =============================================================================
# Thêm lịch trình mới cho NPC (dùng khi quest thêm lịch trình)
#
# Tham số:
#   npc_id: String - mã NPC
#   schedule: Dictionary - lịch trình cần thêm

func add_schedule(npc_id: String, schedule: Dictionary) -> void:
	# Tạo array nếu NPC chưa có lịch trình
	if not schedules.has(npc_id):
		schedules[npc_id] = []
	
	# Thêm vào
	var existing: Array = schedules[npc_id]
	existing.append(schedule)
	schedules[npc_id] = existing


# =============================================================================
# HÀM XÓA LỊCH TRÌNH (remove_schedule)
# =============================================================================
# Xóa lịch trình của NPC
#
# Tham số:
#   npc_id: String - mã NPC
#   schedule_id: String - mã lịch trình cần xóa

func remove_schedule(npc_id: String, schedule_id: String) -> void:
	if schedules.has(npc_id):
		var npc_schedules: Array = schedules[npc_id]
		for i: int in range(npc_schedules.size()):
			var sched_id: String = npc_schedules[i].get("id", "")
			if sched_id == schedule_id:
				npc_schedules.remove_at(i)
				return


# =============================================================================
# HÀM LẤY MÔ TẢ LỊCH TRÌNH (get_schedule_description)
# =============================================================================
# Lấy text mô tả tất cả lịch trình của NPC

func get_schedule_description(npc_id: String) -> String:
	var descs: Array = []
	for schedule: Dictionary in get_schedules(npc_id):
		descs.append(schedule.get("description", ""))
	return "\n".join(descs)


# =============================================================================
# HÀM LẤY TẤT CẢ LỊCH TRÌNH TRONG NGÀY (get_all_schedules_for_day)
# =============================================================================
# Lấy tất cả lịch trình của TẤT CẢ NPC trong một ngày cụ thể
# Dùng để xem ai có lịch trình vào thứ X
#
# Tham số:
#   day_of_week: int - ngày trong tuần (0-6)
#
# Trả về: Array các Dictionary chứa npc_id và schedule

func get_all_schedules_for_day(day_of_week: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	
	# Duyệt tất cả NPC
	for npc_id: String in schedules:
		var npc_schedules: Array = schedules[npc_id]
		
		# Duyệt lịch trình của NPC
		for schedule: Dictionary in npc_schedules:
			# Nếu đúng ngày
			if schedule.get("day_of_week", -1) == day_of_week:
				result.append({
					"npc_id": npc_id,           # Tên NPC
					"schedule": schedule,        # Thông tin lịch trình
				})
	
	return result
