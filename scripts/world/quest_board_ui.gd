extends CanvasLayer
# =============================================================================
# QUEST BOARD UI — Popup nhận quest (v2: scene + get_node, giống inventory_ui)
# =============================================================================
# Layout:
#   ┌─TitleBox─┐
#   │QUEST BOARD│      ← ô nhỏ chính giữa trên cùng
#   └──────────┘
#   ┌─────────── ListBox ────────────┐
#   │  [quest item]                  │
#   │  [quest item]                  │
#   └────────────────────────────────┘
#   [X]                              ← nút đóng ở góc trên phải
#
# Tương tác:
# - Player bấm Accept → QuestSystem.accept_quest() + đóng popup.
# - Nếu không có quest → chỉ hiện "Không có nhiệm vụ hôm nay".
# =============================================================================

@export var board_id: String = "neighbor_board"
@export var quest_giver_npc_id: String = "neighbor"

@export_group("Panel Layout")
## Tổng chiều rộng panel (bao gồm padding)
@export_range(100, 400, 1) var panel_width: int = 228 :
	set(v): panel_width = v; _apply_layout_if_ready(); _save_config()
## Tổng chiều cao panel (bao gồm padding)
@export_range(80, 300, 1) var panel_height: int = 186 :
	set(v): panel_height = v; _apply_layout_if_ready(); _save_config()
## Độ dời X từ tâm viewport
@export_range(-500, 500, 1) var offset_x: int = 0 :
	set(v): offset_x = v; _apply_layout_if_ready(); _save_config()
## Độ dời Y từ tâm viewport
@export_range(-500, 500, 1) var offset_y: int = 0 :
	set(v): offset_y = v; _apply_layout_if_ready(); _save_config()

@export_group("Title Box")
## Text hiển thị trên title tab
@export var title_text: String = "BẢNG NHIỆM VỤ" :
	set(v): title_text = v; _apply_title_text_if_ready(); _save_config()
## Chiều rộng title box
@export_range(40, 150, 1) var title_width: int = 80 :
	set(v): title_width = v; _apply_layout_if_ready(); _save_config()
## Chiều cao title box
@export_range(16, 50, 1) var title_height: int = 20 :
	set(v): title_height = v; _apply_layout_if_ready(); _save_config()
## Font size của title text
@export_range(6, 24, 1) var title_font_size: int = 9 :
	set(v): title_font_size = v; _apply_title_font_if_ready(); _save_config()
## Màu title text
@export var title_text_color: Color = Color(1, 1, 1, 1) :
	set(v): title_text_color = v; _apply_title_font_if_ready(); _save_config()
## Canh lề ngang text (0=Trái, 1=Giữa, 2=Phải)
@export_range(0, 2, 1, "or_greater") var title_horizontal_alignment: int = 1 :
	set(v): title_horizontal_alignment = v; _apply_title_alignment_if_ready(); _save_config()
## Canh lề dọc text (0=Trên, 1=Giữa, 2=Dưới)
@export_range(0, 2, 1, "or_greater") var title_vertical_alignment: int = 1 :
	set(v): title_vertical_alignment = v; _apply_title_alignment_if_ready(); _save_config()
## Độ dời X của title box (từ tâm panel)
@export_range(-200, 200, 1) var title_offset_x: int = 0 :
	set(v): title_offset_x = v; _apply_layout_if_ready(); _save_config()
## Độ dời Y của title box (từ vị trí mặc định)
@export_range(-200, 200, 1) var title_offset_y: int = 0 :
	set(v): title_offset_y = v; _apply_layout_if_ready(); _save_config()

@export_group("Quest List Box")
## Độ dời X của list box (từ mép trái panel)
@export_range(-100, 100, 1) var list_offset_x: int = 0 :
	set(v): list_offset_x = v; _apply_layout_if_ready(); _save_config()
## Độ dời Y của list box (từ title box)
@export_range(-100, 100, 1) var list_offset_y: int = 0 :
	set(v): list_offset_y = v; _apply_layout_if_ready(); _save_config()
## Chiều rộng list box
@export_range(50, 400, 1) var list_width: int = 0 :
	set(v): list_width = v; _apply_layout_if_ready(); _save_config()
## Chiều cao list box
@export_range(50, 300, 1) var list_height: int = 0 :
	set(v): list_height = v; _apply_layout_if_ready(); _save_config()

