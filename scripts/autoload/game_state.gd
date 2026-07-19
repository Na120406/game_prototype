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
# Khi = 0, người chơi buộc phải ngủ
var energy: float = 100.0

# Năng lượng tối đa - giới hạn trên của energy
var max_energy: float = 100.0

# Tốc độ tiêu hao năng lượng mỗi giây khi làm việc
var stamina_drain_rate: float = 5.0

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

# =============================================================================
# HỆ THỐNG ĐỒ (INVENTORY SYSTEM)
# =============================================================================

# Danh sách đồ trong túi - mỗi item là Dictionary với "id" và "amount"
# Cấu trúc: [{"id": "apple", "amount": 5}, {"id": "hoe", "amount": 1}]
var inventory: Array[Dictionary] = []

# Công cụ đang trang bị - tên của công cụ đang dùng
# Ví dụ: "hoe" (cuốc), "water_can" (bình tưới)
var equipped_tool: String = "none"

# Số vàng hiện có - dùng để mua bán vật phẩm
var gold: int = 100

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
	day_changed.emit(current_day)
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
	energy = clampf(energy + amount, 0.0, max_energy)
	
	# Cảnh báo khi năng lượng hết
	if energy <= 0.0:
		print("[GameState] Energy depleted! Forcing sleep...")


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
	# Duyệt túi đồ để tìm vật phẩm đã tồn tại chưa
	for i: int in range(inventory.size()):
		var existing_id: String = inventory[i].get("id", "")
		
		# Nếu tìm thấy vật phẩm cùng loại
		if existing_id == item_id:
			# Tăng số lượng lên
			inventory[i]["amount"] = inventory[i].get("amount", 0) + amount
			print("[GameState] Added %d x %s (now %d)" % [amount, item_id, inventory[i]["amount"]])
			inventory_changed.emit()  # Thông báo cho UI cập nhật
			return true
	
	# Nếu không tìm thấy, thêm vật phẩm mới vào túi
	inventory.append({"id": item_id, "amount": amount})
	print("[GameState] Added %d x %s to inventory" % [amount, item_id])
	inventory_changed.emit()  # Thông báo cho UI cập nhật
	return true


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
	
	# Xóa toàn bộ túi đồ và cờ sự kiện
	inventory.clear()
	world_flags.clear()
	discovered_areas.clear()
	
	# Reset các biến khác
	lore_fragments_found = 0
	weather_type = "clear"
	is_day = true
	gold = 100
	
	print("[GameState] Game state reset.")
