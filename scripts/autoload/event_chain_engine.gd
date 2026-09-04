extends Node
# =============================================================================
# EVENT CHAIN ENGINE (Máy Sự kiện Liên kết)
# =============================================================================
# Chức năng: Quản lý chuỗi sự kiện phức tạp trong game
#
# Event Chain là gì?
#   - Một chuỗi sự kiện có nhiều bước (steps)
#   - Mỗi bước có thể có hành động và hệ quả
#   - Có thể rẽ nhánh dựa trên điều kiện
#   - Kết quả có thể: SAFE, INJURED, DEAD, MISSED, DELAYED
#
# Ví dụ chain "shopkeeper_mountain":
#   1. Step 0: NPC rời nhà (delay 0)
#   2. Step 1: NPC leo núi (delay 2)
#   3. Step 2: Resolve outcome - tung xíu xem kết quả (delay 5)
#   4. Step 3: NPC về hoặc không (delay 10)
#
# CÁCH SỬ DỤNG:
#   EventChainEngine.trigger_chain("shopkeeper_mountain", context) - bắt đầu chain
#   EventChainEngine.is_chain_active("shopkeeper_mountain") - kiểm tra đang chạy
# =============================================================================

# =============================================================================
# TÍN HIỆU (SIGNALS)
# =============================================================================

signal event_chain_started(chain_id: String, root_event: String)
signal event_chain_step(chain_id: String, step_index: int, step_data: Dictionary)
signal event_chain_completed(chain_id: String)
signal event_chain_aborted(chain_id: String, reason: String)
signal branch_triggered(chain_id: String, branch_id: String, branch_data: Dictionary)
signal player_intervention_detected(chain_id: String, intervention_type: String)


# =============================================================================
# ENUM - TRẠNG THÁI CHAIN
# =============================================================================

enum ChainState {
	DORMANT,   # Chưa kích hoạt
	ACTIVE,    # Đang chạy
	PAUSED,    # Tạm dừng
	COMPLETED, # Hoàn thành
	ABORTED    # Bị hủy
}

enum Outcome {
	NONE,     # Không có
	SAFE,     # An toàn
	INJURED,  # Bị thương
	DEAD,     # Chết
	MISSED,   # Bỏ lỡ
	DELAYED,  # Bị trì hoãn
	SEVERELY_INJURED,  # Bị thương nặng (feature Voss mountain)
}

# =============================================================================
# ENUM - CÁCH PLAYER PHÁT HIỆN EVENT (DiscoveryMode)
# =============================================================================
# UNSEEN            - Player không biết gì, event tự chạy (Branch A)
# INVITED           - Player được Vos rủ đi cùng tại shop (Branch B)
# MOUNTAIN_ENCOUNTER- Player tình cờ/ cố ý lên núi đúng ngày (Branch C)

enum DiscoveryMode {
	UNSEEN,
	INVITED,
	MOUNTAIN_ENCOUNTER
}

# =============================================================================
# ENUM - PHA CỦA VOSS MOUNTAIN EVENT (VossPhase)
# =============================================================================
# SCHEDULED     -> Đã lên lịch, chưa xảy ra
# ON_MOUNTAIN   -> Vos đang trên núi (sau 11:00)
# FALLING       -> Vos ngã (16:00)
# RESCUE_WINDOW -> Cửa sổ cứu hộ (player can thiệp)
# RESOLVED      -> Event kết thúc, outcome đã chốt

enum VossPhase {
	SCHEDULED,
	ON_MOUNTAIN,
	FALLING,
	RESCUE_WINDOW,
	RESOLVED
}

# Bảng transition hợp lệ giữa các phase
const VOSS_TRANSITIONS: Dictionary = {
	"SCHEDULED": ["ON_MOUNTAIN"],
	"ON_MOUNTAIN": ["FALLING"],
	"FALLING": ["RESCUE_WINDOW", "RESOLVED"],
	"RESCUE_WINDOW": ["RESOLVED"],
	"RESOLVED": [],
}

# Các key bắt buộc trong context khi trigger chain
const VOSS_CONTEXT_REQUIRED_KEYS: Array[String] = [
	"event_day",
	"departure_time",
	"fall_time",
	"npc_id",
	"family_id",
	"discovery_mode",
]

