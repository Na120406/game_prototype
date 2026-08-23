extends Node
# =============================================================================
# GAME STATE (Trạng thái Game)
# =============================================================================
# Chức năng: Lưu trữ tất cả dữ liệu toàn cục của game
# Đây là nơi DUY NHẤT lưu trữ các biến quan trọng như:
#   - Thông tin người chơi (vàng, máu, năng lượng)
#   - Thời gian trong game (ngày, giờ)
#   - Túi đồ (inventory)
#   - Các cờ sự kiện (world flags)
#
# CÁCH SỬ DỤNG: Gọi GameState.ten_bien từ bất kỳ đâu
# Ví dụ: GameState.gold += 10 (thêm 10 vàng)
# =============================================================================

# =============================================================================
# TÍN HIỆU (SIGNALS) - Thông báo khi có sự thay đổi
# =============================================================================
# Khi inventory thay đổi, gửi thông báo để UI cập nhật
signal inventory_changed
signal day_changed(new_day: int)
signal energy_changed(new_value: float)
signal toolbar_changed

# =============================================================================
# CÁC BIẾN NGƯỜI CHƠI (PLAYER VARIABLES)
# =============================================================================

# Tên nhân vật người chơi - mặc định là "Player"
var player_name: String = "Player"

# Ngày hiện tại trong game - bắt đầu từ ngày 1
var current_day: int = 1

# Thời gian hiện tại (định dạng 24 giờ)
# 6.0 = 6:00 sáng, 12.0 = 12:00 trưa, 18.0 = 6:00 chiều
var current_time: float = 6.0

# Năng lượng hiện tại - dùng để làm các hoạt động (farming, walking...)
# Thanh gồm 20 ô, mỗi hành động (đào đất, tưới nước...) tiêu hao 1 ô.
# Khi = 0, người chơi buộc phải ngủ.
var energy: float = 20.0

# Năng lượng tối đa - giới hạn trên của energy (20 ô)
var max_energy: float = 20.0

# Tốc độ tiêu hao năng lượng mỗi giây khi làm việc
var stamina_drain_rate: float = 5.0

# Tốc độ di chuyển hiện tại (mặc định 1.0 = 100%). Bị giảm 25% mỗi lần
# knock-out, reset về 1.0 sau khi ngủ qua ngày.
var move_speed_mult: float = 1.0

# Máu (health) - khi = 0, người chơi chết hoặc bất tỉnh
var health: float = 100.0

# Máu tối đa - giới hạn trên của health
var max_health: float = 100.0

# =============================================================================
# CÁC TRẠNG THÁI GAME (GAME STATES)
# =============================================================================

# Đang ngủ hay không - true khi đang ngủ (ấn nút ngủ)
var is_sleeping: bool = false

# Game đang tạm dừng hay không - true khi mở menu pause
var is_paused: bool = false

# Người chơi đang tương tác với đối tượng không - true khi đang nói chuyện/dùng đồ
# Dùng để khóa di chuyển khi đang làm gì đó
var game_interacting: bool = false

# Flag set bởi Area2D portal (world_transition.gd) NGAY TRƯỚC khi gọi
# SceneManager.change_scene ở frame player nhấn E. Player._interact() sẽ
# check flag này để SKIP _try_use_active_consumable() — tránh double-handle:
# vừa đổi scene vừa consume item cùng 1 frame. Reset về false ở đầu mỗi
# frame player input, hoặc sau khi portal gọi change_scene xong.
var pending_portal_interaction: bool = false

# =============================================================================
# HỆ THỐNG ĐỒ (INVENTORY SYSTEM)
# =============================================================================

# Danh sách đồ trong túi - mỗi item là Dictionary với "id" và "amount"
# Cấu trúc: [{"id": "apple", "amount": 5}, {"id": "hoe", "amount": 1}]
var inventory: Array[Dictionary] = []

