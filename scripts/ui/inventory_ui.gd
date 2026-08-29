extends CanvasLayer

func _tr(key: String, fallback: String = "") -> String:
	var cm := get_node_or_null("/root/ConfigManager")
	return cm.translate_text(key, fallback) if cm != null and cm.has_method("translate_text") else fallback
# =============================================================================
# INVENTORY UI v5
# =============================================================================
# Layout khi mở (2 khối tách rời):
#   ┌─TitleBox─┐
#   │INVENTORY │      ← ô nhỏ góc trên-trái, chứa chữ "INVENTORY"
#   └──────────┘
#            ┌─────────────── GridBox ─────────────────────┐
#            │ [slot][slot][slot][slot][slot][slot][slot] │
#            │ [slot][slot][slot][slot][slot][slot][slot] │  ← 3 hàng × 7 cột
#            │ [slot][slot][slot][slot][slot][slot][slot] │
#            └────────────────────────────────────────────┘
#
# Cả TitleBox và GridBox đều bo góc nhẹ (corner_radius), nền nâu tối, viền
# vàng nâu. TitleBox lệch trái-lên, GridBox lệch phải-xuống → tạo cảm giác
# 2 khối tách biệt nhưng vẫn cùng nhóm.
#
# Hotbar (5 slot dưới màn hình) LUÔN hiển thị — khi mở Inventory, hotbar
# hoạt động như phần "TOOLBAR" của inventory: drag từ ô inventory ra hotbar
# slot để chuyển item, hoặc ngược lại.
#
# Drag/drop:
# - Bấm chuột trái vào slot có item → bắt đầu drag (preview di theo chuột).
# - Di chuột sang slot khác (inv hoặc hotbar) → highlight drop target.
# - Thả chuột trong slot khác → swap / move vào slot đó.
# - Thả chuột ra ngoài slot nào → huỷ drag, item trở lại vị trí cũ.
# =============================================================================

const COLS: int = 7
const ROWS: int = 3
const TOTAL_SLOTS: int = COLS * ROWS

@export_range(8, 128, 1) var slot_size: int = 32 :
	set(value):
		slot_size = value
		SLOT_SIZE = Vector2(value, value)
		_rebuild_grid_if_ready()
@export_range(0, 32, 1) var slot_gap: int = 4 :
	set(value):
		slot_gap = value
		_separation_h = value
		_separation_v = value
		_apply_separation_if_ready()
var SLOT_SIZE: Vector2 = Vector2(32, 32)
var _separation_h: int = 4
var _separation_v: int = 4

@export_range(120, 480, 1) var panel_width: int = 272 :
	set(value):
		panel_width = value
		_apply_panel_size_if_ready()
@export_range(100, 320, 1) var panel_height: int = 136 :
	set(value):
		panel_height = value
		_apply_panel_size_if_ready()

@export_range(40, 200, 1) var title_width: int = 70 :
	set(value):
		title_width = value
		_apply_title_size_if_ready()
@export_range(12, 48, 1) var title_height: int = 20 :
	set(value):
		title_height = value
		_apply_title_size_if_ready()

@export_range(0, 32, 1) var inner_padding: int = 8 :
	set(value):
		inner_padding = value
		_apply_padding_if_ready()
@export_range(-16, 16, 1) var title_text_v_offset: int = -8 :
	set(value):
		title_text_v_offset = value
		_apply_title_label_offset_if_ready()

# Tọa độ toàn bộ UI theo vị trí screen (pixel, tính từ center).
# @onready để chỉ setter hoạt động khi đã ready (tránh null Root).
@export_range(-2000, 2000, 1) var screen_offset_x: int = 0 :
	set(value):
		screen_offset_x = value
		_apply_screen_offset_if_ready()
@export_range(-2000, 2000, 1) var screen_offset_y: int = 0 :
	set(value):
		screen_offset_y = value
		_apply_screen_offset_if_ready()
const SLOT_BG_COLOR := Color(0.12, 0.09, 0.18, 1.0)
const SLOT_HOVER_COLOR := Color(0.22, 0.16, 0.32, 1.0)
const SLOT_DROP_TARGET_COLOR := Color(0.32, 0.24, 0.18, 1.0)
const SLOT_BORDER := Color(0.35, 0.28, 0.18, 0.8)
const SLOT_EMPTY := Color(0.18, 0.14, 0.25, 0.6)
const SLOT_SELECTED_DROP_COLOR := Color(1.0, 0.82, 0.28, 1.0)

# Vị trí "slot" trong drag/drop system:
#   index >= 0 && index < TOTAL_SLOTS          → inventory slot
#   index >= 100 && index < 100+5               → hotbar slot (index - 100)
const SLOT_KIND_INVENTORY := 0
const SLOT_KIND_TOOLBAR := 1

var _inv_slot_panels: Array[Panel] = []
var _inv_slot_icons: Array[Label] = []
var _inv_slot_counts: Array[RichTextLabel] = []

var _tooltip: RichTextLabel = null
var _tooltip_panel: Panel = null
var _tooltip_timer: Timer = null
var _pending_tooltip_slot: int = -1
var _game_paused_before: bool = false

# Drag/drop state
var _drag_source_slot: int = -1  # -1 = not dragging
var _drag_amount: int = 0
var _drag_preview: Panel = null
var _drop_target_slot: int = -1

var _bright_region: Control = null
var _inventory_panel: Control = null

# =============================================================================
# TAB SYSTEM — Inventory / Quest tracking
# =============================================================================
# TitleBox "TÚI ĐỒ" và nút "NHIỆM VỤ" bên cạnh là 2 nút bấm để chuyển tab.
# Cả 2 dùng chung style với TitleBox (nền nâu tối + viền vàng nâu, bo góc).
# Nội dung panel bên dưới (GridBox) giữ nguyên kích thước:
#   - Tab inventory: lưới 21 ô vật phẩm (như cũ).
#   - Tab quest: danh sách quest đã nhận + deadline + NPC giao quest.
const TAB_INVENTORY := 0
const TAB_QUEST := 1
## Chiều cao tab (tag). Tab active nhô lên 2px so với inactive.
const TAB_HEIGHT := 18
var _current_tab: int = TAB_INVENTORY
var _title_button: Button = null        # nút bấm đè lên TitleBox "TÚI ĐỒ"
var _quest_tab_button: Button = null    # nút "NHIỆM VỤ" bên cạnh
var _quest_panel: PanelContainer = null # panel chứa list quest (con của GridBox)
var _quest_list_box: VBoxContainer = null
var _quest_empty_label: Label = null

# Style (background layer) cho 2 nút tab — định nghĩa trong inventory_ui.tscn.
# Cả 2 dùng nền giống kho đồ + viền vàng nhẹ; tab được chọn dùng style sáng hơn.
@export var tab_style_normal: StyleBoxFlat
@export var tab_style_active: StyleBoxFlat

# Context menu hiện khi chuột phải vào 1 inventory slot có CONSUMABLE.
# Hiển thị 1 nút "Dùng" cạnh slot. Bấm "Dùng" → consume; bấm chỗ khác
# (ô khác, panel khác, phím khác) → ẩn menu.
@export_group("Context Menu")
@export var ctx_menu_w: int = 26:
	set(value):
		ctx_menu_w = value
		_apply_ctx_menu_size()
@export var ctx_menu_h: int = 14:
	set(value):
		ctx_menu_h = value
		_apply_ctx_menu_size()