# Bốn outcome hợp lệ riêng của chuỗi Voss. Outcome legacy khác vẫn được giữ
# trong enum tổng để không phá các chain prototype hiện có, nhưng không được dùng
# trong shopkeeper_mountain.
const VOSS_OUTCOME_NAMES: Array[String] = [
	"SAFE",
	"INJURED",
	"SEVERELY_INJURED",
	"DEAD",
]


# =============================================================================
# HẰNG SỐ
# =============================================================================

# Số bước tối đa trong một chain
const MAX_CHAIN_LENGTH: int = 20


# =============================================================================
# CÁC BIẾN THEO DÕI
# =============================================================================

# Các chain đang chạy
var active_chains: Dictionary = {}

# Các chain đã hoàn thành
var completed_chains: Array[String] = []

# Định nghĩa tất cả chain
var chain_definitions: Dictionary = {}

# Các sự kiện đã lên lịch
var scheduled_events: Array[Dictionary] = []


# =============================================================================
# HÀM KHỞI TẠO (_ready)
# =============================================================================

func _ready() -> void:
	_build_chain_library()
	if not GameState.day_changed.is_connected(_on_day_changed):
		GameState.day_changed.connect(_on_day_changed)
	print("[EventChainEngine] Ready — %d chain definitions loaded." % chain_definitions.size())

func _on_day_changed(_new_day: int) -> void:
	_process_scheduled_events()


# =============================================================================
# HÀM CẬP NHẬT MỖI FRAME (_process)
# =============================================================================

func _process(_delta: float) -> void:
	# Chain delays represent in-game days, not rendered frames.
	return


# =============================================================================
# HÀM XỬ LÝ SỰ KIỆN ĐÃ LÊN LỊCH (_process_scheduled_events)
# =============================================================================

func _process_scheduled_events() -> void:
	var to_remove: Array[int] = []
	for i: int in range(scheduled_events.size()):
		var ev: Dictionary = scheduled_events[i]
		if _is_chain_paused(ev.get("chain_id", "")):
			continue
		if GameState.current_day < int(ev.get("scheduled_day", GameState.current_day)):
			continue
		_execute_scheduled_event(ev)
		to_remove.append(i)
	for i: int in range(to_remove.size() - 1, -1, -1):
		scheduled_events.remove_at(to_remove[i])


# =============================================================================
# HÀM XÂY DỰNG THƯ VIỆN CHAIN (_build_chain_library)
# =============================================================================
# Định nghĩa tất cả chain trong game