# Thanh công cụ (toolbar) - 5 slot cố định gắn với phím 1-5.
# Tách khỏi inventory để tránh phụ thuộc vị trí; player có thể chủ động
# sắp xếp item hay dùng lên toolbar qua Inventory UI (drag/drop).
var toolbar: Array[Dictionary] = [
	{"id": "", "amount": 0},
	{"id": "", "amount": 0},
	{"id": "", "amount": 0},
	{"id": "", "amount": 0},
	{"id": "", "amount": 0},
]

# Công cụ đang trang bị - tên của công cụ đang dùng
# Ví dụ: "hoe" (cuốc), "water_can" (bình tưới)
var equipped_tool: String = "none"

# Số vàng hiện có - dùng để mua bán vật phẩm
var gold: int = 200

# =============================================================================
# HỆ THỐNG THẾ GIỚI (WORLD SYSTEM)
# =============================================================================

# Các cờ sự kiện - lưu trạng thái đã xảy ra trong game
# Ví dụ: {"talked_to_shopkeeper": true, "quest_1_started": true}
# Dùng để theo dõi tiến độ quest, đã nói chuyện với ai, v.v.
var world_flags: Dictionary = {}

# Các khu vực đã khám phá - danh sách tên khu vực đã từng vào
var discovered_areas: Array[String] = []

# Số mảnh lore đã tìm được - dùng cho hệ thống thu thập
var lore_fragments_found: int = 0

# Thời tiết hiện tại - có thể là "clear" (nắng), "rain" (mưa), "storm" (bão)
var weather_type: String = "clear"

# Có phải ban ngày không - true khi 6:00 <= giờ < 22:00
var is_day: bool = true

# Dữ liệu các ô đất trong farm - lưu trạng thái từng ô đất
# Key là tọa độ ô (Vector2), value là Dictionary chứa trạng thái cây trồng
# Ví dụ: {Vector2(0,0): {"state": "GROWING", "crop": "wheat", "watered": true}}
var farm_cells_data: Dictionary = {}


# =============================================================================
# HÀM KHỞI TẠO (_ready)
# =============================================================================
# Được gọi KHI script được load lần đầu
# Dùng để khởi tạo giá trị ban đầu

func _ready() -> void:
	# In ra thông báo khởi tạo để debug
	print("[GameState] Initialized — Day %d, %.0f:00" % [current_day, current_time])
	_ensure_inventory_slots()


# Inventory UI có 21 ô cố định (3 hàng × 7 cột). Mỗi ô map 1:1 với index
# trong GameState.inventory; các ô trống từ đầu cũng phải có entry {"id":"",
# "amount":0} để drag/swap giữa tất cả các ô hoạt động nhất quán.
const INVENTORY_SLOTS: int = 21

func _ensure_inventory_slots() -> void:
	while inventory.size() < INVENTORY_SLOTS:
		inventory.append({"id": "", "amount": 0})


# Gọi sau khi load save hoặc khi inventory UI khởi tạo để đảm bảo mọi
# ô đều có entry tương ứng.
func reset_inventory_layout() -> void:
	_ensure_inventory_slots()


# =============================================================================
# HÀM CHUYỂN NGÀY (advance_day)
# =============================================================================
# Chuyển sang ngày mới khi thời gian đạt 24:00 hoặc khi ngủ
#
# Xử lý:
#   1. Tăng số ngày lên 1
#   2. Reset giờ về 6:00 sáng
#   3. Khôi phục năng lượng đầy
#   4. Đặt lại is_day = true (ban ngày)

func advance_day() -> void:
	current_day += 1           # Tăng ngày
	current_time = 6.0        # Reset về 6:00 sáng
	energy = max_energy        # Khôi phục năng lượng đầy
	is_day = true              # Đặt ban ngày
	# move_speed_mult KHÔNG reset ở đây — penalty chỉ được reset khi người chơi
	# NGỦ ĐÚNG GIỜ (qua đêm tại giường). Nếu qua ngày do kiệt sức hoặc bị
	# phạt vì không ngủ → speed penalty giữ nguyên.
	day_changed.emit(current_day)
	energy_changed.emit(energy)  # Bắn signal để UI cập nhật thanh năng lượng ngay
	print("[GameState] Day %d begins." % current_day)