@export var ctx_menu_offset: Vector2 = Vector2(6, 0)
@export var ctx_btn_h: int = 12:
	set(value):
		ctx_btn_h = value
		_apply_ctx_menu_size()
@export var ctx_btn_font_size: int = 7:
	set(value):
		ctx_btn_font_size = value
		_apply_ctx_menu_font()
var _context_menu: Panel = null
var _context_use_btn: Button = null
var _context_target_slot: int = -1  # inventory slot mà menu đang phục vụ
var _context_target_item_id: String = ""

func _ready() -> void:
	print("[InvUI] _ready ENTER, name=", name)
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("inventory_ui")
	print("[InvUI] added to group, is_in_group=", is_in_group("inventory_ui"))
	visible = false
	_apply_box_style("Root/Panel/TitleBox", Color(0.06, 0.04, 0.1, 0.97), Color(0.85, 0.68, 0.38, 1.0), 4, 2, 3.0)
	_apply_box_style("Root/Panel/GridBox", Color(0.06, 0.04, 0.1, 0.97), Color(0.85, 0.68, 0.38, 1.0), 4, 2, 3.0)
	_build_inv_grid()
	_apply_separation_if_ready()
	_apply_padding_if_ready()
	_apply_title_size_if_ready()
	_apply_gridbox_size_if_ready()
	_apply_panel_size_if_ready()
	_apply_title_label_offset_if_ready()
	_build_tooltip()
	GameState.reset_inventory_layout()
	_refresh_all()
	GameState.inventory_changed.connect(_on_inventory_changed)
	GameState.toolbar_changed.connect(_on_toolbar_changed)
	_bright_region = get_node_or_null("Root/BrightRegion")
	_inventory_panel = get_node_or_null("Root/Panel")
	if _bright_region != null:
		_bright_region.visible = false
	_build_context_menu()
	_build_tabs()
	print("[InvUI] _ready EXIT, _bright_region=", _bright_region, " _inventory_panel=", _inventory_panel, " _context_menu=", _context_menu)

# Áp style bo góc nhẹ cho PanelContainer (TitleBox / GridBox).
# bg_color: màu nền nâu, border_color: màu viền vàng nâu,
# corner_radius: bán kính bo góc (px), border_width: độ dày viền.
# Viền render "rộng ra ngoài" panel rect thêm expand_px mỗi cạnh — tạo cảm
# giác viền nhô ra khỏi khung panel, không bị crop bởi parent.
func _apply_box_style(path: String, bg_color: Color, border_color: Color, corner_radius: int, border_width: int, expand_px: float) -> void:
	var box: PanelContainer = get_node_or_null(path) as PanelContainer
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
	style.expand_margin_left = expand_px
	style.expand_margin_top = expand_px
	style.expand_margin_right = expand_px
	style.expand_margin_bottom = expand_px
	box.add_theme_stylebox_override("panel", style)


# --- Live-tweak setters (gọi từ @export setters khi user chỉnh trong Inspector) ---
# Tất cả đều guard bằng is_inside_tree() / node == null để an toàn trước _ready.

func _apply_panel_size_if_ready() -> void:
	var panel: Control = get_node_or_null("Root/Panel")
	if panel == null or not panel.is_inside_tree():
		return
	var half_w: int = panel_width / 2
	var half_h: int = panel_height / 2
	panel.offset_left = -half_w + screen_offset_x
	panel.offset_right = half_w + screen_offset_x
	panel.offset_top = -half_h + screen_offset_y
	panel.offset_bottom = half_h + screen_offset_y
	_apply_gridbox_size_if_ready()

func _apply_screen_offset_if_ready() -> void:
	# Đã có _apply_panel_size_if_ready tự tính screen_offset vào offset,
	# chỉ cần gọi lại nó khi chỉnh screen_offset_x/y để UI dịch theo.
	_apply_panel_size_if_ready()

func _apply_gridbox_size_if_ready() -> void:
	var gridbox: PanelContainer = get_node_or_null("Root/Panel/GridBox")
	if gridbox == null:
		return
	# GridBox left=2, right=panel_width-2, top=title_height-4, bottom=panel_height-5
	gridbox.offset_left = 2
	gridbox.offset_right = panel_width - 2
	gridbox.offset_top = title_height - 4
	gridbox.offset_bottom = panel_height - 5
	_apply_padding_if_ready()

func _apply_title_size_if_ready() -> void:
	var titlebox: PanelContainer = get_node_or_null("Root/Panel/TitleBox")
	if titlebox == null:
		return
	titlebox.offset_right = 2 + title_width
	titlebox.offset_bottom = 2 + title_height
	var gridbox: PanelContainer = get_node_or_null("Root/Panel/GridBox")
	if gridbox != null:
		gridbox.offset_top = (2 + title_height) - 6
	_apply_title_label_offset_if_ready()

func _apply_title_label_offset_if_ready() -> void:
	var label: Label = get_node_or_null("Root/Panel/Title")
	if label == null:
		return
	label.position.y = title_text_v_offset
	label.position.x = (2 + title_width) / 2.0 - label.size.x / 2.0
	var titlebox: PanelContainer = get_node_or_null("Root/Panel/TitleBox")
	if titlebox == null:
		return
	label.position.x = titlebox.position.x + (titlebox.size.x / 2.0) - (label.size.x / 2.0)
	label.position.y = titlebox.position.y + title_text_v_offset

func _apply_padding_if_ready() -> void:
	var grid: GridContainer = get_node_or_null("Root/Panel/GridBox/GridContainer")
	if grid == null:
		return
	grid.offset_left = inner_padding
	grid.offset_top = inner_padding
	grid.offset_right = -inner_padding
	grid.offset_bottom = -inner_padding
	_apply_separation_if_ready()

func _apply_separation_if_ready() -> void:
	var grid: GridContainer = get_node_or_null("Root/Panel/GridBox/GridContainer")
	if grid == null:
		return
	grid.add_theme_constant_override("h_separation", _separation_h)
	grid.add_theme_constant_override("v_separation", _separation_v)

func _rebuild_grid_if_ready() -> void:
	# Xoá slot cũ, build lại với SLOT_SIZE mới.
	var grid: GridContainer = get_node_or_null("Root/Panel/GridBox/GridContainer")
	if grid == null:
		return
	for child in grid.get_children():
		child.queue_free()
	_inv_slot_panels.clear()
	_inv_slot_icons.clear()
	_inv_slot_counts.clear()
	# Đợi 1 frame để queue_free hoàn tất trước khi build lại — nhưng gọi trực tiếp
	# cũng được vì add_child vào GridContainer vẫn hoạt động; Godot xử lý deferred.
	_build_inv_grid()
	_refresh_all()

# =============================================================================
# BUILD UI
# =============================================================================

func _build_inv_grid() -> void:
	var grid: GridContainer = get_node_or_null("Root/Panel/GridBox/GridContainer")
	if grid == null:
		return
	for i: int in range(TOTAL_SLOTS):
		var panel := Panel.new()
		panel.custom_minimum_size = SLOT_SIZE
		panel.name = "InvSlot%d" % i
		_apply_panel_style(panel, false)
		panel.gui_input.connect(_on_inv_slot_input.bind(i))
		panel.mouse_entered.connect(_on_slot_enter.bind(i))
		panel.mouse_exited.connect(_on_slot_leave.bind(i))
		var icon := _make_icon_label("InvIcon")
		panel.add_child(icon)
		_inv_slot_icons.append(icon)
		var count := _make_count_label("InvCount")
		panel.add_child(count)
		_inv_slot_counts.append(count)
		grid.add_child(panel)
		_inv_slot_panels.append(panel)

