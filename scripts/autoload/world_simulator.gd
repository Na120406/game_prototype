extends Node
# =============================================================================
# WORLD SIMULATOR (Mô phỏng Thế giới)
# =============================================================================
# Chức năng: Mô phỏng thế giới khi người chơi không online
#
# Đặc điểm quan trọng:
#   - Khi player ngủ/đi xa, thế giới vẫn tiếp tục hoạt động
#   - NPC vẫn làm lịch trình của họ
#   - Thời tiết vẫn thay đổi
#   - Events vẫn xảy ra
#   - Khi player quay lại, world đã thay đổi
#
# Tính năng:
#   - Mô phỏng ngày trôi qua
#   - Đánh giá lịch trình NPC
#   - Tính toán risk cho các hoạt động
#   - Kích hoạt event chains
#   - Log lại tất cả sự kiện
#
# CÁCH SỬ DỤNG:
#   WorldSimulator đang chạy ngầm khi game chạy
#   Các hệ thống khác gọi để lấy thông tin world state
# =============================================================================

# =============================================================================
# TÍN HIỆU (SIGNALS)
# =============================================================================

# Phát ra khi trạng thái world thay đổi
signal world_state_updated(flags: Dictionary)


# =============================================================================
# CÁC BIẾN THEO DÕI
# =============================================================================

# Số ngày đã mô phỏng
var simulation_day_count: int = 0

# Log tất cả sự kiện xảy ra trong simulation
var _simulation_log: Array[Dictionary] = []


# =============================================================================
# HÀM KHỞI TẠO (_ready)
# =============================================================================

func _ready() -> void:
	_connect_world_signals()  # Kết nối với các signal
	print("[WorldSimulator] Ready — world ticks only while game is running.")


# =============================================================================
# HÀM KẾT NỐI SIGNALS (_connect_world_signals)
# =============================================================================
# Lắng nghe TimeManager để biết khi nào ngày mới bắt đầu

func _connect_world_signals() -> void:
	TimeManager.day_changed.connect(_on_day_changed)


# =============================================================================
# HÀM XỬ LÝ NGÀY MỚI (_on_day_changed)
# =============================================================================
# Gọi khi chuyển sang ngày mới

func _on_day_changed(new_day: int) -> void:
	_simulate_day(new_day)


# =============================================================================
# HÀM MÔ PHỎNG NGÀY (_simulate_day)
# =============================================================================
# Mô phỏng một ngày trong thế giới
# Xử lý: thời tiết, lịch trình NPC, events, chains

func _simulate_day(day: int) -> void:
	simulation_day_count += 1
	var triggered_events: Array[Dictionary] = []

	# =================================================================
	# 1. CẬP NHẬT THỜI TIẾT
	# =================================================================
	var weather_result: Dictionary = WeatherSystem.simulate_day(day)
	triggered_events.append({"type": "weather", "data": weather_result})

	# =================================================================
	# 2. ĐÁNH GIÁ LỊCH TRÌNH NPC
	# =================================================================
	var scheduled_npc_events: Array[Dictionary] = _evaluate_npc_schedules(day)
	for ev: Dictionary in scheduled_npc_events:
		triggered_events.append(ev)

	# =================================================================
	# 3. ĐÁNH GIÁ WORLD EVENTS
	# =================================================================
	var world_events: Array[Dictionary] = _evaluate_world_events(day)
	for ev: Dictionary in world_events:
		triggered_events.append(ev)

	# =================================================================
	# 4. CẬP NHẬT EVENT CHAINS ĐANG HOẠT ĐỘNG
	# =================================================================
	var chain_updates: Array[Dictionary] = _update_active_chains()
	for ev: Dictionary in chain_updates:
		triggered_events.append(ev)

	# =================================================================
	# 5. LOG SỰ KIỆN
	# =================================================================
	_simulation_log.append({
		"day": day,
		"weather": weather_result.get("weather", "clear"),
		"events": triggered_events,
	})

	# Phát signal thay đổi
	world_state_updated.emit(_summarize_flags())
	
	print("[WorldSimulator] Day %d — %d events." % [day, triggered_events.size()])


# =============================================================================
# HÀM ĐÁNH GIÁ LỊCH TRÌNH NPC (_evaluate_npc_schedules)
# =============================================================================
# Xử lý lịch trình của tất cả NPC trong ngày
# Quan trọng cho hệ thống Dwarf Fortress-style

