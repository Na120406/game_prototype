extends Node
# =============================================================================
# DIALOGUE MANAGER (Quản lý Hội thoại)
# =============================================================================
# Chức năng: Điều khiển hệ thống hội thoại với NPC
#
# Luồng hoạt động:
#   1. NPC gọi start_dialogue() với ID hội thoại
#   2. DialogueManager đọc file JSON chứa nội dung
#   3. Hiển thị từng dòng hội thoại qua DialogueUI
#   4. Người chơi chọn lựa chọn hoặc bấm tiếp tục
#   5. Kết thúc hội thoại, thực hiện action (nếu có)
#
# CẤU TRÚC FILE JSON:
#   res://resources/dialogue/{dialogue_id}.json
#
# CÁCH SỬ DỤNG:
#   DialogueManager.start_dialogue("shopkeeper", "Voss") - bắt đầu hội thoại
# =============================================================================

# =============================================================================
# TÍN HIỆU (SIGNALS) - Thông báo trạng thái hội thoại
# =============================================================================

# Phát ra khi hội thoại bắt đầu
# Tham số: npc_name (String) - tên NPC đang nói
signal dialogue_started(npc_name: String)

# Phát ra khi hội thoại kết thúc hoàn toàn
signal dialogue_ended()

# Phát ra khi người chơi đóng hội thoại
signal dialogue_closed()


# =============================================================================
# CÁC BIẾN TRẠNG THÁI
# =============================================================================

# Có đang trong hội thoại không
var is_active: bool = false

# Nội dung hội thoại hiện tại (đọc từ JSON)
var _current_dialogue: Dictionary = {}

# Tên NPC đang nói
var _current_npc: String = ""

# ID NPC đang nói (dùng cho quest lookup, vd: "neighbor", "shopkeeper")
var _current_npc_id: String = ""

# Dòng hội thoại hiện tại (index)
var _current_line: int = 0

# Action chờ thực hiện (sau khi chọn lựa chọn)
var _pending_action: String = ""

# Đường dẫn thư mục chứa file dialogue JSON
const DIALOGUE_DATA_PATH: String = "res://resources/dialogue/"


# =============================================================================
# HÀM KHỞI TẠO (_ready)
# =============================================================================

func _ready() -> void:
	# Thêm vào group để dễ tìm kiếm
	add_to_group("dialogue_manager")
	
	# Lắng nghe khi có node mới được thêm vào scene
	# Khi DialogueUI được load, sẽ tự động kết nối signals
	get_tree().node_added.connect(_on_node_added)
	
	# Thử kết nối với DialogueUI nếu đã tồn tại
	_connect_to_dialogue_ui()
	
	print("[DialogueManager] Ready.")


# =============================================================================
# HÀM XỬ LÝ KHI NODE ĐƯỢC THÊM (_on_node_added)
# =============================================================================
# Được gọi khi bất kỳ node nào được thêm vào scene tree
# Dùng để tự động kết nối với DialogueUI khi nó load
#
# Tham số:
#   node: Node - node vừa được thêm

func _on_node_added(node: Node) -> void:
	# Bắt mọi node có script dialogue_ui.gd — đây là cách đáng tin cậy nhất
	# để detect DialogueUI Control được thêm vào cây (dù là instance từ scene
	# file gốc hay được spawn bằng code).
	if node.get_script() == null:
		return
	if node.get_script().resource_path != "res://scripts/ui/dialogue_ui.gd":
		return

	# Kết nối với DialogueUI
	var ui: Node = _get_dialogue_ui()
	if ui == null:
		return
	
	# Kết nối các signal của UI với các hàm xử lý
	# dialogue_advance: khi người chơi bấm tiếp tục
	if not ui.dialogue_advance.is_connected(advance):
		ui.dialogue_advance.connect(advance)
	
	# dialogue_close: khi người chơi đóng hội thoại
	if not ui.dialogue_close.is_connected(close):
		ui.dialogue_close.connect(close)
	
	# dialogue_choice: khi người chơi chọn một lựa chọn
	if not ui.dialogue_choice.is_connected(select_choice):
		ui.dialogue_choice.connect(select_choice)
	
	print("[DM] Connected to DialogueUI signals.")