@export_group("No Quest Label")
## Text khi không có quest
@export var no_quest_text: String = "Khong co nhiem vu hom nay" :
	set(v): no_quest_text = v; _apply_no_quest_text_if_ready(); _save_config()
## Canh lề ngang (0=Trái, 1=Giữa, 2=Phải)
@export_range(0, 2, 1, "or_greater") var no_quest_horizontal_alignment: int = 1 :
	set(v): no_quest_horizontal_alignment = v; _apply_no_quest_alignment_if_ready(); _save_config()
## Canh lề dọc (0=Trên, 1=Giữa, 2=Dưới)
@export_range(0, 2, 1, "or_greater") var no_quest_vertical_alignment: int = 1 :
	set(v): no_quest_vertical_alignment = v; _apply_no_quest_alignment_if_ready(); _save_config()
## Độ dời X của label
@export_range(-100, 100, 1) var no_quest_offset_x: int = 0 :
	set(v): no_quest_offset_x = v; _apply_no_quest_position_if_ready(); _save_config()
## Độ dời Y của label
@export_range(-100, 100, 1) var no_quest_offset_y: int = 0 :
	set(v): no_quest_offset_y = v; _apply_no_quest_position_if_ready(); _save_config()

@export_group("Colors")
## Màu nền panel
@export var bg_color: Color = Color(0.06, 0.04, 0.1, 0.97) :
	set(v): bg_color = v; _apply_colors_if_ready(); _save_config()
## Màu viền
@export var border_color: Color = Color(0.85, 0.68, 0.38, 1.0) :
	set(v): border_color = v; _apply_colors_if_ready(); _save_config()
## Bán kính bo góc
@export_range(0, 16, 1) var corner_radius: int = 4 :
	set(v): corner_radius = v; _apply_colors_if_ready(); _save_config()
## Độ dày viền
@export_range(0, 8, 1) var border_width: int = 2 :
	set(v): border_width = v; _apply_colors_if_ready(); _save_config()
## Màu backdrop nền (0 = trong suốt)
@export_range(0, 1, 0.01) var backdrop_alpha: float = 0.55 :
	set(v): backdrop_alpha = v; _apply_backdrop_if_ready(); _save_config()

@export_group("Quest Item")
## Chiều cao mỗi quest item
@export_range(30, 120, 1) var quest_item_height: int = 72 :
	set(v): quest_item_height = v; _apply_item_style_if_ready(); _save_config()
## Màu nền item
@export var item_bg_color: Color = Color(0.04, 0.02, 0.07, 0.97) :
	set(v): item_bg_color = v; _apply_item_style_if_ready(); _save_config()
## Màu item khi hover
@export var item_hover_color: Color = Color(0.12, 0.08, 0.18, 1.0) :
	set(v): item_hover_color = v; _apply_item_style_if_ready(); _save_config()
## Màu reward (vàng)
@export var reward_color: Color = Color(1.0, 0.85, 0.5, 1.0) :
	set(v): reward_color = v; _apply_item_style_if_ready(); _save_config()

var _dim_bg: ColorRect = null
var _panel: Control = null
var _title_box: PanelContainer = null
var _title_label: Label = null
var _list_box: PanelContainer = null
var _scroll: ScrollContainer = null
var _quest_list: VBoxContainer = null
var _no_quest_label: Label = null
var _close_button: Button = null

# --- Config save/load ---
const CONFIG_PATH := "user://quest_board_ui_config.cfg"
var _config: ConfigFile = null
var _is_loading_config := false

