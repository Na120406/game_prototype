extends CanvasLayer
# =============================================================================
# QUEST BOARD UI (Popup nhận quest)
# =============================================================================
# Popup đơn giản hiển thị quest available cho NPC id. Player nhấn Accept →
# QuestSystem.accept_quest() và đóng popup. Nếu không có quest → chỉ hiện
# thông báo "Không có nhiệm vụ hôm nay".

@export var board_id: String = "neighbor_board"
@export var quest_giver_npc_id: String = "neighbor"

var _root: Control = null
var _title_label: Label = null
var _quest_container: ScrollContainer = null
var _quest_list: VBoxContainer = null
var _no_quest_label: Label = null
var _close_button: Button = null
var _selected_quest_id: String = ""

func _ready() -> void:
	layer = 110
	_build_ui()
	_refresh_quests()
	# Lắng nghe signal không thể nhận quest vì item trùng lặp
	QuestSystem.quest_rejected_duplicate_item.connect(_on_quest_rejected_duplicate_item)

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	# Dim background để popup nổi bật.
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	# Panel ở giữa màn hình.
	var panel := PanelContainer.new()
	panel.position = Vector2(40, 50)
	panel.size = Vector2(300, 200)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)

	_title_label = Label.new()
	_title_label.text = "Quest Board"
	_title_label.add_theme_font_size_override("font_size", 14)
	_title_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	vb.add_child(_title_label)

	_quest_container = ScrollContainer.new()
	_quest_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_quest_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(_quest_container)

	_quest_list = VBoxContainer.new()
	_quest_list.add_theme_constant_override("separation", 4)
	_quest_container.add_child(_quest_list)

	_no_quest_label = Label.new()
	_no_quest_label.text = ""
	_no_quest_label.add_theme_font_size_override("font_size", 10)
	_no_quest_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
	vb.add_child(_no_quest_label)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	vb.add_child(hb)

	_close_button = Button.new()
	_close_button.text = "Close"
	_close_button.add_theme_font_size_override("font_size", 10)
	_close_button.pressed.connect(_on_close_pressed)
	hb.add_child(_close_button)