func _build_chain_library() -> void:
	chain_definitions = {
		# =================================================================
		# CHAIN: SHOPKEEPER MOUNTAIN (Chuyến đi núi của ông chủ cửa hàng)
		# =================================================================
		"shopkeeper_mountain": {
			"id": "shopkeeper_mountain",
			"name": "Shopkeeper's Mountain Trip",
			"trigger_condition": "npc_schedule_mountain_day",
			"weather_sensitive": true,  # Thời tiết ảnh hưởng
			"base_risk": 0.0,
			"root_event": "shopkeeper_ascending",
			# Các kết quả có thể xảy ra
			"outcomes": {
				"safe": {
					"weight": 0.70,           # 70% khả năng
					"roll_threshold": 0.70,
					"consequences": [],         # Không có hệ quả
					"message": "Shopkeeper returned safely.",
				},
				"delayed": {
					"weight": 0.10,           # 10% khả năng
					"roll_threshold": 0.80,
					"consequences": ["shop_late_open"],  # Cửa hàng mở muộn
					"message": "Shopkeeper returned late.",
				},
				"injured": {
					"weight": 0.15,           # 15% khả năng
					"roll_threshold": 0.95,
					"consequences": ["shopkeeper_injured", "shop_closed_days"],
					"message": "Shopkeeper was injured on the mountain.",
				},
				"dead": {
					"weight": 0.05,            # 5% khả năng
					"roll_threshold": 1.0,
					"consequences": ["shopkeeper_dead", "shop_closes", "funeral_scheduled", "son_takes_over"],
					"message": "Shopkeeper did not return.",
				},
			},
			# Các nhánh điều kiện
			"branches": {
				"injured_player_escorted": {
					"condition": "player_escorted",     # Có player hộ tống
					"modifiers": {
						"injured": -0.08,         # Giảm khả năng bị thương
						"dead": -0.03,             # Giảm khả năng chết
						"safe": 0.11,               # Tăng khả năng an toàn
					},
				},
				"injured_bad_weather": {
					"condition": "weather_storm",        # Trời bão
					"modifiers": {
						"injured": 0.15,
						"dead": 0.1,
					},
				},
				"dead_bad_weather": {
					"condition": "weather_heavy_rain",   # Mưa to
					"modifiers": {
						"injured": 0.2,
						"dead": 0.2,
					},
				},
			},
			# Các bước trong chain
			"chain_steps": [
				{"delay": 0, "step": "npc_departed", "action": "npc_leaves_home"},
				{"delay": 2, "step": "npc_ascending", "action": "npc_on_mountain"},
				{"delay": 5, "step": "outcome_resolved", "action": "resolve_outcome"},
				{"delay": 10, "step": "return_process", "action": "npc_returns_or_not"},
			],
		},
		
		# =================================================================
		# CHAIN: FESTIVAL DAY (Ngày lễ hội)
		# =================================================================
		"festival_day": {
			"id": "festival_day",
			"name": "Village Festival",
			"trigger_condition": "calendar_festival_day",
			"weather_sensitive": true,
			"base_risk": 0.0,
			"root_event": "festival_begins",
			"outcomes": {
				"proceeds": {
					"weight": 0.65,
					"roll_threshold": 0.65,
					"consequences": [],
					"message": "Festival proceeded normally.",
				},
				"rain_cancel": {
					"weight": 0.20,
					"roll_threshold": 0.85,
					"consequences": ["festival_cancelled", "villagers_disappointed"],
					"message": "Heavy rain cancelled the festival.",
				},
				"cancelled_mysterious": {
					"weight": 0.15,
					"roll_threshold": 1.0,
					"consequences": ["festival_cancelled_mystery", "strange_events"],
					"message": "The festival was cancelled for unknown reasons.",
				},
			},
			"branches": {},
			"chain_steps": [
				{"delay": 0, "step": "festival_setup", "action": "villagers_prepare"},
				{"delay": 3, "step": "festival_start", "action": "festival_begins"},
				{"delay": 8, "step": "outcome_resolved", "action": "resolve_outcome"},
			],
		},
		
		# =================================================================
		# CHAIN: HARVEST BLIGHT (Bệnh cây trồng)
		# =================================================================
		"harvest_blight": {
			"id": "harvest_blight",
			"name": "Crop Blight",
			"trigger_condition": "season_autumn_approaching",
			"weather_sensitive": false,
			"base_risk": 0.0,
			"root_event": "blight_signs_appear",
			"outcomes": {
				"healthy": {
					"weight": 0.50,
					"roll_threshold": 0.50,
					"consequences": [],
					"message": "Harvest was good.",
				},
				"partial_blight": {
					"weight": 0.35,
					"roll_threshold": 0.85,
					"consequences": ["crops_reduced", "food_shortage_warning"],
					"message": "Some crops were lost to blight.",
				},
				"total_blight": {
					"weight": 0.15,
					"roll_threshold": 1.0,
					"consequences": ["crops_destroyed", "food_shortage", "villagers_leaving"],
					"message": "All crops were destroyed by blight.",
				},
			},
			"branches": {},
			"chain_steps": [
				{"delay": 0, "step": "blight_signs", "action": "signs_noticed"},
				{"delay": 5, "step": "blight_spread", "action": "spreads_or_not"},
				{"delay": 10, "step": "harvest_time", "action": "harvest_assessed"},
			],
		},
	}


# =============================================================================
# HÀM KÍCH HOẠT CHAIN (trigger_chain)
# =============================================================================