func _load_config() -> void:
	_is_loading_config = true
	_config = ConfigFile.new()
	var err := _config.load(CONFIG_PATH)
	if err == OK:
		panel_width = _config.get_value("panel", "panel_width", panel_width)
		panel_height = _config.get_value("panel", "panel_height", panel_height)
		offset_x = _config.get_value("panel", "offset_x", offset_x)
		offset_y = _config.get_value("panel", "offset_y", offset_y)
		title_offset_x = _config.get_value("title", "title_offset_x", title_offset_x)
		title_offset_y = _config.get_value("title", "title_offset_y", title_offset_y)
		title_width = _config.get_value("title", "title_width", title_width)
		title_height = _config.get_value("title", "title_height", title_height)
		title_font_size = _config.get_value("title", "title_font_size", title_font_size)
		title_horizontal_alignment = _config.get_value("title", "title_horizontal_alignment", title_horizontal_alignment)
		title_vertical_alignment = _config.get_value("title", "title_vertical_alignment", title_vertical_alignment)
		list_offset_x = _config.get_value("list", "list_offset_x", list_offset_x)
		list_offset_y = _config.get_value("list", "list_offset_y", list_offset_y)
		list_width = _config.get_value("list", "list_width", list_width)
		list_height = _config.get_value("list", "list_height", list_height)
		no_quest_text = _config.get_value("noquest", "no_quest_text", no_quest_text)
		no_quest_horizontal_alignment = _config.get_value("noquest", "no_quest_horizontal_alignment", no_quest_horizontal_alignment)
		no_quest_vertical_alignment = _config.get_value("noquest", "no_quest_vertical_alignment", no_quest_vertical_alignment)
		no_quest_offset_x = _config.get_value("noquest", "no_quest_offset_x", no_quest_offset_x)
		no_quest_offset_y = _config.get_value("noquest", "no_quest_offset_y", no_quest_offset_y)
		bg_color = _config.get_value("colors", "bg_color", bg_color)
		border_color = _config.get_value("colors", "border_color", border_color)
		corner_radius = _config.get_value("colors", "corner_radius", corner_radius)
		border_width = _config.get_value("colors", "border_width", border_width)
		backdrop_alpha = _config.get_value("colors", "backdrop_alpha", backdrop_alpha)
		item_bg_color = _config.get_value("items", "item_bg_color", item_bg_color)
		item_hover_color = _config.get_value("items", "item_hover_color", item_hover_color)
		reward_color = _config.get_value("items", "reward_color", reward_color)
		quest_item_height = _config.get_value("items", "quest_item_height", quest_item_height)
		print("[QuestBoardUI] Config loaded from %s" % CONFIG_PATH)
	_is_loading_config = false

func _save_config() -> void:
	if _is_loading_config:
		return
	_config = ConfigFile.new()
	_config.set_value("panel", "panel_width", panel_width)
	_config.set_value("panel", "panel_height", panel_height)
	_config.set_value("panel", "offset_x", offset_x)
	_config.set_value("panel", "offset_y", offset_y)
	_config.set_value("title", "title_offset_x", title_offset_x)
	_config.set_value("title", "title_offset_y", title_offset_y)
	_config.set_value("title", "title_width", title_width)
	_config.set_value("title", "title_height", title_height)
	_config.set_value("title", "title_font_size", title_font_size)
	_config.set_value("title", "title_horizontal_alignment", title_horizontal_alignment)
	_config.set_value("title", "title_vertical_alignment", title_vertical_alignment)
	_config.set_value("list", "list_offset_x", list_offset_x)
	_config.set_value("list", "list_offset_y", list_offset_y)
	_config.set_value("list", "list_width", list_width)
	_config.set_value("list", "list_height", list_height)
	_config.set_value("noquest", "no_quest_text", no_quest_text)
	_config.set_value("noquest", "no_quest_horizontal_alignment", no_quest_horizontal_alignment)
	_config.set_value("noquest", "no_quest_vertical_alignment", no_quest_vertical_alignment)
	_config.set_value("noquest", "no_quest_offset_x", no_quest_offset_x)
	_config.set_value("noquest", "no_quest_offset_y", no_quest_offset_y)
	_config.set_value("colors", "bg_color", bg_color)
	_config.set_value("colors", "border_color", border_color)
	_config.set_value("colors", "corner_radius", corner_radius)
	_config.set_value("colors", "border_width", border_width)
	_config.set_value("colors", "backdrop_alpha", backdrop_alpha)
	_config.set_value("items", "item_bg_color", item_bg_color)
	_config.set_value("items", "item_hover_color", item_hover_color)
	_config.set_value("items", "reward_color", reward_color)
	_config.set_value("items", "quest_item_height", quest_item_height)
	var err := _config.save(CONFIG_PATH)
	if err == OK:
		print("[QuestBoardUI] Config saved to %s" % CONFIG_PATH)
	else:
		print("[QuestBoardUI] Failed to save config: %d" % err)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_cache_nodes()
	_load_config()
	_apply_layout()
	_apply_colors()
	_apply_title_text()
	_apply_title_font()
	_apply_title_alignment()
	_apply_no_quest_text()
	_apply_no_quest_alignment()
	_apply_no_quest_position()
	_apply_item_style_for_all()
	if _close_button != null:
		_close_button.pressed.connect(_close)
	QuestSystem.quest_rejected_duplicate_item.connect(_on_quest_rejected_duplicate_item)
	set_process_unhandled_input(true)