# =============================================================================
# HÀM KẾT NỐI VỚI DIALOGUE UI (_connect_to_dialogue_ui)
# =============================================================================
# Kết nối các signal của DialogueUI với hàm xử lý
# Tương tự _on_node_added nhưng gọi thủ công

func _connect_to_dialogue_ui() -> void:
	var ui: Node = _get_dialogue_ui()
	if ui == null:
		return
	
	# Kết nối từng signal
	if not ui.dialogue_advance.is_connected(advance):
		ui.dialogue_advance.connect(advance)
	if not ui.dialogue_close.is_connected(close):
		ui.dialogue_close.connect(close)
	if not ui.dialogue_choice.is_connected(select_choice):
		ui.dialogue_choice.connect(select_choice)
	
	print("[DM] Connected to DialogueUI signals.")


# =============================================================================
# HÀM BẮT ĐẦU HỘI THOẠI (start_dialogue)
# =============================================================================
# Bắt đầu một hội thoại mới với NPC
#
# Tham số:
#   dialogue_id: String - ID của hội thoại (trùng với tên file JSON)
#     Ví dụ: "shopkeeper" sẽ đọc file "res://resources/dialogue/shopkeeper.json"
#   npc_name: String - tên NPC đang nói

func start_dialogue(dialogue_id: String, npc_name: String, npc_id: String = "") -> void:
	# Không bắt đầu nếu đang trong hội thoại khác
	if is_active:
		print("[DM] Already active, ignoring.")
		return

	# Đảm bảo đã kết nối với UI
	_connect_to_dialogue_ui()

	# =================================================================
	# ĐỌC FILE JSON
	# =================================================================
	var path := DIALOGUE_DATA_PATH + dialogue_id + ".json"
	
	# Kiểm tra file có tồn tại không
	if not FileAccess.file_exists(path):
		push_error("[DM] File not found: %s" % path)
		return

	# Mở file để đọc
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[DM] Cannot open: %s" % path)
		return

	# Đọc nội dung file thành text
	var json_str := file.get_as_text()
	file.close()

	# =================================================================
	# PARSE JSON
	# =================================================================
	var json := JSON.new()
	var parse_result := json.parse(json_str)
	
	# Kiểm tra parse thành công không
	if parse_result != OK:
		push_error("[DM] JSON parse error: %s" % path)
		return

	# =================================================================
	# KHỞI TẠO TRẠNG THÁI HỘI THOẠI
	# =================================================================
	_current_dialogue = json.get_data()  # Lưu nội dung dialogue
	_current_npc = npc_name              # Lưu tên NPC
	_current_npc_id = npc_id             # Lưu NPC id (dùng cho quest lookup)
	_current_line = 0                    # Bắt đầu từ dòng 0
	_pending_action = ""                 # Chưa có action nào chờ
	is_active = true                     # Đánh dấu đang active
	
	# Khóa người chơi không cho di chuyển
	GameState.game_interacting = true
	
	# Phát tín hiệu bắt đầu
	dialogue_started.emit(npc_name)
	
	# Hiển thị dòng đầu tiên
	_show_line()
	
	print("[DM] Started: '%s'" % dialogue_id)


# =============================================================================
# HÀM HIỂN THỊ DÒNG HỘI THOẠI (_show_line)
# =============================================================================
# Hiển thị dòng hội thoại hiện tại lên UI
# Được gọi khi bắt đầu dialogue và khi người chơi bấm tiếp