func trigger_chain(chain_id: String, context: Dictionary = {}) -> bool:
	if not chain_definitions.has(chain_id):
		push_error("[EventChainEngine] Unknown chain: %s" % chain_id)
		return false

	if active_chains.has(chain_id):
		return false

	# Chuẩn hóa và kiểm tra context riêng cho chain Voss trước khi tạo state.
	# Các chain cũ khác vẫn giữ contract Dictionary hiện tại.
	if chain_id == "shopkeeper_mountain":
		if not context.has("npc_id") or not context.has("family_id"):
			push_warning("[EventChainEngine] Context Voss thiếu npc_id hoặc family_id — không trigger.")
			return false
		context = _normalize_voss_context(context)
		if not validate_voss_context(context):
			push_warning("[EventChainEngine] Context Voss không hợp lệ — không trigger.")
			return false

	# Voss mountain event chỉ chạy MỘT lần trong save: sau khi RESOLVED không
	# được re-trigger dù context có được đưa lại từ branch khác.
	if chain_id == "shopkeeper_mountain" and is_voss_event_resolved():
		push_warning("[EventChainEngine] Chain '%s' đã resolved — không re-trigger." % chain_id)
		return false

	# Chỉ chain Voss là one-shot. Các chain world khác có thể lặp theo lịch
	# (ví dụ festival/blight) và không được dùng completed_chains để chặn chung.
	if chain_id == "shopkeeper_mountain" and chain_id in completed_chains:
		return false

	var def: Dictionary = chain_definitions[chain_id]
	var chain: Dictionary = {
		"id": chain_id,
		"state": ChainState.ACTIVE,
		"context": context,
		"current_step": 0,
		"rolls_made": {},
		"active_branch": "",
		"consequences_applied": [],
		"intervention_active": false,
	}

	active_chains[chain_id] = chain
	_schedule_chain_steps(chain_id, def)
	# Execute zero-day trigger steps immediately; later steps wait for day_changed.
	_process_scheduled_events()
	var root_event: String = def.get("root_event", "")
	event_chain_started.emit(chain_id, root_event)
	print("[EventChainEngine] Chain started: %s" % chain_id)
	return true


# =============================================================================
# HÀM LÊN LỊCH CÁC BƯỚC (_schedule_chain_steps)
# =============================================================================

func _schedule_chain_steps(chain_id: String, def: Dictionary) -> void:
	var steps: Array = def.get("chain_steps", [])
	for step_data: Dictionary in steps:
		scheduled_events.append({
			"chain_id": chain_id,
			"step": step_data.get("step", ""),
			"action": step_data.get("action", ""),
			"delay": step_data.get("delay", 0),
			"scheduled_day": GameState.current_day + maxi(0, int(step_data.get("delay", 0))),
			"executed": false,
		})


# =============================================================================
# HÀM THỰC HIỆN SỰ KIỆN ĐÃ LÊN LỊCH (_execute_scheduled_event)
# =============================================================================

func _execute_scheduled_event(ev: Dictionary) -> void:
	var chain_id: String = ev.get("chain_id", "")
	if not active_chains.has(chain_id):
		return

	var step: String = ev.get("step", "")
	var action: String = ev.get("action", "")
	var def: Dictionary = chain_definitions[chain_id]
	var chain: Dictionary = active_chains[chain_id]

	match action:
		"resolve_outcome":
			_resolve_outcome(chain_id)
		"npc_returns_or_not":
			_finalize_npc_return(chain_id)
		"npc_leaves_home":
			_apply_step_effect(chain_id, step, "npc_left_home")
		"npc_on_mountain":
			_apply_step_effect(chain_id, step, "npc_mountain_ascent")
		"harvest_assessed":
			_resolve_outcome(chain_id)

	event_chain_step.emit(chain_id, chain["current_step"], {"step": step, "action": action})
	chain["current_step"] += 1

	var chain_steps: Array = def.get("chain_steps", [])
	if chain["current_step"] >= chain_steps.size():
		_complete_chain(chain_id)


# =============================================================================
# HÀM TÍNH TOÁN KẾT QUẢ (_resolve_outcome)
# =============================================================================