# =============================================================================
# HÀM TĂNG THỜI GIAN (advance_time)
# =============================================================================
# Tăng thời gian game theo số giờ chỉ định
# Thường dùng khi người chơi ngủ để chuyển ngày nhanh
#
# Tham số:
#   hours: float - số giờ cần tăng (ví dụ: 8.0 = 8 tiếng)

func advance_time(hours: float) -> void:
	current_time += hours                                    # Tăng thời gian
	
	# Nếu thời gian >= 22:00 (10 giờ tối), đặt ban đêm
	if current_time >= 22.0:
		is_day = false
	
	# Nếu thời gian >= 24:00, chuyển sang ngày mới
	if current_time >= 24.0:
		advance_day()
	
	print("[GameState] Time: %.0f:00" % current_time)


# =============================================================================
# HÀM THAY ĐỔI NĂNG LƯỢNG (modify_energy)
# =============================================================================
# Thay đổi năng lượng người chơi (thêm hoặc bớt)
#
# Tham số:
#   amount: float - số năng lượng thay đổi
#     > 0: thêm năng lượng (ăn uống, nghỉ ngơi)
#     < 0: bớt năng lượng (làm việc, chạy)
#
# Đặc biệt: Nếu năng lượng về 0, in cảnh báo buộc ngủ

func modify_energy(amount: float) -> void:
	# Clampf đảm bảo giá trị nằm trong khoảng [0, max_energy]
	var prev: float = energy
	energy = clampf(energy + amount, 0.0, max_energy)
	energy_changed.emit(energy)

	# Cảnh báo khi năng lượng hết
	if energy <= 0.0 and prev > 0.0:
		print("[GameState] Energy depleted! Knock-out imminent.")


# =============================================================================
# HÀM THAY ĐỔI MÁU (modify_health)
# =============================================================================
# Thay đổi máu người chơi (thêm hoặc bớt)
#
# Tham số:
#   amount: float - số máu thay đổi
#     > 0: hồi máu (uống thuốc, nghỉ ngơi)
#     < 0: mất máu (bị thương, bệnh)

func modify_health(amount: float) -> void:
	# Clampf đảm bảo máu nằm trong khoảng [0, max_health]
	health = clampf(health + amount, 0.0, max_health)
	print("[GameState] Health: %.0f / %.0f" % [health, max_health])


# =============================================================================
# HÀM THÊM ĐỒ VÀO TÚI (add_item)
# =============================================================================
# Thêm vật phẩm vào túi đồ
# Nếu vật phẩm đã tồn tại, tăng số lượng
# Nếu chưa có, tạo mới
#
# Tham số:
#   item_id: String - định danh của vật phẩm (ví dụ: "apple", "hoe")
#   amount: int - số lượng thêm vào (mặc định = 1)
#
# Trả về: true nếu thêm thành công