func _apply_panel_style(panel: Panel, drop_target: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = SLOT_BG_COLOR
	style.border_color = SLOT_EMPTY if not drop_target else SLOT_DROP_TARGET_COLOR
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_right = 2
	style.corner_radius_bottom_left = 2
	panel.add_theme_stylebox_override("panel", style)

func _make_icon_label(name_str: String) -> Label:
	var icon := Label.new()
	icon.name = name_str
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 14)
	# Label mặc định mouse_filter = IGNORE, nhưng explicit để chắc chắn click
	# xuyên qua → Panel cha nhận gui_input.
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon

func _make_count_label(name_str: String) -> RichTextLabel:
	var count := RichTextLabel.new()
	count.name = name_str
	count.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	count.anchor_left = 1.0
	count.anchor_top = 1.0
	count.anchor_right = 1.0
	count.anchor_bottom = 1.0
	count.offset_left = -20.0
	count.offset_top = -12.0
	count.offset_right = -1.0
	count.offset_bottom = -1.0
	count.grow_horizontal = Control.GROW_DIRECTION_END
	count.grow_vertical = Control.GROW_DIRECTION_END
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count.bbcode_enabled = true
	count.fit_content = true
	count.scroll_active = false
	count.autowrap_mode = TextServer.AUTOWRAP_OFF
	count.add_theme_font_size_override("normal_font_size", 7)
	count.add_theme_color_override("default_color", Color(1, 0.92, 0.5, 1))
	# RichTextLabel mặc định mouse_filter = STOP sẽ nuốt event khi click vào
	# vùng text — khiến Panel cha không nhận gui_input → drag không hoạt
	# động ở slot có amount > 1 (label visible). Set IGNORE để click xuyên.
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return count

func _build_tooltip() -> void:
	_tooltip_panel = Panel.new()
	_tooltip_panel.z_index = 100
	var ts := StyleBoxFlat.new()
	ts.bg_color = Color(0.04, 0.02, 0.07, 0.97)
	ts.border_color = Color(0.5, 0.4, 0.25, 1)
	ts.border_width_left = 1
	ts.border_width_top = 1
	ts.border_width_right = 1
	ts.border_width_bottom = 1
	ts.corner_radius_top_left = 2
	ts.corner_radius_top_right = 2
	ts.corner_radius_bottom_right = 2
	ts.corner_radius_bottom_left = 2
	_tooltip_panel.add_theme_stylebox_override("panel", ts)
	_tooltip_panel.visible = false
	add_child(_tooltip_panel)

	_tooltip = RichTextLabel.new()
	_tooltip.name = "TooltipLabel"
	_tooltip.add_theme_font_size_override("normal_font_size", 7)
	_tooltip.add_theme_color_override("default_color", Color(0.95, 0.92, 0.85, 1))
	_tooltip.text = ""
	_tooltip.bbcode_enabled = true
	_tooltip.fit_content = true
	_tooltip.scroll_active = false
	_tooltip.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Tooltip không ăn event (parent Panel cũng vậy — tooltip chỉ là read-only).
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_panel.add_child(_tooltip)

	var tooltip_style := StyleBoxEmpty.new()
	tooltip_style.content_margin_left = 4
	tooltip_style.content_margin_top = 1.5
	tooltip_style.content_margin_right = 4
	tooltip_style.content_margin_bottom = 2
	_tooltip.add_theme_stylebox_override("normal", tooltip_style)

	_tooltip_timer = Timer.new()
	_tooltip_timer.wait_time = 0.3
	_tooltip_timer.one_shot = true
	_tooltip_timer.timeout.connect(_show_tooltip_for_pending)
	add_child(_tooltip_timer)

# Build context menu (popup nhỏ hiện cạnh inventory slot khi chuột phải).
# Hiện chỉ có 1 nút "Dùng" cho CONSUMABLE — các loại item khác không hiện
# menu. Click "Dùng" → consume item. Click bất kỳ đâu khác → ẩn menu.
func _build_context_menu() -> void:
	_context_menu = Panel.new()
	_context_menu.name = "ContextMenu"
	_context_menu.size = Vector2(ctx_menu_w, ctx_menu_h)
	_context_menu.visible = false
	_context_menu.z_index = 110
	_context_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0.04, 0.02, 0.07, 0.97)
	cs.border_color = Color(0.85, 0.68, 0.38, 1.0)
	cs.border_width_left = 1
	cs.border_width_top = 1
	cs.border_width_right = 1
	cs.border_width_bottom = 1
	cs.corner_radius_top_left = 2
	cs.corner_radius_top_right = 2
	cs.corner_radius_bottom_right = 2
	cs.corner_radius_bottom_left = 2
	_context_menu.add_theme_stylebox_override("panel", cs)
	add_child(_context_menu)

	# Kích thước nút vừa đủ chữ "Use" — bỏ default style của Button (padding
# mặc định làm nút phình to) để nút đúng bằng box.
	_context_use_btn = Button.new()
	_context_use_btn.name = "UseBtn"
	_context_use_btn.text = _tr("ui.inventory.use_button", "Dùng")
	_context_use_btn.position = Vector2(2, 1)
	_context_use_btn.size = Vector2(ctx_menu_w - 4, ctx_btn_h)
	_context_use_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_context_use_btn.focus_mode = Control.FOCUS_NONE
	_context_use_btn.add_theme_font_size_override("font_size", ctx_btn_font_size)
	# Style trong suốt — nền/viền/padding mặc định của Button bị tắt để nút
	# không vẽ đè lên menu Panel. Hover/pressed đổi màu text để báo click.
	_context_use_btn.add_theme_constant_override("h_separation", 0)
	# Tắt style của Button bằng StyleBoxEmpty cho mọi state.
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var empty: StyleBoxEmpty = StyleBoxEmpty.new()
		_context_use_btn.add_theme_stylebox_override(state, empty)
	_context_use_btn.add_theme_color_override("font_color", Color(1, 0.92, 0.65, 1))
	_context_use_btn.add_theme_color_override("font_hover_color", Color(1, 0.97, 0.78, 1))
	_context_use_btn.add_theme_color_override("font_pressed_color", Color(1, 1, 0.85, 1))
	_context_use_btn.pressed.connect(_on_context_use_pressed)
	_context_menu.add_child(_context_use_btn)
	# Apply 1 lần sau khi build xong (setter không gọi được vì _ready trước
	# _build → _context_menu = null lúc setter chạy).
	_apply_ctx_menu_size()
	_apply_ctx_menu_font()


# Apply lại size khi đổi ctx_menu_w / ctx_menu_h / ctx_btn_h trong Inspector.
func _apply_ctx_menu_size() -> void:
	if _context_menu == null:
		return
	_context_menu.size = Vector2(ctx_menu_w, ctx_menu_h)
	if _context_use_btn != null:
		_context_use_btn.position = Vector2(2, 1)
		_context_use_btn.size = Vector2(ctx_menu_w - 4, ctx_btn_h)


func _apply_ctx_menu_font() -> void:
	if _context_use_btn == null:
		return
	_context_use_btn.add_theme_font_size_override("font_size", ctx_btn_font_size)
	_context_use_btn.add_theme_color_override("font_color", Color(1, 0.92, 0.65, 1))
	_context_use_btn.add_theme_color_override("font_hover_color", Color(1, 0.97, 0.78, 1))
	_context_use_btn.add_theme_color_override("font_pressed_color", Color(1, 1, 0.85, 1))