func _resolve_outcome(chain_id: String) -> void:
	var def: Dictionary = chain_definitions[chain_id]
	var chain: Dictionary = active_chains[chain_id]
	var context: Dictionary = chain.get("context", {})

	# Lấy trọng số các kết quả
	var outcome_weights: Dictionary = {}
	var outcomes: Dictionary = def.get("outcomes", {})
	for key: String in outcomes:
		var weight: float = outcomes[key].get("weight", 0.0)
		outcome_weights[key] = weight

	# Áp dụng các modifier từ nhánh
	outcome_weights = _apply_branch_modifiers(chain_id, outcome_weights)
	
	# Normalize trọng số để tổng = 1.0
	var total: float = 0.0
	for w: float in outcome_weights.values():
		total += w
	if total <= 0.0:
		push_warning("[EventChainEngine] No valid outcome weights for chain '%s'; using safe." % chain_id)
		outcome_weights = {"safe": 1.0}
		total = 1.0
	for key: String in outcome_weights:
		outcome_weights[key] = outcome_weights[key] / total

	# Tung xíu để chọn kết quả
	var roll: float = randf()
	var cumulative: float = 0.0
	var chosen_outcome: String = "safe"

	for outcome_key: String in outcome_weights:
		cumulative += outcome_weights[outcome_key]
		if roll <= cumulative:
			chosen_outcome = outcome_key
			break

	chain["rolls_made"]["outcome"] = chosen_outcome
	chain["rolls_made"]["roll_value"] = roll

	var outcome_data: Dictionary = def["outcomes"][chosen_outcome]
	print("[EventChainEngine] Chain '%s' outcome: %s (roll=%.2f)" % [chain_id, chosen_outcome, roll])

	# Áp dụng hệ quả
	var consequences: Array = outcome_data.get("consequences", [])
	for consequence_id: String in consequences:
		_apply_consequence(consequence_id, chain_id, context)
		chain["consequences_applied"].append(consequence_id)

	# Kích hoạt event
	var event_id: String = chain_id + "_" + chosen_outcome
	EventManager.trigger_event(event_id)


# =============================================================================
# HÀM ÁP DỤNG MODIFIER NHÁNH (_apply_branch_modifiers)
# =============================================================================

func _apply_branch_modifiers(chain_id: String, weights: Dictionary) -> Dictionary:
	var def: Dictionary = chain_definitions[chain_id]
	var branches: Dictionary = def.get("branches", {})
	var chain: Dictionary = active_chains[chain_id]
	var context: Dictionary = chain.get("context", {})

	var modified: Dictionary = weights.duplicate(true)

	for branch_id: String in branches:
		var branch: Dictionary = branches[branch_id]
		var condition: String = branch.get("condition", "")
		var condition_met: bool = _check_branch_condition(condition, context)

		if condition_met:
			chain["active_branch"] = branch_id
			var modifiers: Dictionary = branch.get("modifiers", {})
			for outcome_key: String in modifiers:
				if modified.has(outcome_key):
					modified[outcome_key] = modified[outcome_key] + modifiers[outcome_key]
					modified[outcome_key] = maxf(0.0, modified[outcome_key])
			branch_triggered.emit(chain_id, branch_id, branch)

	return modified


# =============================================================================
# HÀM KIỂM TRA ĐIỀU KIỆN NHÁNH (_check_branch_condition)
# =============================================================================

func _check_branch_condition(condition: String, context: Dictionary) -> bool:
	match condition:
		"player_escorted":
			return context.get("player_escorted", false)
		"weather_storm":
			return WeatherSystem.get_today_weather() == "storm"
		"weather_heavy_rain":
			return WeatherSystem.get_today_weather() == "heavy_rain"
		"weather_rain":
			var weather: String = WeatherSystem.get_today_weather()
			return weather == "rain" or weather == "drizzle"
		"npc_has_escort":
			return context.get("has_escort", false)
	return false


# =============================================================================
# HÀM ÁP DỤNG HIỆU ỨNG BƯỚC (_apply_step_effect)
# =============================================================================

func _apply_step_effect(chain_id: String, step: String, description: String) -> void:
	print("[EventChainEngine] Chain '%s' step '%s': %s" % [chain_id, step, description])


# =============================================================================
# HÀM XỬ LÝ TRẢ VỀ CỦA NPC (_finalize_npc_return)
# =============================================================================