func _show_line() -> void:
	# Lấy danh sách các dòng từ JSON
	var lines: Array = _current_dialogue.get("lines", [])
	
	# Nếu đã hết dòng -> kết thúc
	if _current_line >= lines.size():
		_end()
		return

	# Lấy nội dung dòng hiện tại
	var line: Dictionary = lines[_current_line]
	
	# Lấy thông tin người nói (mặc định là NPC hiện tại)
	var speaker: String = line.get("speaker", _current_npc)
	
	# Lấy nội dung text
	var text: String = line.get("text", "")
	
	# Lấy danh sách lựa chọn (nếu có)
	var choices: Array = line.get("choices", [])
	
	# Kiểm tra đây có phải dòng cuối không (để hiển thị nút đóng)
	var is_last: bool = (_current_line >= lines.size() - 1) and choices.is_empty()

	# =================================================================
	# GỌI UI ĐỂ HIỂN THỊ
	# =================================================================
	var ui: Node = _get_dialogue_ui()
	if ui == null:
		push_error("[DM] DialogueUI not found!")
		_end()
		return

	# Gọi hàm hiển thị của UI
	ui.show_text(speaker, text, choices, is_last)


# =============================================================================
# HÀM CHUYỂN DÒNG TIẾP THEO (advance)
# =============================================================================
# Được gọi khi người chơi bấm nút "Tiếp" hoặc "Next"
# Chuyển sang dòng hội thoại tiếp theo

func advance() -> void:
	# Không làm gì nếu không active
	if not is_active:
		return
	
	# Tăng index dòng hiện tại
	_current_line += 1
	
	# Hiển thị dòng tiếp theo
	_show_line()


# =============================================================================
# HÀM ĐÓNG HỘI THOẠI (close)
# =============================================================================
# Đóng hội thoại (khi người chơi bấm nút X hoặc hết dialogue)
# Chỉ đơn giản là gọi _end()

func close() -> void:
	print("[DM] close() called.")
	_end()


# =============================================================================
# HÀM KẾT THÚC HỘI THOẠI (end_dialogue)
# =============================================================================
# Alias cho close() - kết thúc hội thoại
# Dùng khi cần kết thúc từ bên ngoài

func end_dialogue() -> void:
	close()


# =============================================================================
# HÀM CHỌN LỰA CHỌN (select_choice)
# =============================================================================
# Được gọi khi người chơi chọn một lựa chọn trong dialogue
#
# Tham số:
#   index: int - thứ tự lựa chọn (0, 1, 2, ...)

func select_choice(index: int) -> void:
	# Không làm gì nếu không active
	if not is_active:
		return

	# Lấy danh sách dòng
	var lines: Array = _current_dialogue.get("lines", [])

	# Lấy dữ liệu lựa chọn của dòng hiện tại
	var choice_data: Array = lines[_current_line].get("choices_data", [])

	# Kiểm tra index hợp lệ
	if index >= choice_data.size():
		return

	# Lấy action từ lựa chọn
	var action: String = choice_data[index].get("action", "")

	# Lưu action để thực hiện sau
	_pending_action = action

	# Ẩn choices ngay lập tức
	var ui: Node = _get_dialogue_ui()
	if ui != null:
		ui._clear_choices()

	# Thực hiện action ngay
	_execute_action(action)


# =============================================================================
# HÀM THỰC HIỆN ACTION (_execute_action)
# =============================================================================
# Thực hiện action sau khi chọn lựa chọn
# Actions có thể: đóng dialogue, thêm item, bắt đầu quest...
#
# Tham số:
#   action: String - action cần thực hiện

func _execute_action(action: String) -> void:
	# Xử lý theo loại action
	match action:
		"close":
			# Đóng dialogue ngay lập tức
			_end()
		"confirm_delivery":
			# Xác nhận giao hàng - hoàn thành quest delivery
			print("[DM] confirm_delivery action triggered")
			var ok: bool = _try_complete_delivery()
			print("[DM] complete_delivery_quest returned: %s" % str(ok))
			# Chuyển sang dòng cảm ơn (line tiếp theo). Player ấn tiếp/click để tắt.
			_current_line += 1
			_show_line()
		"cancel_delivery":
			# Hủy giao hàng - chỉ đóng dialogue ngay
			print("[DM] Delivery cancelled by player.")
			_end()


# =============================================================================
# HÀM HOÀN THÀNH GIAO HÀNG (_try_complete_delivery)
# =============================================================================
# Tìm quest delivery active và hoàn thành nó