func add_item(item_id: String, amount: int = 1) -> bool:
	_ensure_inventory_slots()
	# Lấy stack_size và type để biết item này có stack được với toolbar không.
	var stack_max: int = 99
	var is_tool: bool = false
	var db = get_node_or_null("/root/ItemDB")
	if db != null:
		var data: ItemData = db.get_item(item_id)
		if data != null:
			stack_max = max(1, data.stack_size)
			is_tool = (data.item_type == ItemData.Type.TOOL)
	# Bước 1: thử stack vào toolbar trước cho item cùng id, không phải tool.
	# Tool không stack — mỗi slot chỉ chứa 1 equipment độc lập.
	if not is_tool:
		var remaining: int = amount
		for t: int in range(toolbar.size()):
			if remaining <= 0:
				break
			if toolbar[t].get("id", "") == item_id:
				var cur_amt: int = toolbar[t].get("amount", 0)
				var space: int = stack_max - cur_amt
				if space <= 0:
					continue
				var to_add: int = min(remaining, space)
				toolbar[t]["amount"] = cur_amt + to_add
				remaining -= to_add
		if remaining < amount:
			# Đã stack 1 phần (hoặc toàn bộ) vào toolbar.
			toolbar_changed.emit()
		if remaining == 0:
			return true
		amount = remaining
	# Bước 2: stack với item cùng loại đã có trong inventory (cap stack_size).
	for i: int in range(inventory.size()):
		var existing_id: String = inventory[i].get("id", "")
		if existing_id == item_id:
			var cur_inv: int = inventory[i].get("amount", 0)
			var inv_space: int = stack_max - cur_inv
			if inv_space <= 0:
				continue
			var add_inv: int = min(amount, inv_space)
			inventory[i]["amount"] = cur_inv + add_inv
			amount -= add_inv
			if amount <= 0:
				inventory_changed.emit()
				return true
	if amount > 0:
		inventory_changed.emit()
	if amount == 0:
		return true
	# Bước 3: phần dư (hoặc item mới) đặt vào ô trống đầu tiên.
	for i: int in range(inventory.size()):
		if inventory[i].get("id", "") == "":
			var fill: int = min(amount, stack_max)
			inventory[i] = {"id": item_id, "amount": fill}
			amount -= fill
			if amount <= 0:
				return true
	# Inventory đầy
	if amount > 0:
		print("[GameState] add_item: %d x %s không còn chỗ chứa." % [amount, item_id])
	return false


# =============================================================================
# HÀM XÓA ĐỒ KHỎI TÚI (remove_item)
# =============================================================================
# Xóa vật phẩm khỏi túi đồ
# Nếu số lượng về 0, xóa hẳn vật phẩm khỏi túi
#
# Tham số:
#   item_id: String - định danh của vật phẩm cần xóa
#   amount: int - số lượng xóa (mặc định = 1)
#
# Trả về: true nếu xóa thành công, false nếu không tìm thấy

func remove_item(item_id: String, amount: int = 1) -> bool:
	# Duyệt túi đồ để tìm vật phẩm
	for i: int in range(inventory.size()):
		var existing_id: String = inventory[i].get("id", "")
		
		# Nếu tìm thấy
		if existing_id == item_id:
			# Giảm số lượng
			inventory[i]["amount"] = inventory[i].get("amount", 0) - amount
			
			# Nếu số lượng <= 0, xóa hẳn vật phẩm khỏi túi
			if inventory[i]["amount"] <= 0:
				inventory.remove_at(i)
			
			print("[GameState] Removed %d x %s" % [amount, item_id])
			inventory_changed.emit()  # Thông báo cho UI cập nhật
			return true
	
	# Không tìm thấy vật phẩm
	return false


# =============================================================================
# THANH CÔNG CỤ (TOOLBAR) - 5 slot gắn với phím 1-5
# =============================================================================
# Tách khỏi inventory để player chủ động đặt item hay dùng (tool, seed,
# consumable) lên 5 ô cố định. Drag/drop trong Inventory UI hoán đổi giữa
# inventory ↔ toolbar hoặc giữa các slot toolbar với nhau.
# =============================================================================

const TOOLBAR_SIZE: int = 5

func set_toolbar_slot(idx: int, item_id: String, amount: int = 1) -> bool:
	if idx < 0 or idx >= toolbar.size():
		return false
	toolbar[idx] = {"id": item_id, "amount": amount}
	toolbar_changed.emit()
	return true

func clear_toolbar_slot(idx: int) -> bool:
	if idx < 0 or idx >= toolbar.size():
		return false
	toolbar[idx] = {"id": "", "amount": 0}
	toolbar_changed.emit()
	return true