func _finalize_npc_return(chain_id: String) -> void:
	var chain: Dictionary = active_chains[chain_id]
	var rolls_made: Dictionary = chain.get("rolls_made", {})
	var outcome: String = rolls_made.get("outcome", "safe")
	match outcome:
		"safe", "delayed":
			pass
		"injured":
			GameState.set_flag("%s_npc_injured" % chain_id)
		"dead":
			GameState.set_flag("%s_npc_dead" % chain_id)
			var context: Dictionary = chain.get("context", {})
			var npc_id: String = context.get("npc_id", "")
			var family_id: String = context.get("family_id", "")
			FamilyRegistry.mark_family_member_dead(npc_id, family_id)


# =============================================================================
# HÀM ÁP DỤNG HỆ QUẢ (_apply_consequence)
# =============================================================================

func _apply_consequence(consequence_id: String, chain_id: String, context: Dictionary) -> void:
	match consequence_id:
		"shop_closes":
			GameState.set_flag("shop_open", false)
			GameState.set_flag("shop_closes_day", GameState.current_day)
			ConsequenceResolver.apply_scene_change("res://scenes/world/shop.tscn", "set_shop_state", "closed")
		"shop_closed_days":
			var days: int = randi() % 3 + 2
			GameState.set_flag("shop_open", false)
			GameState.set_flag("shop_reopens_day", GameState.current_day + days)
			ConsequenceResolver.schedule_flag_change("shop_open", true, days)
		"shop_late_open":
			GameState.set_flag("shop_late", true)
		"funeral_scheduled":
			var funeral_day: int = GameState.current_day + 3
			GameState.set_flag("funeral_scheduled_day", funeral_day)
			ConsequenceResolver.schedule_event("funeral", funeral_day - GameState.current_day)
		"son_takes_over":
			var family_id: String = context.get("family_id", "")
			var son_npc_id: String = context.get("son_npc_id", "shopkeeper_son")
			ConsequenceResolver.schedule_family_succession(family_id, son_npc_id, 3)
			GameState.set_flag("new_shopkeeper", true)
		"food_shortage":
			GameState.set_flag("food_shortage", true)
			GameState.set_flag("food_shortage_day", GameState.current_day)
		"villagers_leaving":
			GameState.set_flag("villagers_leaving", true)
		"strange_events":
			GameState.set_flag("strange_events_active", true)
			WeatherSystem.trigger_anomaly_weather()


# =============================================================================
# HÀM GHI NHẬN CAN THIỆP (register_player_intervention)
# =============================================================================

func register_player_intervention(chain_id: String, intervention_type: String) -> void:
	if not active_chains.has(chain_id):
		return
	active_chains[chain_id]["intervention_active"] = true
	active_chains[chain_id]["intervention_type"] = intervention_type
	player_intervention_detected.emit(chain_id, intervention_type)
	print("[EventChainEngine] Player intervention in chain '%s': %s" % [chain_id, intervention_type])


# =============================================================================
# HÀM DỪNG CHAIN (pause_chain)
# =============================================================================

func pause_chain(chain_id: String) -> void:
	if active_chains.has(chain_id):
		active_chains[chain_id]["state"] = ChainState.PAUSED

func _is_chain_paused(chain_id: String) -> bool:
	return active_chains.has(chain_id) and active_chains[chain_id].get("state", ChainState.DORMANT) == ChainState.PAUSED


# =============================================================================
# HÀM TIẾP TỤC CHAIN (resume_chain)
# =============================================================================

func resume_chain(chain_id: String) -> void:
	if active_chains.has(chain_id):
		active_chains[chain_id]["state"] = ChainState.ACTIVE


# =============================================================================
# HÀM HỦY CHAIN (abort_chain)
# =============================================================================

func abort_chain(chain_id: String, reason: String) -> void:
	if active_chains.has(chain_id):
		active_chains[chain_id]["state"] = ChainState.ABORTED
		event_chain_aborted.emit(chain_id, reason)
		active_chains.erase(chain_id)
		print("[EventChainEngine] Chain aborted: %s (%s)" % [chain_id, reason])


# =============================================================================
# HÀM HOÀN THÀNH CHAIN (_complete_chain)
# =============================================================================