func _try_complete_delivery() -> bool:
	# Tìm delivery quest đang active cho NPC hiện tại (không phải bất kỳ NPC nào)
	# để tránh complete nhầm quest của NPC khác.
	var active_quests: Array = QuestSystem.get_active_quests()
	var lookup_id: String = _current_npc_id if _current_npc_id != "" else _current_npc
	for quest: Dictionary in active_quests:
		if quest.get("type", "") != "delivery":
			continue
		var giver: String = quest.get("giver", "")
		if giver != lookup_id:
			continue
		var quest_id: String = quest.get("id", "")
		var req_item: String = quest.get("required_item", "")
		var req_amount: int = int(quest.get("required_amount", 0))
		print("[DM] Trying to complete delivery quest %s for %s (need %d x %s)" % [quest_id, giver, req_amount, req_item])
		var ok: bool = QuestSystem.complete_delivery_quest(quest_id)
		if ok:
			print("[DM] Delivery quest %s completed successfully." % quest_id)
			return true
		else:
			print("[DM] Delivery quest %s FAILED to complete." % quest_id)
	print("[DM] No matching delivery quest found for current NPC '%s'." % lookup_id)
	return false


# =============================================================================
# HÀM KẾT THÚC (_end)
# =============================================================================
# Kết thúc hội thoại, dọn dẹp trạng thái
# Được gọi khi dialogue kết thúc hoặc người chơi đóng

func _end() -> void:
	# Reset trạng thái
	is_active = false
	GameState.game_interacting = false  # Cho phép người chơi di chuyển
	_pending_action = ""

	# Ẩn UI dialogue
	var ui: Node = _get_dialogue_ui()
	if ui != null:
		ui.hide_dialogue()

	# Clear dữ liệu
	_current_dialogue = {}
	_current_line = 0
	_current_npc = ""
	_current_npc_id = ""

	# Phát tín hiệu kết thúc
	dialogue_ended.emit()
	dialogue_closed.emit()
	
	print("[DM] Dialogue ended.")


# =============================================================================
# HÀM TÌM DIALOGUE UI (_get_dialogue_ui)
# =============================================================================
# Tìm node DialogueUI trong scene tree
#
# Trả về: Node DialogueUI nếu tìm thấy, null nếu không

func _get_dialogue_ui() -> Node:
	var scene: SceneTree = get_tree()
	if scene == null:
		return null

	# Ưu tiên tìm node có script dialogue_ui.gd trong toàn bộ scene tree
	# (DialogueUI có thể nằm trong current_scene HOẶC ở root nếu được spawn
	# bởi WorldUIManager với CanvasLayer riêng).
	var root_node: Node = scene.root
	if root_node != null:
		var by_script: Node = _find_node_with_script(root_node)
		if by_script != null:
			return by_script

	# Fallback: tìm theo tên "DialogueUI" trong current_scene (cấu trúc cũ)
	var root_scene: Node = scene.current_scene
	if root_scene != null:
		var found: Node = _find_child(root_scene, "DialogueUI")
		if found != null:
			return found
	return null

func _find_node_with_script(root_node: Node) -> Node:
	if root_node == null:
		return null
	if root_node.get_script() != null:
		var sp: String = root_node.get_script().resource_path
		if sp == "res://scripts/ui/dialogue_ui.gd":
			return root_node
	for child in root_node.get_children():
		var r: Node = _find_node_with_script(child)
		if r != null:
			return r
	return null


# =============================================================================
# HÀM TÌM NODE CON (_find_child)
# =============================================================================
# Tìm node con theo tên trong scene tree (đệ quy)
#
# Tham số:
#   root: Node - node bắt đầu tìm
#   name: String - tên node cần tìm
#
# Trả về: Node nếu tìm thấy, null nếu không

func _find_child(root: Node, name: String) -> Node:
	# Kiểm tra node rỗng
	if root == null:
		return null
	
	# Nếu đây là node cần tìm
	if root.name == name:
		return root
	
	# Tìm trong các node con
	for child in root.get_children():
		var result: Node = _find_child(child, name)
		if result != null:
			return result
	
	return null