func _cache_nodes() -> void:
	_dim_bg = get_node_or_null("BackdropLayer/DimBG")
	_panel = get_node_or_null("Root/Panel")
	_title_box = get_node_or_null("Root/Panel/TitleBox") as PanelContainer
	_title_label = get_node_or_null("Root/Panel/Title") as Label
	_list_box = get_node_or_null("Root/Panel/ListBox") as PanelContainer
	_scroll = get_node_or_null("Root/Panel/ListBox/Scroll") as ScrollContainer
	_quest_list = get_node_or_null("Root/Panel/ListBox/Scroll/QuestList") as VBoxContainer
	_no_quest_label = get_node_or_null("Root/Panel/NoQuestLabel") as Label
	_close_button = get_node_or_null("Root/Panel/CloseButton") as Button

# --- Layout ---
func _apply_layout() -> void:
	if _panel == null or not is_inside_tree():
		return
	var pw := float(panel_width)
	var ph := float(panel_height)
	_panel.offset_left = -pw * 0.5 + offset_x
	_panel.offset_top = -ph * 0.5 + offset_y
	_panel.offset_right = pw * 0.5 + offset_x
	_panel.offset_bottom = ph * 0.5 + offset_y

	if _title_box != null:
		var tw := float(title_width)
		var th := float(title_height)
		_title_box.offset_left = (pw - tw) * 0.5 + float(title_offset_x)
		_title_box.offset_top = 4.0 + float(title_offset_y)
		_title_box.offset_right = (pw + tw) * 0.5 + float(title_offset_x)
		_title_box.offset_bottom = 4.0 + th + float(title_offset_y)

	if _title_label != null:
		_title_label.offset_left = (pw - float(title_width)) * 0.5 + float(title_offset_x)
		_title_label.offset_top = 4.0 + float(title_offset_y)
		_title_label.offset_right = (pw + float(title_width)) * 0.5 + float(title_offset_x)
		_title_label.offset_bottom = 4.0 + float(title_height) + float(title_offset_y)

	if _list_box != null:
		var lw: float
		var lh: float
		if list_width == 0:
			lw = pw - 8.0
		else:
			lw = float(list_width)
		if list_height == 0:
			lh = ph - float(title_height) - 16.0
		else:
			lh = float(list_height)
		_list_box.offset_left = 4.0 + float(list_offset_x)
		_list_box.offset_top = float(title_height) + 10.0 + float(list_offset_y)
		_list_box.offset_right = _list_box.offset_left + lw
		_list_box.offset_bottom = _list_box.offset_top + lh

func _apply_layout_if_ready() -> void:
	if _panel != null:
		_apply_layout()

# --- Title text ---
func _apply_title_text() -> void:
	if _title_label != null:
		_title_label.text = _tr("ui.quest.title", title_text)

func _apply_title_text_if_ready() -> void:
	if _title_label != null:
		_apply_title_text()

func _apply_title_font() -> void:
	if _title_label != null:
		_title_label.add_theme_font_size_override("font_size", title_font_size)
		_title_label.add_theme_color_override("font_color", title_text_color)

func _apply_title_font_if_ready() -> void:
	if _title_label != null:
		_apply_title_font()

func _apply_title_alignment() -> void:
	if _title_label != null:
		_title_label.horizontal_alignment = title_horizontal_alignment as HorizontalAlignment
		_title_label.vertical_alignment = title_vertical_alignment as VerticalAlignment

func _apply_title_alignment_if_ready() -> void:
	if _title_label != null:
		_apply_title_alignment()

# --- No Quest Label ---
func _apply_no_quest_text() -> void:
	if _no_quest_label != null:
		_no_quest_label.text = _tr("ui.quest.no_quest", no_quest_text)

func _apply_no_quest_text_if_ready() -> void:
	if _no_quest_label != null:
		_apply_no_quest_text()

func _apply_no_quest_alignment() -> void:
	if _no_quest_label != null:
		_no_quest_label.horizontal_alignment = no_quest_horizontal_alignment as HorizontalAlignment
		_no_quest_label.vertical_alignment = no_quest_vertical_alignment as VerticalAlignment

func _apply_no_quest_alignment_if_ready() -> void:
	if _no_quest_label != null:
		_apply_no_quest_alignment()