# =============================================================================
# OPEN / CLOSE
# =============================================================================

# =============================================================================
# TAB SYSTEM — build & switch
# =============================================================================
# Dựng 2 nút tab (TitleBox "TÚI ĐỒ" + nút "NHIỆM VỤ" bên cạnh) cùng panel list
# quest bên trong GridBox. Khi chuyển tab, chỉ đổi nội dung bên trong GridBox,
# giữ nguyên kích thước/viền/style để 2 tab trông đồng nhất.

func _build_tabs() -> void:
	var panel: Control = get_node_or_null("Root/Panel") as Control
	var titlebox: PanelContainer = get_node_or_null("Root/Panel/TitleBox") as PanelContainer
	var gridbox: PanelContainer = get_node_or_null("Root/Panel/GridBox") as PanelContainer
	var grid: GridContainer = get_node_or_null("Root/Panel/GridBox/GridContainer") as GridContainer
	if panel == null or gridbox == null or grid == null:
		return

	# Nút tab thay thế TitleBox/Label cũ (tránh text chồng nhau). Nút tab được đặt
	# SAU GridBox (z thấp hơn) nên mép dưới bị GridBox che → giống "tag" gắn trên
	# panel. Vị trí/z_index được set trong _update_tab_visuals().
	if titlebox != null:
		titlebox.visible = false
	var old_title_label: Label = get_node_or_null("Root/Panel/Title") as Label
	if old_title_label != null:
		old_title_label.visible = false

	# --- Nút "TÚI ĐỒ" (tag) ---
	_title_button = Button.new()
	_title_button.name = "TitleTabButton"
	_title_button.text = _tr("ui.inventory.title", "TÚI ĐỒ")
	_title_button.flat = true
	_title_button.focus_mode = Control.FOCUS_NONE
	_title_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_title_button.pressed.connect(_switch_tab.bind(TAB_INVENTORY))
	panel.add_child(_title_button)
	_title_button.size = Vector2(float(title_width), float(TAB_HEIGHT))

	# --- Nút "NHIỆM VỤ" (tag) ---
	_quest_tab_button = Button.new()
	_quest_tab_button.name = "QuestTabButton"
	_quest_tab_button.text = _tr("ui.inventory.quest_tab", "NHIỆM VỤ")
	_quest_tab_button.flat = true
	_quest_tab_button.focus_mode = Control.FOCUS_NONE
	_quest_tab_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_quest_tab_button.pressed.connect(_switch_tab.bind(TAB_QUEST))
	panel.add_child(_quest_tab_button)
	var quest_tab_w: int = title_width + 10
	_quest_tab_button.size = Vector2(float(quest_tab_w), float(TAB_HEIGHT))

	# --- Panel danh sách quest (con của GridBox, thay thế grid khi ở tab quest) ---
	_quest_panel = PanelContainer.new()
	_quest_panel.name = "QuestPanel"
	_quest_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_quest_panel.offset_left = inner_padding
	_quest_panel.offset_top = inner_padding
	_quest_panel.offset_right = -inner_padding
	_quest_panel.offset_bottom = -inner_padding
	_quest_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_quest_panel_style()
	gridbox.add_child(_quest_panel)

	var scroll := ScrollContainer.new()
	scroll.name = "QuestScroll"
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_quest_panel.add_child(scroll)

	_quest_list_box = VBoxContainer.new()
	_quest_list_box.name = "QuestList"
	_quest_list_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_quest_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quest_list_box.add_theme_constant_override("separation", 4)
	scroll.add_child(_quest_list_box)

	_quest_empty_label = Label.new()
	_quest_empty_label.name = "QuestEmptyLabel"
	_quest_empty_label.text = _tr("ui.inventory.no_quests", "Chưa nhận nhiệm vụ nào.")
	_quest_empty_label.add_theme_font_size_override("font_size", 8)
	_quest_empty_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 0.9))
	_quest_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quest_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_quest_empty_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_quest_panel.add_child(_quest_empty_label)

	# Khởi tạo tab mặc định là inventory.
	_switch_tab(TAB_INVENTORY)

	# Tự refresh list quest khi quest thay đổi trạng thái.
	# quest_accepted emit 2 tham số, quest_completed/quest_failed emit 1 tham số
	# → phải dùng handler riêng cho từng signal.
	if QuestSystem.quest_accepted.is_connected(_on_quest_accepted):
		QuestSystem.quest_accepted.disconnect(_on_quest_accepted)
	if QuestSystem.quest_completed.is_connected(_on_quest_resolved):
		QuestSystem.quest_completed.disconnect(_on_quest_resolved)
	if QuestSystem.quest_failed.is_connected(_on_quest_resolved):
		QuestSystem.quest_failed.disconnect(_on_quest_resolved)
	QuestSystem.quest_accepted.connect(_on_quest_accepted)
	QuestSystem.quest_completed.connect(_on_quest_resolved)
	QuestSystem.quest_failed.connect(_on_quest_resolved)

func _apply_tab_button_style(btn: Button, active: bool) -> void:
	# Dùng StyleBoxFlat định nghĩa trong .tscn (tab_style_normal/tab_style_active).
	var style: StyleBoxFlat = tab_style_active if active else tab_style_normal
	if style == null:
		# Fallback an toàn nếu .tscn chưa gán resource (nền giống kho đồ + viền vàng).
		style = StyleBoxFlat.new()
		style.bg_color = Color(0.06, 0.04, 0.1, 0.97)
		style.border_color = Color(0.95, 0.8, 0.45, 1.0) if active else Color(0.62, 0.48, 0.28, 1.0)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 0 if active else 2
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_right = 0
		style.corner_radius_bottom_left = 0
		style.content_margin_left = 6
		style.content_margin_top = 1
		style.content_margin_right = 6
		style.content_margin_bottom = 1
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(state, style)
	btn.add_theme_font_size_override("font_size", 8)
	btn.add_theme_color_override("font_color", Color(1, 0.88, 0.55, 1) if active else Color(0.72, 0.69, 0.62, 1))

func _apply_quest_panel_style() -> void:
	if _quest_panel == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.04, 0.1, 0.0)
	style.border_color = Color(0.5, 0.4, 0.25, 0.0)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	_quest_panel.add_theme_stylebox_override("panel", style)

func _switch_tab(tab: int) -> void:
	_current_tab = tab
	var grid: GridContainer = get_node_or_null("Root/Panel/GridBox/GridContainer") as GridContainer
	if grid != null:
		grid.visible = (_current_tab == TAB_INVENTORY)
	if _quest_panel != null:
		_quest_panel.visible = (_current_tab == TAB_QUEST)
	# Cập nhật vị trí/z-index/viền cho 2 tab (tag active nhô lên + sáng hơn).
	_update_tab_visuals()
	# Khi sang tab quest, hủy drag đang chờ (không còn ô vật phẩm để thả).
	if _current_tab == TAB_QUEST:
		_cancel_drag()
		_hide_context_menu()
		_hide_tooltip()
		_refresh_quest_list()