# Xóa 1 lượng item khỏi 1 slot cụ thể của toolbar (dùng khi bán / consume từ
# hotbar). Nếu amount <= 0 thì clear slot. Trả về true nếu có thay đổi.
func remove_toolbar_item(slot_idx: int, amount: int = 1) -> bool:
	if slot_idx < 0 or slot_idx >= toolbar.size():
		return false
	if toolbar[slot_idx].get("id", "") == "":
		return false
	var cur: int = int(toolbar[slot_idx].get("amount", 0))
	var new_amount: int = cur - amount
	if new_amount <= 0:
		toolbar[slot_idx] = {"id": "", "amount": 0}
	else:
		toolbar[slot_idx]["amount"] = new_amount
	toolbar_changed.emit()
	return true

# Xóa 1 lượng item khỏi 1 slot cụ thể của inventory (theo index, không phải
# item_id — chính xác hơn khi nhiều slot cùng item_id). Nếu amount <= 0 thì
# xóa cả entry. Trả về true nếu có thay đổi.
func remove_inventory_item_at(slot_idx: int, amount: int = 1) -> bool:
	if slot_idx < 0 or slot_idx >= inventory.size():
		return false
	if inventory[slot_idx].get("id", "") == "":
		return false
	var cur: int = int(inventory[slot_idx].get("amount", 0))
	var new_amount: int = cur - amount
	if new_amount <= 0:
		inventory.remove_at(slot_idx)
	else:
		inventory[slot_idx]["amount"] = new_amount
	inventory_changed.emit()
	return true

func swap_toolbar_slots(a: int, b: int) -> bool:
	if a < 0 or a >= toolbar.size() or b < 0 or b >= toolbar.size():
		return false
	if a == b:
		return false
	var tmp: Dictionary = toolbar[a]
	toolbar[a] = toolbar[b]
	toolbar[b] = tmp
	toolbar_changed.emit()
	return true

func swap_inventory_slots(a: int, b: int) -> bool:
	if a < 0 or a >= inventory.size() or b < 0 or b >= inventory.size():
		return false
	if a == b:
		return false
	var tmp: Dictionary = inventory[a]
	inventory[a] = inventory[b]
	inventory[b] = tmp
	inventory_changed.emit()
	return true

func swap_inventory_toolbar(inv_idx: int, tool_idx: int) -> bool:
	if tool_idx < 0 or tool_idx >= toolbar.size():
		return false
	if inv_idx < 0 or inv_idx >= inventory.size():
		return false
	var tmp: Dictionary = inventory[inv_idx]
	inventory[inv_idx] = toolbar[tool_idx]
	toolbar[tool_idx] = tmp
	inventory_changed.emit()
	toolbar_changed.emit()
	return true

func get_toolbar_item(idx: int) -> Dictionary:
	if idx < 0 or idx >= toolbar.size():
		return {}
	return toolbar[idx]

func consume_toolbar_slot(idx: int, amount: int = 1) -> bool:
	if idx < 0 or idx >= toolbar.size():
		return false
	var slot: Dictionary = toolbar[idx]
	var slot_id: String = slot.get("id", "")
	var slot_amount: int = int(slot.get("amount", 0))
	if slot_id == "" or slot_amount <= 0:
		return false
	slot_amount -= amount
	if slot_amount <= 0:
		toolbar[idx] = {"id": "", "amount": 0}
	else:
		toolbar[idx] = {"id": slot_id, "amount": slot_amount}
	toolbar_changed.emit()
	return true

func reset_toolbar() -> void:
	for i in range(toolbar.size()):
		toolbar[i] = {"id": "", "amount": 0}
	toolbar_changed.emit()


# =============================================================================
# HÀM KIỂM TRA ĐỒ TRONG TÚI (has_item)
# =============================================================================
# Kiểm tra xem có đủ vật phẩm trong túi không
#
# Tham số:
#   item_id: String - định danh vật phẩm cần kiểm tra
#   amount: int - số lượng cần kiểm tra (mặc định = 1)
#
# Trả về: true nếu có đủ số lượng, false nếu không

func has_item(item_id: String, amount: int = 1) -> bool:
	# Duyệt túi đồ
	for item: Dictionary in inventory:
		var item_id_found: String = item.get("id", "")
		var item_amount: int = item.get("amount", 0)
		
		# Kiểm tra cả id và số lượng
		if item_id_found == item_id and item_amount >= amount:
			return true
	
	return false