func _apply_no_quest_position() -> void:
	if _no_quest_label != null and _panel != null:
		var pw := float(panel_width)
		var ph := float(panel_height)
		_no_quest_label.offset_left = 8.0 + float(no_quest_offset_x)
		_no_quest_label.offset_top = float(title_height) + 16.0 + float(no_quest_offset_y)
		_no_quest_label.offset_right = pw - 8.0 + float(no_quest_offset_x)
		_no_quest_label.offset_bottom = ph - 8.0 + float(no_quest_offset_y)

func _apply_no_quest_position_if_ready() -> void:
	if _no_quest_label != null and _panel != null:
		_apply_no_quest_position()

# --- Colors ---
func _apply_colors() -> void:
	_apply_box_style(_title_box)
	_apply_box_style(_list_box)

func _apply_colors_if_ready() -> void:
	if _title_box != null:
		_apply_colors()

func _apply_box_style(box: PanelContainer) -> void:
	if box == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.expand_margin_left = 3.0
	style.expand_margin_top = 3.0
	style.expand_margin_right = 3.0
	style.expand_margin_bottom = 3.0
	box.add_theme_stylebox_override("panel", style)

# --- Backdrop ---
func _apply_backdrop() -> void:
	if _dim_bg != null:
		_dim_bg.color = Color(0, 0, 0, backdrop_alpha)

func _apply_backdrop_if_ready() -> void:
	if _dim_bg != null:
		_apply_backdrop()

# --- Item style ---
func _apply_item_style_for_all() -> void:
	if _quest_list == null:
		return
	for child in _quest_list.get_children():
		if child is PanelContainer:
			_apply_single_item_style(child, false)

func _apply_item_style_if_ready() -> void:
	_apply_item_style_for_all()

func _apply_single_item_style(item: PanelContainer, hovered: bool) -> void:
	if item == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = item_hover_color if hovered else item_bg_color
	style.border_color = Color(0.5, 0.4, 0.25, 1.0)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_right = 3
	style.corner_radius_bottom_left = 3
	style.content_margin_left = 6
	style.content_margin_top = 4
	style.content_margin_right = 6
	style.content_margin_bottom = 4
	item.add_theme_stylebox_override("panel", style)

# --- Public API ---
func open() -> void:
	_refresh_quests()
	visible = true
	if _dim_bg != null:
		_dim_bg.visible = true

func close() -> void:
	visible = false
	if _dim_bg != null:
		_dim_bg.visible = false

func _close() -> void:
	close()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_E:
			close()
			get_viewport().set_input_as_handled()

# --- Quest list ---
func _refresh_quests() -> void:
	if _quest_list == null:
		return
	for child in _quest_list.get_children():
		child.queue_free()

	# Dùng get_quests_for_board để lấy quests hiển thị trên bảng (bao gồm cả dynamic quests)
	var quests: Array = QuestSystem.get_quests_for_board(quest_giver_npc_id)
	if quests.is_empty():
		if _no_quest_label != null:
			_no_quest_label.visible = true
		if _scroll != null:
			_scroll.visible = false
		return
	if _no_quest_label != null:
		_no_quest_label.visible = false
	if _scroll != null:
		_scroll.visible = true

	for q in quests:
		var quest_data: Dictionary = q
		var item := _create_quest_item(quest_data)
		_quest_list.add_child(item)

func _tr(key: String, fallback: String = "") -> String:
	var cm: Node = get_node_or_null("/root/ConfigManager")
	return cm.translate_text(key, fallback) if cm != null and cm.has_method("translate_text") else fallback