# Đặt vị trí + z_index + style cho 2 tab (tag gắn trên panel). Tab đang chọn:
#   - nhô lên 2px (y nhỏ hơn),
#   - z_index cao hơn → nằm TRÊN GridBox (mép dưới nối liền với panel),
#   - viền sáng hơn (set trong _apply_tab_button_style).
# Tab không chọn nằm SAU GridBox (z thấp) → mép dưới bị che, chỉ thấy phần trên.
func _update_tab_visuals() -> void:
	var gridbox: Control = get_node_or_null("Root/Panel/GridBox") as Control
	var grid_top: float = gridbox.position.y if gridbox != null else float(title_height) - 4.0
	var title_active: bool = _current_tab == TAB_INVENTORY
	if _title_button != null:
		_apply_tab_button_style(_title_button, title_active)
		_title_button.position = Vector2(2.0, _tab_y(title_active, grid_top))
		_title_button.z_index = 1 if title_active else -1
	if _quest_tab_button != null:
		_apply_tab_button_style(_quest_tab_button, not title_active)
		_quest_tab_button.position = Vector2(float(title_width) + 4.0, _tab_y(not title_active, grid_top))
		_quest_tab_button.z_index = 1 if not title_active else -1

# Y của tab theo trạng thái. Tab active chạm mép trên GridBox (bottom = grid_top);
# inactive thấp hơn 2px (bottom = grid_top + 2) và bị GridBox che phần thừa.
func _tab_y(active: bool, grid_top: float) -> float:
	if active:
		return grid_top - float(TAB_HEIGHT)
	return grid_top - float(TAB_HEIGHT) + 2.0

func _on_quest_accepted(_quest_id: String, _context: Dictionary) -> void:
	if _current_tab == TAB_QUEST:
		_refresh_quest_list()

func _on_quest_resolved(_quest_id: String) -> void:
	if _current_tab == TAB_QUEST:
		_refresh_quest_list()

func _refresh_quest_list() -> void:
	if _quest_list_box == null:
		return
	for child in _quest_list_box.get_children():
		child.queue_free()
	var quests: Array = QuestSystem.get_active_quests()
	if quests.is_empty():
		if _quest_empty_label != null:
			_quest_empty_label.visible = true
		return
	if _quest_empty_label != null:
		_quest_empty_label.visible = false
	for q in quests:
		if q is Dictionary:
			_quest_list_box.add_child(_create_quest_list_item(q))

func _create_quest_list_item(quest: Dictionary) -> Control:
	var item := PanelContainer.new()
	# Box fit với text: không set chiều cao cố định — PanelContainer tự co giãn
	# theo nội dung. Chiều ngang lấp đầy list (SIZE_EXPAND_FILL).
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.02, 0.07, 0.97)
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
	style.content_margin_top = 3
	style.content_margin_right = 6
	style.content_margin_bottom = 3
	item.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 1)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.add_child(vbox)

	# Tên quest
	var title := Label.new()
	title.text = str(quest.get("name", quest.get("title", "?")))
	title.add_theme_font_size_override("font_size", 8)
	title.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(title)

	# Dòng thông tin: NPC giao quest + deadline
	var info := Label.new()
	var giver_id: String = str(quest.get("giver", ""))
	var giver_name: String = QuestSystem.NPC_DISPLAY_NAMES.get(giver_id, giver_id.capitalize())
	var days_left: int = 0
	if int(quest.get("deadline_day", 0)) > 0:
		days_left = maxi(int(quest.get("deadline_day", 0)) - GameState.current_day, 0)
	else:
		days_left = QuestSystem.get_quest_deadline_days(quest)
	info.text = "%s: %s  |  %s %d %s" % [
		_tr("ui.inventory.quest_giver", "Từ"),
		giver_name,
		_tr("ui.quest.deadline", "Hạn chót:"),
		days_left,
		_tr("ui.quest.day", "ngày"),
	]
	info.add_theme_font_size_override("font_size", 7)
	info.add_theme_color_override("font_color", Color(1.0, 0.6, 0.5, 1.0))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(info)

	return item

func _input(event: InputEvent) -> void:
	if GameState.player_movement_locked or GameState.cinematic_intro_state != GameState.CINEMATIC_NONE or DialogueManager.is_active:
		return
	# Toggle inventory cũng được bắt ở HotkeyInputManager (autoload) để chắc
	# chắn hoạt động dù packed scene này bị delay load. Handler ở đây vẫn
	# giữ làm fallback — _input chạy trước GUI dispatch.
	if event.is_action_pressed("toggle_inventory"):
		if DialogueManager.is_active:
			return
		_toggle()
		get_viewport().set_input_as_handled()
		return

	if not visible:
		return
	if event is InputEventMouseMotion:
		var vp_rect := get_viewport().get_visible_rect()
		var mouse_pos := get_viewport().get_mouse_position()
		if not vp_rect.has_point(mouse_pos):
			_clear_hover()

	# Bắt mouse UP ở _input (không phải _unhandled_input) vì hotbar slots có
	# mouse_filter = STOP mặc định — chúng ăn event trước khi bubble xuống
	# unhandled. Khi inventory đang mở và đang drag, hotbar slot không nên
	# nhận click "chọn slot" — ta consume event để hotbar bỏ qua.
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and _drag_source_slot >= 0:
			_handle_drag_release()
			get_viewport().set_input_as_handled()

	# Click bất kỳ (chuột trái HOẶC phải) vào vùng NGOÀI context menu mà
	# context menu đang hiện → ẩn menu. Click vào chính context menu (Panel
	# hoặc Button bên trong) sẽ được GUI dispatch nuốt ở mouse_filter STOP,
	# không vào nhánh này.
	if _context_menu != null and _context_menu.visible:
		if event is InputEventMouseButton and event.pressed:
			var mp: Vector2 = get_viewport().get_mouse_position()
			if not _context_menu.get_global_rect().has_point(mp):
				_hide_context_menu()
		elif event is InputEventKey and event.pressed:
			# Phím bất kỳ → đóng menu.
			_hide_context_menu()

func _unhandled_input(event: InputEvent) -> void:
	# Defensive: khi inventory mở + đang drag, mouse UP cũng có thể bubble
	# tới đây nếu không có control nào trên đường đi.
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and _drag_source_slot >= 0:
			_handle_drag_release()
			get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	# Vùng sáng cần update mỗi frame vì hotbar có thể bị layout thay đổi
	# (resolution, scene change). Tính bounding rect bao trùm cả inventory
	# panel và hotbar, set BrightRegion = rect đó (không chia ô vuông).
	if _bright_region != null and _bright_region.visible:
		_update_bright_region()

	# Cập nhật vị trí preview theo chuột mỗi frame (motion event không bubble
	# xuống _unhandled_input khi popup đang mở vì mouse_filter của Panel).
	if _drag_source_slot >= 0 and _drag_preview != null and is_instance_valid(_drag_preview):
		var mouse_pos: Vector2 = get_viewport().get_mouse_position()
		_drag_preview.position = mouse_pos - SLOT_SIZE * 0.5
		# Cập nhật drop target theo vị trí chuột (slot nào chuột đang nằm trên).
		# Bắt buộc dùng _process vì hotbar slots chặn mouse event (mouse_filter
		# = STOP mặc định) nên _unhandled_input không nhận được motion.
		var new_target: int = _find_slot_under_mouse(mouse_pos)
		if new_target != _drop_target_slot:
			# Clear highlight slot cũ (nếu đang highlight)
			if _drop_target_slot >= 0:
				_apply_drop_target_style(_drop_target_slot, false)
			_drop_target_slot = new_target
			# Highlight slot mới nếu khác source
			if _drop_target_slot >= 0 and _drop_target_slot != _drag_source_slot:
				_apply_drop_target_style(_drop_target_slot, true)
	elif _drag_source_slot < 0 and _drop_target_slot != -1:
		_drop_target_slot = -1