func _complete_chain(chain_id: String) -> void:
	if active_chains.has(chain_id):
		active_chains[chain_id]["state"] = ChainState.COMPLETED
		completed_chains.append(chain_id)
		active_chains.erase(chain_id)
		event_chain_completed.emit(chain_id)
		print("[EventChainEngine] Chain completed: %s" % chain_id)


# =============================================================================
# HÀM LẤY TRẠNG THÁI CHAIN (get_chain_state)
# =============================================================================

func get_chain_state(chain_id: String) -> int:
	if not active_chains.has(chain_id):
		if chain_id in completed_chains:
			return ChainState.COMPLETED
		return ChainState.DORMANT
	return active_chains[chain_id]["state"]


# =============================================================================
# HÀM KIỂM TRA CHAIN ĐANG CHẠY (is_chain_active)
# =============================================================================

func is_chain_active(chain_id: String) -> bool:
	return active_chains.has(chain_id)


# =============================================================================
# HÀM LẤY THÔNG TIN CHAIN (get_chain_info)
# =============================================================================

func get_chain_info(chain_id: String) -> Dictionary:
	if active_chains.has(chain_id):
		return active_chains[chain_id]
	return {}


# =============================================================================
# HÀM KIỂM TRA KẾT QUẢ ĐÃ XẢY RA (is_outcome_triggered)
# =============================================================================

func is_outcome_triggered(chain_id: String, outcome: String) -> bool:
	return GameState.get_flag("%s_%s" % [chain_id, outcome])


# =============================================================================
# HÀM MÔ PHỎNG CHAIN (simulate_chain)
# =============================================================================

func simulate_chain(chain_id: String, context: Dictionary, days_to_simulate: int) -> Dictionary:
	if not chain_definitions.has(chain_id):
		return {}

	var def: Dictionary = chain_definitions[chain_id]
	var outcome_weights: Dictionary = {}
	var outcomes: Dictionary = def.get("outcomes", {})
	for key: String in outcomes:
		var weight: float = outcomes[key].get("weight", 0.0)
		outcome_weights[key] = weight

	var roll: float = randf()
	var cumulative: float = 0.0
	var chosen: String = "safe"
	for key: String in outcome_weights:
		cumulative += outcome_weights[key]
		if roll <= cumulative:
			chosen = key
			break

	var outcome_data: Dictionary = def["outcomes"][chosen]
	return {
		"chain_id": chain_id,
		"simulated_outcome": chosen,
		"roll": roll,
		"consequences": outcome_data.get("consequences", []),
		"message": outcome_data.get("message", ""),
	}


# =============================================================================
# HÀM LẤY TẤT CẢ CHAIN ĐANG CHẠY (get_all_active_chains)
# =============================================================================

func get_all_active_chains() -> Array:
	return active_chains.keys()


# =============================================================================
# HÀM LẤY CHAIN ĐÃ HOÀN THÀNH (get_completed_chains)
# =============================================================================

func get_completed_chains() -> Array:
	return completed_chains.duplicate()


# =============================================================================
# HÀM LẤY ĐỊNH NGHĨA CHAIN (get_chain_definition)
# =============================================================================

func get_chain_definition(chain_id: String) -> Dictionary:
	return chain_definitions.get(chain_id, {})


# =============================================================================
# VOSS MOUNTAIN EVENT — DOMAIN VALIDATION
# =============================================================================
# Các hàm này là contract cho toàn bộ 3 branch (UNSEEN/INVITED/MOUNTAIN_ENCOUNTER).
# Mọi trigger chain phải đưa context hợp lệ; mọi phase transition phải đi qua
# bảng VOSS_TRANSITIONS.