func _refresh_quests() -> void:
	# Clear existing quest items
	for child: Node in _quest_list.get_children():
		child.queue_free()

	# Kiểm tra hôm nay có quest không (đã roll trong cache daily)
	if not QuestSystem.has_quests_today(quest_giver_npc_id):
		_no_quest_label.text = "No quests today. Check back tomorrow."
		return

	# Lấy quest từ bảng tin (bao gồm quest tĩnh + quest ngẫu nhiên)
	var quests: Array = QuestSystem.get_quests_for_board(quest_giver_npc_id)

	if quests.is_empty():
		_no_quest_label.text = "No quests today. Check back tomorrow."
		return

	_no_quest_label.text = ""

	# Tạo button cho mỗi quest
	for quest: Dictionary in quests:
		var quest_id: String = quest.get("id", "")
		var qname: String = quest.get("name", "Quest")
		var qdesc: String = quest.get("description", "")
		var required_item: String = quest.get("required_item", "")
		var required_amount: int = int(quest.get("required_amount", 0))
		var qreward: Dictionary = quest.get("reward", {})
		var days_min: int = int(quest.get("days_to_complete_min", 2))
		var days_max: int = int(quest.get("days_to_complete_max", 3))

		# Kiểm tra quest đã được nhận chưa
		var is_already_active: bool = QuestSystem.is_quest_active(quest_id)
		var is_completed: bool = QuestSystem.is_quest_completed(quest_id)

		# Build reward text
		var reward_text: String = ""
		if qreward.has("gold"):
			reward_text = "%d gold" % int(qreward.get("gold", 0))
		if qreward.has("relationship"):
			if reward_text != "":
				reward_text += " + "
			reward_text += "+%d rel" % int(qreward.get("relationship", 0))

		# Tạo panel cho quest
		var quest_panel := PanelContainer.new()
		quest_panel.add_theme_stylebox_override("panel", _create_quest_stylebox())
		# Nếu đã nhận hoặc hoàn thành thì làm mờ panel
		if is_already_active or is_completed:
			quest_panel.modulate = Color(0.6, 0.6, 0.6, 0.8)
		_quest_list.add_child(quest_panel)

		var quest_vb := VBoxContainer.new()
		quest_vb.add_theme_constant_override("separation", 2)
		quest_panel.add_child(quest_vb)

		# Tên quest
		var name_label := Label.new()
		name_label.text = qname
		name_label.add_theme_font_size_override("font_size", 11)
		if is_completed:
			name_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5, 0.7))
		elif is_already_active:
			name_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6, 0.7))
		else:
			name_label.add_theme_color_override("font_color", Color(1, 0.9, 0.6, 1))
		quest_vb.add_child(name_label)

		# Mô tả
		var desc_label := Label.new()
		desc_label.text = qdesc
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.add_theme_font_size_override("font_size", 9)
		desc_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 0.7))
		quest_vb.add_child(desc_label)

		# Reward + deadline
		var info_label := Label.new()
		info_label.text = "Reward: %s | Deadline: %d-%d days" % [reward_text, days_min, days_max]
		info_label.add_theme_font_size_override("font_size", 8)
		if is_completed:
			info_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5, 0.5))
		elif is_already_active:
			info_label.add_theme_color_override("font_color", Color(0.5, 1, 0.5, 0.6))
		else:
			info_label.add_theme_color_override("font_color", Color(0.6, 1, 0.6, 1))
		quest_vb.add_child(info_label)

		# Nút Accept
		var accept_btn := Button.new()
		if is_completed:
			accept_btn.text = "Completed"
			accept_btn.disabled = true
		elif is_already_active:
			accept_btn.text = "Accepted"
			accept_btn.disabled = true
		else:
			accept_btn.text = "Accept"
			accept_btn.pressed.connect(_on_quest_accept_pressed.bind(quest_id, quest))
		accept_btn.add_theme_font_size_override("font_size", 9)
		quest_vb.add_child(accept_btn)

func _create_quest_stylebox() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2, 0.9)
	style.border_color = Color(0.3, 0.3, 0.4, 1)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 8
	style.content_margin_top = 6
	style.content_margin_right = 8
	style.content_margin_bottom = 6
	return style

func _on_quest_accept_pressed(quest_id: String, quest_data: Dictionary) -> void:
	var ok: bool = QuestSystem.accept_quest(quest_id, quest_data)
	if ok:
		GameState.quest_appearance_bonus = 0.0
		GameState.quest_bonus_day = GameState.current_day
		print("[QuestBoardUI] Quest accepted: %s" % quest_id)
		# Refresh UI để hiển thị trạng thái "Accepted"
		_refresh_quests()
		# Đóng sau một chút để user thấy thay đổi
		await get_tree().create_timer(0.3).timeout
		_close()
	# Không hiện thông báo gì khi thất bại - đã có signal quest_rejected_duplicate_item

func _on_quest_rejected_duplicate_item(item_id: String, quest_id: String) -> void:
	# Lấy tên item để hiển thị thông báo
	var item_name: String = item_id
	var db = get_node_or_null("/root/ItemDB")
	if db != null and db.has_method("get_item"):
		var item_data = db.get_item(item_id)
		if item_data != null:
			item_name = item_data.get("name", item_id)

	# Hiển thị thông báo "đã nhận quest với item này rồi"
	var msg: String = "Bạn đã nhận nhiệm vụ giao %s rồi!\nHoàn thành quest cũ trước." % item_name
	_show_message(msg)

func _show_message(msg: String) -> void:
	if _no_quest_label != null:
		_no_quest_label.text = msg
		_no_quest_label.modulate = Color(1, 0.3, 0.3, 1)  # Màu đỏ
		_no_quest_label.visible = true
	print("[QuestBoardUI] Message: %s" % msg)

func _on_close_pressed() -> void:
	_close()

func _close() -> void:
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		_close()