func _toggle() -> void:
	if visible:
		_close()
	else:
		_open()

func _open() -> void:
	_game_paused_before = GameState.is_paused
	GameState.is_paused = true
	GameState.game_interacting = true
	visible = true
	_cancel_drag()
	_refresh_all()
	_hide_tooltip()
	# Backdrop tắt theo yêu cầu — chỉ hiện inventory panel, không dim UI phụ
	# và không vẽ BrightRegion. Nếu muốn bật lại, set _bright_region.visible
	# = true trước khi gọi _open(), hoặc bỏ comment 2 dòng dưới.
	# if _bright_region != null:
	# 	_bright_region.visible = true
	# 	_update_bright_region()
	# var uif: Node = get_node_or_null("/root/UIFocusManager")
	# if uif != null:
	# 	uif.call("dim_background", true)

func _close() -> void:
	visible = false
	GameState.is_paused = _game_paused_before
	GameState.game_interacting = false
	_cancel_drag()
	_hide_context_menu()
	_hide_tooltip()
	_clear_hover()
	# Defensive reset: nếu backdrop từng được bật (qua code path khác),
	# đảm bảo tắt khi đóng inventory để không kẹt UI mờ.
	if _bright_region != null and _bright_region.visible:
		_bright_region.visible = false
	var uif: Node = get_node_or_null("/root/UIFocusManager")
	if uif != null:
		uif.call("dim_background", false)

# Tính bounding rect (union của TitleBox + GridBox + hotbar) và set BrightRegion
# position/size. Vùng sáng là một khối liền, không chia ô vuông — nó phủ bên
# dưới cả inventory boxes và hotbar để chúng nổi bật như 1 layout dọc.
# Cộng thêm expand_px (StyleBox expand_margin) để viền render nằm gọn trong
# BrightRegion.
func _update_bright_region() -> void:
	if _bright_region == null:
		return
	var title_box: Control = get_node_or_null("Root/Panel/TitleBox") as Control
	var grid_box: Control = get_node_or_null("Root/Panel/GridBox") as Control
	if title_box == null or grid_box == null:
		return
	var pad: float = 8.0
	var expand_px: float = 2.0
	var inv_rect: Rect2 = title_box.get_global_rect()
	inv_rect = inv_rect.merge(grid_box.get_global_rect())
	inv_rect = inv_rect.grow(expand_px)
	# Hotbar KHÔNG nằm trong BrightRegion — nó luôn hiển thị đầy đủ
	# (xem UIFocusManager: hotbar loại khỏi dim list).
	_bright_region.position = inv_rect.position - Vector2(pad, pad)
	_bright_region.size = inv_rect.size + Vector2(pad * 2, pad * 2)

# =============================================================================
# REFRESH
# =============================================================================

func _refresh_all() -> void:
	_refresh_inv()

func _on_inventory_changed() -> void:
	if visible:
		_refresh_inv()

func _on_toolbar_changed() -> void:
	# Hotbar tự refresh qua signal của nó; inventory không có panel hotbar
	# riêng — chỉ cần refresh nếu slot đang được highlight drop target.
	if visible and _drop_target_slot >= 100:
		_apply_drop_target_style(_drop_target_slot, _is_drop_target(_drop_target_slot))

func _refresh_inv() -> void:
	for i: int in range(TOTAL_SLOTS):
		_update_inv_slot(i)

func _update_inv_slot(slot_idx: int) -> void:
	if slot_idx >= _inv_slot_panels.size():
		return
	var panel: Panel = _inv_slot_panels[slot_idx]
	var icon: Label = _inv_slot_icons[slot_idx]
	var count: RichTextLabel = _inv_slot_counts[slot_idx]
	var item_id: String = ""
	var amount: int = 0
	if slot_idx < GameState.inventory.size():
		var entry: Dictionary = GameState.inventory[slot_idx]
		item_id = entry.get("id", "")
		amount = entry.get("amount", 1)
	_fill_slot(panel, icon, count, item_id, amount, slot_idx)

func _fill_slot(panel: Panel, icon: Label, count: RichTextLabel, item_id: String, amount: int, slot_idx: int) -> void:
	if item_id == "":
		icon.text = ""
		icon.visible = false
		count.visible = false
		_set_slot_border(panel, false, false, slot_idx)
	else:
		var data: ItemData = ItemDB.get_item(item_id)
		if data != null:
			icon.text = data.icon
			icon.add_theme_color_override("font_color", data.item_color)
			icon.visible = true
			_set_slot_border(panel, true, false, slot_idx)
			if amount > 1:
				count.text = "[font_size=5]x[/font_size][font_size=7]%d[/font_size]" % amount
				count.visible = true
			else:
				count.visible = false
		else:
			icon.text = "?"
			icon.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
			icon.visible = true
			count.visible = false
			_set_slot_border(panel, true, false, slot_idx)

func _set_slot_border(panel: Panel, has_item: bool, is_drop: bool, slot_idx: int) -> void:
	var style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style == null:
		return
	# Highlight bị tắt theo yêu cầu: drag preview di chuyển theo chuột là đủ
	# tín hiệu trực quan — không highlight source / drop target slot.
	style.bg_color = SLOT_BG_COLOR
	style.border_color = SLOT_BORDER if has_item else SLOT_EMPTY

func _apply_drop_target_style(slot_idx: int, is_drop_target: bool) -> void:
	if slot_idx >= 100:
		# Toolbar slot — hotbar tự render và tự highlight
		var hotbar: Control = get_tree().get_first_node_in_group("hotbar")
		if hotbar != null and hotbar.has_method("highlight_slot"):
			# Vẫn gọi để reset style về default (highlight đã tắt).
			hotbar.call("highlight_slot", slot_idx - 100, false)
		return
	var panel: Panel = _get_panel_for_slot(slot_idx)
	if panel == null:
		return
	# Highlight đã tắt — không đổi border width / bg; reset về default.
	_set_slot_border(panel, _has_item_in_slot(slot_idx), false, slot_idx)

func _has_item_in_slot(slot_idx: int) -> bool:
	if slot_idx < 100:
		if slot_idx >= GameState.inventory.size():
			return false
		return GameState.inventory[slot_idx].get("id", "") != ""
	else:
		var ti := slot_idx - 100
		if ti >= GameState.toolbar.size():
			return false
		return GameState.toolbar[ti].get("id", "") != ""

func _get_panel_for_slot(slot_idx: int) -> Panel:
	if slot_idx < 100:
		if slot_idx >= _inv_slot_panels.size():
			return null
		return _inv_slot_panels[slot_idx]
	# Toolbar slot (>=100) nằm ngoài inventory UI (dùng hotbar bên ngoài).
	# Inventory không giữ reference tới panel đó — giao diện hotbar tự render.
	return null

# =============================================================================
# SLOT EVENTS
# =============================================================================

func _on_slot_enter(slot_idx: int) -> void:
	if _drag_source_slot >= 0:
		# đang drag → highlight slot này là drop target nếu khác source
		var is_drop := (slot_idx != _drag_source_slot)
		_apply_drop_target_style(slot_idx, is_drop)
		if is_drop:
			_drop_target_slot = slot_idx
		return
	_pending_tooltip_slot = slot_idx
	_tooltip_timer.start()

