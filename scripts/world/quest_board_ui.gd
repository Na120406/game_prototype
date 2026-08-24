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
	set(v): panel_width = v; _apply_layout_if_ready()
## Tổng chiều cao panel (bao gồm padding)
@export_range(80, 300, 1) var panel_height: int = 186 :
	set(v): panel_height = v; _apply_layout_if_ready()
## Độ dời X từ tâm viewport
@export_range(-500, 500, 1) var offset_x: int = 0 :
	set(v): offset_x = v; _apply_layout_if_ready()
## Độ dời Y từ tâm viewport
@export_range(-500, 500, 1) var offset_y: int = 0 :
	set(v): offset_y = v; _apply_layout_if_ready()

@export_group("Title Box")
## Text hiển thị trên title tab
@export var title_text: String = "QUEST BOARD" :
	set(v): title_text = v; _apply_title_text_if_ready()
## Chiều rộng title box
@export_range(40, 150, 1) var title_width: int = 80 :
	set(v): title_width = v; _apply_layout_if_ready()
## Chiều cao title box
@export_range(16, 50, 1) var title_height: int = 20 :
	set(v): title_height = v; _apply_layout_if_ready()
## Font size của title text
@export_range(6, 24, 1) var title_font_size: int = 9 :
	set(v): title_font_size = v; _apply_title_font_if_ready()
## Màu title text
@export var title_text_color: Color = Color(1, 1, 1, 1) :
	set(v): title_text_color = v; _apply_title_font_if_ready()

@export_group("Colors")
## Màu nền panel
@export var bg_color: Color = Color(0.06, 0.04, 0.1, 0.97) :
	set(v): bg_color = v; _apply_colors_if_ready()
## Màu viền
@export var border_color: Color = Color(0.85, 0.68, 0.38, 1.0) :
	set(v): border_color = v; _apply_colors_if_ready()
## Bán kính bo góc
@export_range(0, 16, 1) var corner_radius: int = 4 :
	set(v): corner_radius = v; _apply_colors_if_ready()
## Độ dày viền
@export_range(0, 8, 1) var border_width: int = 2 :
	set(v): border_width = v; _apply_colors_if_ready()
## Màu backdrop nền (0 = trong suốt)
@export_range(0, 1, 0.01) var backdrop_alpha: float = 0.55 :
	set(v): backdrop_alpha = v; _apply_backdrop_if_ready()

@export_group("Quest Item")
## Chiều cao mỗi quest item
@export_range(30, 120, 1) var quest_item_height: int = 56 :
	set(v): quest_item_height = v; _apply_item_style_if_ready()
## Màu nền item
@export var item_bg_color: Color = Color(0.04, 0.02, 0.07, 0.97) :
	set(v): item_bg_color = v; _apply_item_style_if_ready()
## Màu item khi hover
@export var item_hover_color: Color = Color(0.12, 0.08, 0.18, 1.0) :
	set(v): item_hover_color = v; _apply_item_style_if_ready()
## Màu reward (vàng)
@export var reward_color: Color = Color(1.0, 0.85, 0.5, 1.0) :
	set(v): reward_color = v; _apply_item_style_if_ready()

var _dim_bg: ColorRect = null
var _panel: Control = null
var _title_box: PanelContainer = null
var _title_label: Label = null
var _list_box: PanelContainer = null
var _scroll: ScrollContainer = null
var _quest_list: VBoxContainer = null
var _no_quest_label: Label = null
var _close_button: Button = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Ẩn mặc định — chỉ hiện khi gọi open()
	visible = false
	_cache_nodes()
	_apply_layout()
	_apply_colors()
	_apply_title_text()
	_apply_title_font()
	_apply_item_style_for_all()
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
		_title_box.offset_left = (pw - tw) * 0.5
		_title_box.offset_top = 4.0
		_title_box.offset_right = (pw + tw) * 0.5
		_title_box.offset_bottom = 4.0 + th

	# Title Label đặt đè lên TitleBox (sibling, điều khiển vị trí tự do)
	if _title_label != null:
		_title_label.offset_left = (pw - float(title_width)) * 0.5
		_title_label.offset_top = 4.0
		_title_label.offset_right = (pw + float(title_width)) * 0.5
		_title_label.offset_bottom = 4.0 + float(title_height)

	if _list_box != null:
		var lw := pw - 8.0
		var lh := ph - float(title_height) - 16.0
		_list_box.offset_left = 4.0
		_list_box.offset_top = float(title_height) + 10.0
		_list_box.offset_right = pw - 4.0
		_list_box.offset_bottom = ph - 4.0

func _apply_layout_if_ready() -> void:
	if _panel != null:
		_apply_layout()

# --- Title text ---
func _apply_title_text() -> void:
	if _title_label != null:
		_title_label.text = title_text

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
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()

# --- Quest list ---
func _refresh_quests() -> void:
	if _quest_list == null:
		return
	for child in _quest_list.get_children():
		child.queue_free()

	var quests: Array = QuestSystem.get_available_quests_for_npc(quest_giver_npc_id)
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

func _create_quest_item(quest_data: Dictionary) -> Control:
	var item := PanelContainer.new()
	item.custom_minimum_size = Vector2(float(panel_width) - 24.0, float(quest_item_height))
	_apply_single_item_style(item, false)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	item.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = str(quest_data.get("title", "?"))
	title.add_theme_font_size_override("font_size", 9)
	title.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	title.add_theme_constant_override("outline_size", 2)
	vbox.add_child(title)

	# Description (truncate)
	var desc_text := str(quest_data.get("description", ""))
	if desc_text.length() > 60:
		desc_text = desc_text.substr(0, 57) + "..."
	var desc := Label.new()
	desc.text = desc_text
	desc.add_theme_font_size_override("font_size", 7)
	desc.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 0.9))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	# Bottom row: reward + Accept button
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	vbox.add_child(hbox)

	var reward := Label.new()
	var gold: int = int(quest_data.get("reward_gold", 0))
	var xp: int = int(quest_data.get("reward_xp", 0))
	reward.text = "💰 %d   ⭐ %d" % [gold, xp]
	reward.add_theme_font_size_override("font_size", 7)
	reward.add_theme_color_override("font_color", reward_color)
	reward.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(reward)

	var quest_id := str(quest_data.get("id", ""))
	var accept := Button.new()
	accept.text = "Nhận"
	accept.add_theme_font_size_override("font_size", 7)
	accept.custom_minimum_size = Vector2(40, 14)
	accept.pressed.connect(_on_accept_pressed.bind(quest_id, quest_data))
	hbox.add_child(accept)

	# Hover effect
	var hovered := false
	item.mouse_entered.connect(_on_item_hover.bind(item, true))
	item.mouse_exited.connect(_on_item_hover.bind(item, false))
	return item

func _on_item_hover(item: PanelContainer, is_hovered: bool) -> void:
	_apply_single_item_style(item, is_hovered)

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