# =============================================================================
# HÀM ĐẾM SỐ LƯỢNG ĐỒ (get_item_count)
# =============================================================================
# Đếm số lượng của một vật phẩm trong túi
#
# Tham số:
#   item_id: String - định danh vật phẩm cần đếm
#
# Trả về: số lượng của vật phẩm, 0 nếu không có

func get_item_count(item_id: String) -> int:
	for item: Dictionary in inventory:
		var item_id_found: String = item.get("id", "")
		if item_id_found == item_id:
			return item.get("amount", 0)
	return 0


# =============================================================================
# HÀM ĐẶT CỜ SỰ KIỆN (set_flag)
# =============================================================================
# Đặt giá trị cho một cờ sự kiện
# Dùng để theo dõi trạng thái quest, đã làm gì trong game
#
# Tham số:
#   flag: String - tên cờ (ví dụ: "talked_to_voss")
#   value: Variant - giá trị đặt cho cờ (mặc định = true)

func set_flag(flag: String, value: Variant = true) -> void:
	world_flags[flag] = value
	print("[GameState] Flag set: %s = %s" % [flag, str(value)])


# =============================================================================
# HÀM LẤY GIÁ TRỊ CỜ (get_flag)
# =============================================================================
# Lấy giá trị của một cờ sự kiện
#
# Tham số:
#   flag: String - tên cờ cần lấy
#   default: Variant - giá trị mặc định nếu cờ không tồn tại
#
# Trả về: giá trị của cờ, hoặc default nếu không có

func get_flag(flag: String, default: Variant = false) -> Variant:
	return world_flags.get(flag, default)


# =============================================================================
# HÀM KHÁM PHÁ KHU VỰC (discover_area)
# =============================================================================
# Đánh dấu một khu vực đã được khám phá
#
# Tham số:
#   area_id: String - định danh khu vực (ví dụ: "forest", "mountain")
#
# Trả về: true nếu là khu vực mới, false nếu đã khám phá rồi

func discover_area(area_id: String) -> bool:
	# Nếu đã khám phá rồi, không làm gì
	if area_id in discovered_areas:
		return false
	
	# Thêm vào danh sách đã khám phá
	discovered_areas.append(area_id)
	print("[GameState] New area discovered: %s" % area_id)
	return true


# =============================================================================
# HÀM RESET GAME (reset)
# =============================================================================
# Đặt lại toàn bộ game về trạng thái ban đầu
# Dùng khi bắt đầu game mới hoặc chơi lại

func reset() -> void:
	# Reset các biến về giá trị ban đầu
	current_day = 1
	current_time = 6.0
	energy = max_energy
	health = max_health
	is_sleeping = false
	is_paused = false
	pending_portal_interaction = false
	
	# Xóa toàn bộ túi đồ và cờ sự kiện
	inventory.clear()
	reset_toolbar()
	world_flags.clear()
	discovered_areas.clear()
	
	# Reset các biến khác
	lore_fragments_found = 0
	weather_type = "clear"
	is_day = true
	gold = 200
	move_speed_mult = 1.0
	
	print("[GameState] Game state reset.")


# =============================================================================
# INVENTORY HELPER FUNCTIONS (Type-Safe Utilities)
# =============================================================================

## Lấy tất cả item ID trong inventory
func get_all_item_ids() -> Array[String]:
	var ids: Array[String] = []
	for item: Dictionary in inventory:
		ids.append(item.get("id", ""))
	return ids

## Tìm index của item trong inventory, -1 nếu không tìm thấy
func find_item_index(item_id: String) -> int:
	for i: int in range(inventory.size()):
		if inventory[i].get("id", "") == item_id:
			return i
	return -1

## Kiểm tra item có tồn tại trong inventory không
func item_exists(item_id: String) -> bool:
	return find_item_index(item_id) >= 0