func _on_slot_leave(slot_idx: int) -> void:
	_tooltip_timer.stop()
	_apply_drop_target_style(slot_idx, false)
	if _drop_target_slot == slot_idx:
		_drop_target_slot = -1
	_hide_tooltip()

func _on_inv_slot_input(event: InputEvent, slot_idx: int) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if slot_idx >= GameState.inventory.size():
		return
	var entry: Dictionary = GameState.inventory[slot_idx]
	var item_id: String = entry.get("id", "")
	if item_id == "":
		_hide_context_menu()
		return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		# Chuột phải vào 1 ô có item: nếu là CONSUMABLE → hiện context menu
		# "Dùng" cạnh ô đó. Các loại khác (TOOL/SEED/KEY/CURRENCY) → không
		# hiện menu, đóng menu cũ nếu đang mở.
		var data: ItemData = ItemDB.get_item(item_id)
		if data != null and data.item_type == ItemData.Type.CONSUMABLE:
			_show_context_menu(slot_idx, item_id)
		else:
			_hide_context_menu()
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	# Click trái vào slot có item → bắt đầu drag. Đồng thời ẩn context menu
	# nếu đang mở (click sang ô khác = chọn việc khác).
	_hide_context_menu()
	_start_drag(slot_idx, item_id, int(entry.get("amount", 1)))

func _on_toolbar_slot_input(_event: InputEvent, _toolbar_idx: int) -> void:
	pass

# =============================================================================
# DRAG / DROP
# =============================================================================

func _start_drag(slot_idx: int, item_id: String, amount: int) -> void:
	if item_id == "":
		return
	_cancel_drag()
	_drag_source_slot = slot_idx
	_drag_amount = amount
	# Tạo preview panel nhỏ di theo chuột
	var preview := Panel.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.size = SLOT_SIZE
	preview.z_index = 50
	var preview_style := StyleBoxFlat.new()
	preview_style.bg_color = SLOT_BG_COLOR
	preview_style.border_color = Color(1, 0.82, 0.28, 1)
	preview_style.border_width_left = 2
	preview_style.border_width_top = 2
	preview_style.border_width_right = 2
	preview_style.border_width_bottom = 2
	preview_style.corner_radius_top_left = 2
	preview_style.corner_radius_top_right = 2
	preview_style.corner_radius_bottom_right = 2
	preview_style.corner_radius_bottom_left = 2
	preview.add_theme_stylebox_override("panel", preview_style)
	var icon := Label.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 14)
	var data: ItemData = ItemDB.get_item(item_id)
	if data != null:
		icon.text = data.icon
		icon.add_theme_color_override("font_color", data.item_color)
	else:
		icon.text = "?"
	preview.add_child(icon)
	# Đặt preview vào CanvasLayer (self) để không bị clip bởi Panel container
	add_child(preview)
	preview.position = get_viewport().get_mouse_position() - SLOT_SIZE * 0.5
	_drag_preview = preview
	# (Highlight source đã tắt — drag preview di chuyển theo chuột là đủ tín hiệu.)

func _update_drag_preview(mouse_pos: Vector2) -> void:
	if _drag_preview != null and is_instance_valid(_drag_preview):
		_drag_preview.position = mouse_pos - SLOT_SIZE * 0.5

func _handle_drag_release() -> void:
	if _drag_source_slot < 0:
		return
	var drop_slot := _find_slot_under_mouse(get_viewport().get_mouse_position())
	if drop_slot >= 0 and drop_slot != _drag_source_slot:
		# Swap bất kể ô đích có item hay không — move item giữa các ô trống
		# hoặc hoán đổi vị trí khi cả 2 ô đều có item.
		_swap_slots(_drag_source_slot, drop_slot)
	_cancel_drag()

func _find_slot_under_mouse(mouse_pos: Vector2) -> int:
	# Ưu tiên inventory trước (trên cùng), rồi đến hotbar ở dưới màn hình.
	for i: int in range(_inv_slot_panels.size()):
		var p := _inv_slot_panels[i]
		if is_instance_valid(p) and p.get_global_rect().has_point(mouse_pos):
			return i
	# Hotbar slots nằm ngoài inventory UI; truy vấn qua group "hotbar".
	var hotbar: Control = get_tree().get_first_node_in_group("hotbar")
	if hotbar != null:
		var slot_names := ["Slot0", "Slot1", "Slot2", "Slot3", "Slot4"]
		for i: int in range(slot_names.size()):
			var slot: Control = hotbar.get_node_or_null("SlotsContainer/" + slot_names[i]) as Control
			if slot != null and is_instance_valid(slot) and slot.get_global_rect().has_point(mouse_pos):
				return 100 + i
	return -1

func _is_drop_target(slot_idx: int) -> bool:
	return _drag_source_slot >= 0 and slot_idx != _drag_source_slot

func _swap_slots(a: int, b: int) -> void:
	if a == b:
		return
	# a < 100: inventory ; a >= 100: toolbar
	if a < 100 and b < 100:
		GameState.swap_inventory_slots(a, b)
	elif a >= 100 and b >= 100:
		GameState.swap_toolbar_slots(a - 100, b - 100)
	else:
		# inventory ↔ toolbar
		if a < 100:
			GameState.swap_inventory_toolbar(a, b - 100)
		else:
			GameState.swap_inventory_toolbar(b, a - 100)

func _swap_inv_inv(a: int, b: int) -> void:
	# Deprecated — dùng GameState.swap_inventory_slots trực tiếp.
	GameState.swap_inventory_slots(a, b)

func _cancel_drag() -> void:
	if _drag_preview != null and is_instance_valid(_drag_preview):
		_drag_preview.queue_free()
	_drag_preview = null
	# Reset style của source slot
	if _drag_source_slot >= 0:
		var panel: Panel = _get_panel_for_slot(_drag_source_slot)
		if panel != null:
			_apply_drop_target_style(_drag_source_slot, false)
	_drag_source_slot = -1
	_drag_amount = 0
	_drop_target_slot = -1

# =============================================================================
# CONTEXT MENU (chuột phải vào inventory slot có CONSUMABLE → nút "Dùng")
# =============================================================================
# Hiển thị popup nhỏ cạnh slot. Bấm "Dùng" → consume item; bấm bất kỳ chỗ
# nào khác (ô khác, panel khác, phím khác) → ẩn menu.
# =============================================================================

func _show_context_menu(slot_idx: int, item_id: String) -> void:
	if _context_menu == null:
		return
	var panel: Panel = _get_panel_for_slot(slot_idx)
	if panel == null:
		return
	_context_target_slot = slot_idx
	_context_target_item_id = item_id
	# Đặt menu cạnh slot. Inventory grid 7 cột — slot nằm trong 3 cột phải
	# ngoài cùng (col 4,5,6, tức slot_idx % 7 >= 4) thì menu luôn nằm bên
	# TRÁI slot để không tràn viewport. Các vị trí khác → bên phải, trừ khi
	# tràn viewport thì tự flip.
	var slot_rect: Rect2 = panel.get_global_rect()
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var right_col_threshold: int = 4  # 7 cột: 0..6; cột 4,5,6 = 3 cột phải
	var slot_col: int = slot_idx % 7
	var place_left: bool = slot_col >= right_col_threshold
	if place_left:
		var menu_pos_x: float = slot_rect.position.x - ctx_menu_w - ctx_menu_offset.x
		_context_menu.position = Vector2(menu_pos_x, slot_rect.position.y)
	else:
		var menu_pos_x: float = slot_rect.position.x + slot_rect.size.x + ctx_menu_offset.x
		# Flip nếu vẫn tràn viewport.
		if menu_pos_x + ctx_menu_w > viewport_size.x:
			menu_pos_x = slot_rect.position.x - ctx_menu_w - ctx_menu_offset.x
		_context_menu.position = Vector2(menu_pos_x, slot_rect.position.y)
	_context_menu.visible = true
	# Ẩn tooltip inventory cũ (nếu đang hiện từ hover) để khỏi chồng UI.
	_hide_tooltip()