func _create_quest_item(quest_data: Dictionary) -> Control:
	var item := PanelContainer.new()
	item.custom_minimum_size = Vector2(float(panel_width) - 24.0, float(quest_item_height))
	_apply_single_item_style(item, false)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	item.add_child(vbox)

	# Title - dùng "name" hoặc "title" tùy quest type
	var title := Label.new()
	var title_key: String = str(quest_data.get("name_key", ""))
	title.text = _tr(title_key, str(quest_data.get("name", quest_data.get("title", "?")))) if title_key != "" else str(quest_data.get("name", quest_data.get("title", "?")))
	title.add_theme_font_size_override("font_size", 9)
	title.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	title.add_theme_constant_override("outline_size", 2)
	vbox.add_child(title)

	# Description (truncate)
	var desc_key: String = str(quest_data.get("description_key", ""))
	var desc_text := _tr(desc_key, str(quest_data.get("description", ""))) if desc_key != "" else str(quest_data.get("description", ""))
	if desc_text.length() > 60:
		desc_text = desc_text.substr(0, 57) + "..."
	var desc := Label.new()
	desc.text = desc_text
	desc.add_theme_font_size_override("font_size", 7)
	desc.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 0.9))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	# Deadline label — hiển thị số ngày còn lại để hoàn thành quest.
	# Đối với quest đã nhận (có deadline_day) thì tính days_left; quest chưa
	# nhận thì hiển thị số ngày deadline dự kiến theo thời gian trồng cây.
	var deadline_label := Label.new()
	var days_left := _get_quest_days_left(quest_data)
	deadline_label.text = "%s %d %s" % [_tr("ui.quest.deadline", "Hạn chót:"), days_left, _tr("ui.quest.day", "ngày")]
	deadline_label.add_theme_font_size_override("font_size", 7)
	deadline_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.5, 1.0))
	vbox.add_child(deadline_label)

	# Bottom row: reward + Accept button
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	vbox.add_child(hbox)

	# Lấy reward từ quest data (hỗ trợ cả reward dict và reward_gold/reward_xp)
	var reward_dict: Dictionary = quest_data.get("reward", {})
	var gold: int = int(reward_dict.get("gold", quest_data.get("reward_gold", 0)))
	var relationship: int = int(reward_dict.get("relationship", 0))
	var reward_text := ""
	# Tránh emoji: font fallback trên Web export/itch.io không đảm bảo có glyph,
	# khiến emoji hiển thị thành ô vuông hoặc chuỗi ký tự lỗi.
	# Dùng nhãn Unicode phổ biến, được font mặc định hỗ trợ ổn định hơn.
	if gold > 0:
		reward_text = "Vàng: %d" % gold
	if relationship > 0:
		if reward_text != "":
			reward_text += "  |  "
		reward_text += "Quan hệ: %d" % relationship

	var reward := Label.new()
	reward.text = reward_text if reward_text != "" else ""
	reward.add_theme_font_size_override("font_size", 7)
	reward.add_theme_color_override("font_color", reward_color)
	reward.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(reward)

	var quest_id := str(quest_data.get("id", ""))
	var accept := Button.new()
	var is_accepted: bool = QuestSystem.is_quest_active(quest_id) or QuestSystem.is_quest_completed(quest_id) or QuestSystem.is_quest_failed(quest_id)
	if is_accepted:
		accept.text = _tr("ui.quest.accepted_button", "Đã nhận")
		accept.disabled = true
		accept.modulate = Color(0.6, 0.6, 0.6, 1.0)
	else:
		accept.text = _tr("ui.quest.accept_button", "Nhận")
		accept.pressed.connect(_on_accept_pressed.bind(quest_id, quest_data))
	accept.add_theme_font_size_override("font_size", 7)
	accept.custom_minimum_size = Vector2(40, 14)
	hbox.add_child(accept)

	# Hover effect
	item.mouse_entered.connect(_on_item_hover.bind(item, true))
	item.mouse_exited.connect(_on_item_hover.bind(item, false))
	return item

func _on_item_hover(item: PanelContainer, is_hovered: bool) -> void:
	_apply_single_item_style(item, is_hovered)

func _get_quest_days_left(quest_data: Dictionary) -> int:
	# Quest đã nhận → tính days_left từ deadline_day thực tế.
	var quest_id: String = str(quest_data.get("id", ""))
	if QuestSystem.is_quest_active(quest_id):
		var info: Dictionary = QuestSystem.get_quest_deadline(quest_id)
		return int(info.get("days_left", 0))
	# Quest chưa nhận → ước lượng deadline theo loại quest (cây trồng/normal).
	return QuestSystem.get_quest_deadline_days(quest_data)

func _on_accept_pressed(quest_id: String, quest_data: Dictionary) -> void:
	var ok: bool = QuestSystem.accept_quest(quest_id, quest_data)
	if ok:
		GameState.quest_appearance_bonus = 0.0
		GameState.quest_bonus_day = GameState.current_day
		print("[QuestBoardUI] Quest accepted: %s" % quest_id)
		_refresh_quests()
		await get_tree().create_timer(0.3).timeout
		close()

func _on_quest_rejected_duplicate_item(item_id: String, quest_id: String) -> void:
	print("[QuestBoardUI] Quest %s rejected — duplicate item %s" % [quest_id, item_id])