## Lấy thông tin item đầy đủ từ inventory (id + amount)
func get_inventory_item(item_id: String) -> Dictionary:
	var idx: int = find_item_index(item_id)
	if idx >= 0:
		return inventory[idx].duplicate()
	return {}

## Thêm item với validation (chỉ thêm nếu hợp lệ)
func add_item_safe(item_id: String, amount: int = 1) -> bool:
	if item_id == "" or amount <= 0:
		push_warning("[GameState] Invalid add_item parameters: %s, %d" % [item_id, amount])
		return false
	return add_item(item_id, amount)

## Xóa item với validation
func remove_item_safe(item_id: String, amount: int = 1) -> bool:
	if item_id == "" or amount <= 0:
		push_warning("[GameState] Invalid remove_item parameters: %s, %d" % [item_id, amount])
		return false
	if not has_item(item_id, amount):
		push_warning("[GameState] Cannot remove %d x %s - not enough in inventory" % [amount, item_id])
		return false
	return remove_item(item_id, amount)

## Đếm tổng số loại item trong inventory
func get_unique_item_count() -> int:
	return inventory.size()

## Đếm tổng số item trong inventory (tất cả các loại)
func get_total_item_count() -> int:
	var total: int = 0
	for item: Dictionary in inventory:
		total += item.get("amount", 0)
	return total

## Lấy tất cả items có số lượng >= min_amount
func get_items_with_min_amount(min_amount: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item: Dictionary in inventory:
		if item.get("amount", 0) >= min_amount:
			result.append(item.duplicate())
	return result

## Xóa tất cả items của một loại (xóa hết số lượng)
func clear_item(item_id: String) -> bool:
	var idx: int = find_item_index(item_id)
	if idx >= 0:
		inventory.remove_at(idx)
		inventory_changed.emit()
		return true
	return false

## Xóa toàn bộ inventory
func clear_inventory() -> void:
	inventory.clear()
	inventory_changed.emit()

## Kiểm tra inventory có trống không
func is_inventory_empty() -> bool:
	return inventory.is_empty()

## Kiểm tra inventory có đầy không (giới hạn slot)
func is_inventory_full(max_slots: int = 20) -> bool:
	return inventory.size() >= max_slots

## Thêm item vào slot trống đầu tiên (cho stackable items)
func add_item_to_empty_slot(item_id: String, amount: int = 1) -> bool:
	# Thử stack với item cùng loại trước
	if has_item(item_id):
		return add_item(item_id, amount)
	# Thử thêm vào slot mới nếu còn chỗ
	if not is_inventory_full():
		return add_item(item_id, amount)
	push_warning("[GameState] Inventory full! Cannot add %s" % item_id)
	return false

## Lấy danh sách seeds trong inventory
func get_seeds_in_inventory() -> Array[Dictionary]:
	var seeds: Array[Dictionary] = []
	var db = get_node_or_null("/root/ItemDB")
	if db == null:
		return seeds
	for item: Dictionary in inventory:
		var item_data: ItemData = db.get_item(item.get("id", ""))
		if item_data != null and item_data.item_type == ItemData.Type.SEED:
			seeds.append(item.duplicate())
	return seeds

## Lấy danh sách tools trong inventory
func get_tools_in_inventory() -> Array[Dictionary]:
	var tools: Array[Dictionary] = []
	var db = get_node_or_null("/root/ItemDB")
	if db == null:
		return tools
	for item: Dictionary in inventory:
		var item_data: ItemData = db.get_item(item.get("id", ""))
		if item_data != null and item_data.item_type == ItemData.Type.TOOL:
			tools.append(item.duplicate())
	return tools

## Debug: In ra inventory hiện tại
func debug_print_inventory() -> void:
	print("[GameState] === INVENTORY DEBUG ===")
	print("Total unique items: %d" % get_unique_item_count())
	print("Total item count: %d" % get_total_item_count())
	for item: Dictionary in inventory:
		print("  - %s: %d" % [item.get("id", "?"), item.get("amount", 0)])
	print("==============================")