func validate_voss_context(context: Dictionary) -> bool:
	for key: String in VOSS_CONTEXT_REQUIRED_KEYS:
		if not context.has(key):
			push_warning("[EventChainEngine] validate_voss_context: thiếu key '%s'" % key)
			return false
	if int(context.get("event_day", -1)) < 1:
		return false
	if float(context.get("departure_time", -1.0)) < 0.0 or float(context.get("departure_time", -1.0)) >= 24.0:
		return false
	if float(context.get("fall_time", -1.0)) < 0.0 or float(context.get("fall_time", -1.0)) >= 24.0:
		return false
	if float(context.get("end_time", 17.0)) < 0.0 or float(context.get("end_time", 17.0)) >= 24.0:
		return false
	if float(context.get("departure_time", 0.0)) >= float(context.get("fall_time", 0.0)):
		return false
	if float(context.get("fall_time", 0.0)) >= float(context.get("end_time", 17.0)):
		return false
	if str(context.get("npc_id", "")) != "Vos":
		return false
	if str(context.get("family_id", "")) != "shopkeeper_family":
		return false
	var discovery: Variant = context.get("discovery_mode", "")
	if discovery is String:
		if not DiscoveryMode.has(discovery):
			push_warning("[EventChainEngine] validate_voss_context: discovery_mode không hợp lệ '%s'" % str(discovery))
			return false
	elif discovery is int:
		if discovery < 0 or discovery >= DiscoveryMode.size():
			push_warning("[EventChainEngine] validate_voss_context: discovery_mode int ngoài phạm vi '%d'" % int(discovery))
			return false
	else:
		push_warning("[EventChainEngine] validate_voss_context: discovery_mode phải là String hoặc int")
		return false
	return true


func _normalize_voss_context(context: Dictionary) -> Dictionary:
	var normalized: Dictionary = context.duplicate(true)
	var config: Dictionary = ConfigManager.get_voss_event_config() if ConfigManager.has_method("get_voss_event_config") else {}
	var schedule: Dictionary = config.get("schedule", {})
	normalized["event_day"] = int(normalized.get("event_day", schedule.get("event_day", 5)))
	normalized["departure_time"] = float(normalized.get("departure_time", schedule.get("departure_time", 11.0)))
	normalized["fall_time"] = float(normalized.get("fall_time", schedule.get("fall_time", 16.0)))
	normalized["end_time"] = float(normalized.get("end_time", schedule.get("end_time", 17.0)))
	normalized["npc_id"] = FamilyRegistry.resolve_canonical_npc_id(str(normalized.get("npc_id", "Vos")))
	normalized["family_id"] = str(normalized.get("family_id", "shopkeeper_family"))
	var discovery: Variant = normalized.get("discovery_mode", "UNSEEN")
	if discovery is int:
		normalized["discovery_mode"] = DiscoveryMode.keys()[int(discovery)] if int(discovery) >= 0 and int(discovery) < DiscoveryMode.size() else ""
	return normalized


func is_valid_voss_transition(from_phase: String, to_phase: String) -> bool:
	if not VossPhase.has(from_phase) or not VossPhase.has(to_phase):
		return false
	var allowed: Array = VOSS_TRANSITIONS.get(from_phase, [])
	return allowed.has(to_phase)


func get_voss_phase() -> int:
	var phase_str: String = str(GameState.get_flag("voss_mountain_phase", "SCHEDULED"))
	return VossPhase.get(phase_str, VossPhase.SCHEDULED)


func get_voss_phase_name() -> String:
	var phase_index: int = get_voss_phase()
	return VossPhase.keys()[phase_index]


func set_voss_phase(phase: Variant) -> bool:
	var to_name: String = ""
	if phase is String:
		to_name = str(phase)
	elif phase is int:
		var phase_index: int = int(phase)
		if phase_index < 0 or phase_index >= VossPhase.size():
			push_warning("[EventChainEngine] set_voss_phase: phase ngoài phạm vi '%d'" % phase_index)
			return false
		to_name = VossPhase.keys()[phase_index]
	else:
		push_warning("[EventChainEngine] set_voss_phase: phase phải là String hoặc int")
		return false
	if not VossPhase.has(to_name):
		push_warning("[EventChainEngine] set_voss_phase: phase không hợp lệ '%s'" % to_name)
		return false
	var from_name: String = get_voss_phase_name()
	if from_name == to_name:
		return true
	if not is_valid_voss_transition(from_name, to_name):
		push_warning("[EventChainEngine] set_voss_phase: transition không hợp lệ %s -> %s" % [from_name, to_name])
		return false
	GameState.set_flag("voss_mountain_phase", to_name)
	print("[EventChainEngine] Voss phase: %s -> %s" % [from_name, to_name])
	return true


func is_voss_event_resolved() -> bool:
	return get_voss_phase_name() == "RESOLVED"