func _evaluate_npc_schedules(day: int) -> Array[Dictionary]:
	var triggered: Array[Dictionary] = []

	# Lấy tất cả gia đình
	var families: Array = FamilyRegistry.get_all_families()
	
	# Duyệt từng gia đình
	for family_id_raw: Variant in families:
		var family_id: String = family_id_raw
		var members: Array = FamilyRegistry.get_family_members(family_id)
		
		# Duyệt từng thành viên
		for member_raw: Variant in members:
			var member: Dictionary = member_raw
			
			# Bỏ qua nếu đã chết
			if not member.get("alive", true):
				continue

			var npc_id: String = member.get("id", "")
			var schedules: Array = NPCSchedules.get_schedules(npc_id)
			
			# Bỏ qua nếu không có lịch trình
			if schedules.is_empty():
				continue

			# Duyệt lịch trình
			for schedule_raw: Variant in schedules:
				var schedule: Dictionary = schedule_raw
				
				# Kiểm tra đúng ngày trong tuần
				# (day - 1) % 7 để tính ngày trong tuần
				if schedule.get("day_of_week", -1) == (day - 1) % 7:
					
					# =================================================================
					# XỬ LÝ CHUYẾN ĐI NÚI
					# =================================================================
					if schedule.get("type", "") == "mountain":
						# Kiểm tra player có hộ tống không
						var player_escorted: bool = _check_player_escort(npc_id, day)
						
						# Tạo context cho risk calculation
						var context: Dictionary = {
							"npc_id": npc_id,
							"family_id": family_id,
							"day": day,
							"player_escorted": player_escorted,
						}
						
						# Tính risk
						var risk: float = RiskCalculator.calculate_risk(npc_id, "mountain_trip", context)
						print("[WorldSimulator] NPC '%s' scheduled mountain trip. Risk: %.0f%%" % [npc_id, risk * 100.0])
						
						# Ghi nhận sự kiện
						triggered.append({
							"type": "npc_scheduled",
							"npc_id": npc_id,
							"family_id": family_id,
							"schedule_type": "mountain",
							"risk": risk,
							"context": context,
						})

						# Nếu risk cao -> kích hoạt chain
						if risk >= 0.3:
							EventChainEngine.trigger_chain("shopkeeper_mountain", context)

	return triggered


# =============================================================================
# HÀM KIỂM TRA HỘ TỐNG (_check_player_escort)
# =============================================================================
# Kiểm tra player có đang hộ tống NPC không

func _check_player_escort(npc_id: String, day: int) -> bool:
	# Kiểm tra flag trong GameState
	return GameState.get_flag("quest_escorted_%s_day_%d" % [npc_id, day])


# =============================================================================
# HÀM ĐÁNH GIÁ WORLD EVENTS (_evaluate_world_events)
# =============================================================================
# Xử lý các sự kiện thế giới định kỳ

func _evaluate_world_events(day: int) -> Array[Dictionary]:
	var triggered: Array[Dictionary] = []

	# =================================================================
	# LỄ HỘI - MỖI 7 NGÀY
	# =================================================================
	if day % 7 == 0 and day > 1:
		triggered.append({"type": "festival", "day": day})
		EventChainEngine.trigger_chain("festival_day", {"day": day})

	# =================================================================
	# CHUYỂN MÙA - MỖI 30 NGÀY
	# =================================================================
	if day % 30 == 0 and day > 30:
		triggered.append({"type": "season_transition", "day": day})
		WeatherSystem.advance_season()
		EventChainEngine.trigger_chain("harvest_blight", {"day": day, "season": WeatherSystem.current_season})

	return triggered


# =============================================================================
# HÀM CẬP NHẬT CHAINS ĐANG HOẠT ĐỘNG (_update_active_chains)
# =============================================================================

func _update_active_chains() -> Array[Dictionary]:
	var updates: Array[Dictionary] = []
	var chain_ids: Array = EventChainEngine.get_all_active_chains()
	for chain_id_raw: Variant in chain_ids:
		var chain_id: String = chain_id_raw
		updates.append({
			"type": "chain_update",
			"chain_id": chain_id,
			"day": GameState.current_day,
		})
	return updates


# =============================================================================
# HÀM TÓM TẮT FLAGS (_summarize_flags)
# =============================================================================
# Tạo bản tóm tắt trạng thái world

func _summarize_flags() -> Dictionary:
	return {
		"shop_open": GameState.get_flag("shop_open", true),
		"new_shopkeeper": GameState.get_flag("new_shopkeeper", false),
		"food_shortage": GameState.get_flag("food_shortage", false),
		"strange_events": GameState.get_flag("strange_events_active", false),
		"anomaly_weather": WeatherSystem.anomaly_weather_active,
	}


# =============================================================================
# HÀM LẤY LOG SIMULATION (get_simulation_log)
# =============================================================================

func get_simulation_log() -> Array:
	return _simulation_log.duplicate()


# =============================================================================
# HÀM XÓA LOG (_clear_simulation_log)
# =============================================================================

func clear_simulation_log() -> void:
	_simulation_log.clear()


# =============================================================================
# HÀM LẤY SỰ KIỆN NGÀY CỤ THỂ (get_events_for_day)
# =============================================================================

func get_events_for_day(day: int) -> Array[Dictionary]:
	for entry_raw: Variant in _simulation_log:
		var entry: Dictionary = entry_raw
		if entry.get("day", 0) == day:
			return entry.get("events", [])
	return []


# =============================================================================
# HÀM ÉP KÍCH HOẠT EVENT (force_trigger_event)
# =============================================================================
# Kích hoạt event cụ thể (cho debug hoặc quest)

func force_trigger_event(event_id: String, context: Dictionary = {}) -> void:
	match event_id:
		"shopkeeper_mountain":
			EventChainEngine.trigger_chain("shopkeeper_mountain", context)
		"festival":
			EventChainEngine.trigger_chain("festival_day", context)
		"harvest_blight":
			EventChainEngine.trigger_chain("harvest_blight", context)