func _hide_context_menu() -> void:
	if _context_menu == null:
		return
	_context_menu.visible = false
	_context_target_slot = -1
	_context_target_item_id = ""

func _on_context_use_pressed() -> void:
	# Lưu slot/item_id và reset target TRƯỚC khi gọi consume — để khi
	# inventory_changed emit, _refresh_inv chạy không bị ảnh hưởng bởi menu.
	var slot_idx: int = _context_target_slot
	var item_id: String = _context_target_item_id
	_hide_context_menu()
	if slot_idx < 0 or item_id == "":
		return
	if slot_idx >= GameState.inventory.size():
		return
	if GameState.inventory[slot_idx].get("id", "") != item_id:
		# Item ở slot đã bị thay đổi giữa lúc mở menu và bấm Dùng → bỏ qua.
		return
	var item_handler: Node = get_node_or_null("/root/ItemHandler")
	if item_handler == null:
		push_warning("[InvUI] ItemHandler not found")
		return
	# Apply effect (energy/health) trước, sau đó remove_item sẽ fire signal
	# inventory_changed → _refresh_all cập nhật grid.
	if item_handler.has_method("use_item"):
		item_handler.use_item(item_id, true)

# =============================================================================
# TOOLTIP / INFO
# =============================================================================

func _show_tooltip_for_pending() -> void:
	if _pending_tooltip_slot < 0:
		return
	var entry: Dictionary = _get_slot_entry(_pending_tooltip_slot)
	if entry.is_empty():
		return
	var item_id: String = entry.get("id", "")
	if item_id == "":
		return
	var data: ItemData = ItemDB.get_item(item_id)
	if data == null:
		return
	var name_text := "[color=#FFD866]%s[/color]" % data.get_display_name()
	var type_text := "[color=#AAA]%s[/color]" % data.get_type_name()
	var effect_text := ""
	match data.item_type:
		ItemData.Type.CONSUMABLE:
			if data.effect_type == ItemData.Effect.RESTORE_ENERGY:
				effect_text = "[color=#6F6]%+d Energy[/color]" % int(data.energy_restore)
			elif data.effect_type == ItemData.Effect.RESTORE_HEALTH:
				effect_text = "[color=#F66]%+d Health[/color]" % int(data.health_restore)
		ItemData.Type.SEED:
			effect_text = "[color=#6A6]%dd to harvest[/color]" % data.grow_days
		ItemData.Type.TOOL:
			effect_text = "[color=#AAA]Equip[/color]"
	_tooltip.text = "\n".join([name_text, type_text, effect_text])
	var panel: Panel = _get_panel_for_slot(_pending_tooltip_slot)
	var slot_global_pos: Vector2
	if panel != null:
		slot_global_pos = panel.get_global_rect().position
	else:
		slot_global_pos = get_viewport().get_mouse_position()
	var tt_size := Vector2(100, 36)
	var tt_pos := slot_global_pos + Vector2(SLOT_SIZE.x + 4, 0)
	if tt_pos.x + tt_size.x > get_viewport().get_visible_rect().size.x:
		tt_pos.x = slot_global_pos.x - tt_size.x - 4
	_tooltip_panel.position = tt_pos
	_tooltip_panel.custom_minimum_size = tt_size
	_tooltip_panel.visible = true

func _show_item_info_for(slot_idx: int) -> void:
	var entry: Dictionary = _get_slot_entry(slot_idx)
	if entry.is_empty():
		return
	var item_id: String = entry.get("id", "")
	if item_id == "":
		return
	var data: ItemData = ItemDB.get_item(item_id)
	if data == null:
		return
	var lines: Array[String] = []
	lines.append("[color=#FFD866]%s[/color]" % data.get_display_name())
	lines.append("[color=#AAA]%s[/color]" % data.get_type_name())
	var item_description: String = data.get_description() if data.has_method("get_description") else data.description
	if item_description != "":
		lines.append("[color=#CCC]%s[/color]" % item_description)
	lines.append("")
	var amount: int = int(entry.get("amount", 1))
	lines.append("[color=#888]Owned: %d[/color]" % amount)
	match data.item_type:
		ItemData.Type.CONSUMABLE:
			if data.effect_type == ItemData.Effect.RESTORE_ENERGY:
				lines.append("[color=#6F6]%+d Energy[/color]" % int(data.energy_restore))
			elif data.effect_type == ItemData.Effect.RESTORE_HEALTH:
				lines.append("[color=#F66]%+d Health[/color]" % int(data.health_restore))
		ItemData.Type.SEED:
			lines.append("[color=#6A6]Grows: %s[/color]" % data.harvest_item_id.capitalize().replace("_", " "))
			lines.append("[color=#666]Days: %d[/color]" % data.grow_days)
	_tooltip.text = "\n".join(lines)
	var panel: Panel = _get_panel_for_slot(slot_idx)
	var slot_global_pos: Vector2
	if panel != null:
		slot_global_pos = panel.get_global_rect().position
	else:
		slot_global_pos = get_viewport().get_mouse_position()
	var tt_size := Vector2(120, 60)
	var tt_pos := slot_global_pos + Vector2(SLOT_SIZE.x + 4, 0)
	if tt_pos.x + tt_size.x > get_viewport().get_visible_rect().size.x:
		tt_pos.x = slot_global_pos.x - tt_size.x - 4
	_tooltip_panel.position = tt_pos
	_tooltip_panel.custom_minimum_size = tt_size
	_tooltip_panel.visible = true
	_tooltip_timer.stop()

func _is_mouse_over_consumable_slot() -> bool:
	if not visible:
		return false
	var mp: Vector2 = get_viewport().get_mouse_position()
	for i: int in range(_inv_slot_panels.size()):
		var p: Panel = _inv_slot_panels[i]
		if is_instance_valid(p) and p.get_global_rect().has_point(mp):
			if i >= GameState.inventory.size():
				return false
			var entry: Dictionary = GameState.inventory[i]
			var item_id: String = entry.get("id", "")
			if item_id == "":
				return false
			var data: ItemData = ItemDB.get_item(item_id)
			return data != null and data.item_type == ItemData.Type.CONSUMABLE
	return false

func _get_slot_entry(slot_idx: int) -> Dictionary:
	if slot_idx < 100:
		if slot_idx >= GameState.inventory.size():
			return {}
		return GameState.inventory[slot_idx]
	else:
		var ti := slot_idx - 100
		if ti >= GameState.toolbar.size():
			return {}
		return GameState.toolbar[ti]

func _hide_tooltip() -> void:
	if _tooltip_panel != null:
		_tooltip_panel.visible = false
	_pending_tooltip_slot = -1

func _clear_hover() -> void:
	_tooltip_timer.stop()
	_hide_tooltip()

func _maybe_pause_tree(pause: bool) -> void:
	get_tree().paused = pause
