extends CanvasLayer

func _tr(key: String, fallback: String = "") -> String:
	var cm := get_node_or_null("/root/ConfigManager")
	return cm.translate_text(key, fallback) if cm != null and cm.has_method("translate_text") else fallback
# =============================================================================
# SHOP UI (Giao diện Cửa hàng)
# =============================================================================
# Chức năng: Hiển thị giao diện mua/bán vật phẩm
#
# Bug đã fix:
#   - Tooltip không bị stuck sau khi đóng shop
#   - Tooltip không hiện ở scene khác
#   - Thêm kiểm tra an toàn trước khi xử lý
# =============================================================================

signal shop_closed()

const SELL_PRICE_RATIO: float = 0.5

var _player_gold: int = 100
var _hotbar: Control = null
var _current_tab: int = 0

# =============================================================================
# TOOLTIP STATE - CÁC BIẾN THEO DÕI TOOLTIP
# =============================================================================

var _tooltip_panel: Control = null
var _tooltip_name: Label = null
var _tooltip_desc: Label = null
var _tooltip_detail: Label = null
var _tooltip_layer: CanvasLayer = null

# Theo dõi item đang hover trong shop
var _last_hover_item_id: String = ""
var _row_item_cache: Array[ItemData] = []
var _hover_timer: float = 0.0
var _pending_item_data: ItemData = null

# Trạng thái shop có đang mở không
var _shop_is_visible: bool = false

# Hotbar hover state (cho hotbar khi shop đóng)
var _hotbar_last_id: String = ""
var _hotbar_pending_id: String = ""
var _hotbar_hover_timer: float = 0.0
const HOTBAR_HOVER_DELAY: float = 1.5

# Cờ báo tooltip đang hiện (dùng cho cả shop và hotbar)
var _tooltip_is_shown: bool = false

@onready var items_scroll: ScrollContainer = $Win/Col/ItemsScroll
@onready var items_list: VBoxContainer = $Win/Col/ItemsScroll/Margin/ItemsList
@onready var buy_tab: Button = $Win/Col/Tabs/BuyTab
@onready var sell_tab: Button = $Win/Col/Tabs/SellTab

func _ready() -> void:
	add_to_group("shop_ui")
	visible = false
	_shop_is_visible = false

	_hotbar = get_tree().get_first_node_in_group("hotbar")

	buy_tab.pressed.connect(_on_tab_buy)
	sell_tab.pressed.connect(_on_tab_sell)
	shop_closed.connect(_on_shop_closed)
	_create_tooltip()
	_refresh_tabs()
	items_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	items_scroll.get_v_scroll_bar().visible = false
	items_scroll.get_h_scroll_bar().visible = false
	print("[ShopUI] Ready.")


# =============================================================================
# HÀM DỌN DẸP KHI THOÁT (_exit_tree)
# =============================================================================

func _exit_tree() -> void:
	_cleanup_tooltip()


# =============================================================================
# HÀM TẠO TOOLTIP (_create_tooltip)
# =============================================================================

func _create_tooltip() -> void:
	_tooltip_panel = PanelContainer.new()
	_tooltip_panel.name = "TooltipPanel"
	_tooltip_panel.z_index = 1000
	_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.04, 0.08, 0.85)
	_tooltip_panel.add_child(bg)

	var border := ColorRect.new()
	border.color = Color(0.55, 0.45, 0.25, 0.7)
	border.position = Vector2(-1, -1)
	border.size = Vector2(2, 2)
	_tooltip_panel.add_child(border)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	_tooltip_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	margin.add_child(vbox)

	_tooltip_name = Label.new()
	_tooltip_name.add_theme_color_override("font_color", Color(1, 0.9, 0.5, 1))
	_tooltip_name.add_theme_font_size_override("font_size", 9)
	vbox.add_child(_tooltip_name)

	_tooltip_desc = Label.new()
	_tooltip_desc.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75, 0.85))
	_tooltip_desc.add_theme_font_size_override("font_size", 8)
	_tooltip_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_tooltip_desc)

	_tooltip_detail = Label.new()
	_tooltip_detail.add_theme_color_override("font_color", Color(0.6, 0.55, 0.5, 0.7))
	_tooltip_detail.add_theme_font_size_override("font_size", 7)
	vbox.add_child(_tooltip_detail)

	_tooltip_layer = CanvasLayer.new()
	_tooltip_layer.name = "TooltipLayer"
	_tooltip_layer.layer = 100
	_tooltip_layer.add_child(_tooltip_panel)
	_tooltip_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_tooltip_panel.set_offsets_preset(Control.PRESET_TOP_LEFT)
	_tooltip_panel.custom_minimum_size = Vector2(140, 0)
	_tooltip_panel.size = Vector2(140, 50)
	_tooltip_panel.visible = false

	get_tree().root.add_child(_tooltip_layer)


# =============================================================================
# HÀM DỌN DẸP TOOLTIP (_cleanup_tooltip)
# =============================================================================

func _cleanup_tooltip() -> void:
	# Reset tất cả state
	_last_hover_item_id = ""
	_pending_item_data = null
	_hover_timer = 0.0
	_tooltip_is_shown = false
	
	# Reset hotbar state
	_hotbar_last_id = ""
	_hotbar_pending_id = ""
	_hotbar_hover_timer = 0.0
	
	# Xóa tooltip layer hoàn toàn
	if _tooltip_layer != null:
		_tooltip_layer.queue_free()
		_tooltip_layer = null
		_tooltip_panel = null
		_tooltip_name = null
		_tooltip_desc = null
		_tooltip_detail = null


# =============================================================================
# HÀM RESET STATE (_reset_all_state)
# =============================================================================
# Reset tất cả state liên quan đến tooltip

func _reset_all_state() -> void:
	_last_hover_item_id = ""
	_pending_item_data = null
	_hover_timer = 0.0
	_tooltip_is_shown = false
	_hotbar_last_id = ""
	_hotbar_pending_id = ""
	_hotbar_hover_timer = 0.0
	_row_item_cache.clear()


# =============================================================================
# HÀM HIỂN THỊ TOOLTIP (_show_tooltip)
# =============================================================================

func _show_tooltip(item_data: ItemData) -> void:
	if item_data == null or _tooltip_panel == null:
		return

	_tooltip_name.text = item_data.get_display_name()
	_tooltip_desc.text = item_data.get_description() if item_data.has_method("get_description") else item_data.description

	var type_str: String
	match item_data.item_type:
		ItemData.Type.CONSUMABLE: type_str = "Vật phẩm tiêu hao"
		ItemData.Type.TOOL: type_str = "Dụng cụ"
		ItemData.Type.SEED: type_str = "Hạt giống (%s)" % item_data.grow_season
		ItemData.Type.KEY_ITEM: type_str = "Vật phẩm nhiệm vụ"
		ItemData.Type.CURRENCY: type_str = "Tiền tệ"
		_: type_str = "Vật phẩm"

	var sell_str := _tr("ui.tooltip.sell", "Bán: %d G") % item_data.sell_price if item_data.sell_price > 0 else ""
	var parts := [type_str, sell_str].filter(func(s): return s != "")
	_tooltip_detail.text = " | ".join(PackedStringArray(parts))

	_tooltip_desc.size.x = 128
	_tooltip_desc.emit_signal("size_flags_changed")
	var text_h: int = _tooltip_desc.get_minimum_size().y
	var total_h: int = 10 + 12 + text_h + 2 + 10
	_tooltip_panel.custom_minimum_size = Vector2(140, total_h)
	_tooltip_panel.size = Vector2(140, total_h)

	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var tooltip_w: float = 140.0
	var tooltip_h: float = total_h

	var screen_size := get_tree().root.get_visible_rect().size

	var tooltip_x := mouse_pos.x
	var tooltip_y: float

	if mouse_pos.y < screen_size.y * 0.5:
		tooltip_y = mouse_pos.y
	else:
		tooltip_y = mouse_pos.y - tooltip_h

	tooltip_x = clamp(tooltip_x, 0.0, screen_size.x - tooltip_w)
	tooltip_y = clamp(tooltip_y, 0.0, screen_size.y - tooltip_h)

	_tooltip_panel.global_position = Vector2(tooltip_x, tooltip_y)
	_tooltip_panel.visible = true
	_tooltip_is_shown = true


# =============================================================================
# HÀM ẨN TOOLTIP (_hide_tooltip)
# =============================================================================

func _hide_tooltip() -> void:
	if _tooltip_panel != null:
		_tooltip_panel.visible = false
	_tooltip_is_shown = false


# =============================================================================
# HÀM CẬP NHẬT VỊ TRÍ TOOLTIP CHO HOTBAR (_show_tooltip_for_hotbar)
# =============================================================================

func _show_tooltip_for_hotbar(item_id: String) -> void:
	if item_id.is_empty():
		return
	if item_id != _hotbar_last_id:
		_hotbar_last_id = item_id
		_hotbar_pending_id = item_id
		_hotbar_hover_timer = 0.0
		_hide_tooltip()


# =============================================================================
# HÀM CẬP NHẬT MỖI FRAME (_process)
# =============================================================================
# KIỂM TRA: Chỉ xử lý tooltip khi tooltip layer còn tồn tại

func _process(_delta: float) -> void:
	# =================================================================
	# SỬA LỖI: Kiểm tra tooltip layer còn tồn tại không
	# Nếu đã bị xóa (scene chuyển), không làm gì
	# =================================================================
	if _tooltip_layer == null or _tooltip_panel == null:
		return

	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var item_data := _get_item_data_at_mouse(mouse_pos)

	# =================================================================
	# XỬ LÝ TOOLTIP SHOP
	# =================================================================
	if _shop_is_visible and visible:
		if item_data != null:
			if item_data.item_id != _last_hover_item_id:
				_last_hover_item_id = item_data.item_id
				_pending_item_data = item_data
				_hover_timer = 0.0
				if _tooltip_panel.visible:
					_hide_tooltip()
			elif _pending_item_data != null:
				_hover_timer += _delta
				if _hover_timer >= 1.5:
					_show_tooltip(_pending_item_data)
					_pending_item_data = null
			elif _tooltip_panel.visible:
				_update_tooltip_position(mouse_pos)
		else:
			if _last_hover_item_id != "" or _pending_item_data != null:
				_last_hover_item_id = ""
				_pending_item_data = null
				_hover_timer = 0.0
				_hide_tooltip()
	
	# =================================================================
	# XỬ LÝ TOOLTIP HOTBAR (khi shop đóng)
	# =================================================================
	# Chỉ xử lý hotbar tooltip khi:
	# - Shop không visible (đã đóng)
	# - Có pending item từ hotbar
	elif not visible and _hotbar_pending_id != "":
		_hotbar_hover_timer += _delta
		if _hotbar_hover_timer >= HOTBAR_HOVER_DELAY:
			var db = get_node_or_null("/root/ItemDB")
			if db != null:
				var data: ItemData = db.get_item(_hotbar_pending_id)
				if data != null:
					_show_tooltip(data)
			_hotbar_pending_id = ""
	elif not visible and _hotbar_last_id != "" and not _tooltip_panel.visible:
		_hotbar_last_id = ""
		_hotbar_hover_timer = 0.0


# =============================================================================
# HÀM RESET HOTBAR HOVER (_reset_hotbar_hover)
# =============================================================================

func _reset_hotbar_hover() -> void:
	_hotbar_last_id = ""
	_hotbar_pending_id = ""
	_hotbar_hover_timer = 0.0


# =============================================================================
# HÀM LẤY ITEM DATA TẠI VỊ TRÍ CHUỘT (_get_item_data_at_mouse)
# =============================================================================

func _get_item_data_at_mouse(mouse_pos: Vector2) -> ItemData:
	# Chỉ kiểm tra khi shop đang visible
	if not visible:
		return null
		
	for i in items_list.get_child_count():
		var row: Control = items_list.get_child(i)
		if not row is HBoxContainer:
			continue
		var hover_zone: Control = row.find_child("HoverZone", false, false)
		if hover_zone == null:
			continue
		if hover_zone.get_global_rect().has_point(mouse_pos):
			if i < _row_item_cache.size():
				return _row_item_cache[i]
	return null


# =============================================================================
# HÀM CẬP NHẬT VỊ TRỊ TOOLTIP (_update_tooltip_position)
# =============================================================================

func _update_tooltip_position(mouse_pos: Vector2) -> void:
	if _tooltip_panel == null:
		return
		
	var tooltip_w: float = _tooltip_panel.size.x
	var tooltip_h: float = _tooltip_panel.size.y
	var screen_size := get_tree().root.get_visible_rect().size

	var tooltip_x := mouse_pos.x
	var tooltip_y: float

	if mouse_pos.y < screen_size.y * 0.5:
		tooltip_y = mouse_pos.y
	else:
		tooltip_y = mouse_pos.y - tooltip_h

	tooltip_x = clamp(tooltip_x, 0.0, screen_size.x - tooltip_w)
	tooltip_y = clamp(tooltip_y, 0.0, screen_size.y - tooltip_h)

	_tooltip_panel.global_position = Vector2(tooltip_x, tooltip_y)


# =============================================================================
# HÀM XỬ LÝ INPUT (_input)
# =============================================================================

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("interact"):
		close()
		get_viewport().set_input_as_handled()


# =============================================================================
# HÀM XỬ LÝ ĐÓNG SHOP (_on_shop_closed)
# =============================================================================

func _on_shop_closed() -> void:
	_try_show_hotbar()


# =============================================================================
# HÀM THỬ ẨN HOTBAR (_try_hide_hotbar)
# =============================================================================

func _try_hide_hotbar() -> void:
	if _hotbar == null:
		_hotbar = get_tree().get_first_node_in_group("hotbar")
	if _hotbar != null:
		_hotbar.visible = false


# =============================================================================
# HÀM THỬ HIỆN HOTBAR (_try_show_hotbar)
# =============================================================================

func _try_show_hotbar() -> void:
	if _hotbar == null:
		_hotbar = get_tree().get_first_node_in_group("hotbar")
	if _hotbar != null:
		_hotbar.visible = true


# =============================================================================
# HÀM MỞ SHOP (open)
# =============================================================================

func open(gold: int = 200) -> void:
	_player_gold = gold
	_current_tab = 0
	_refresh_tabs()
	_refresh_shop()
	_try_hide_hotbar()

	# Reset state khi mở shop
	_reset_all_state()

	_shop_is_visible = true
	visible = true
	GameState.game_interacting = true
	var uif: Node = get_node_or_null("/root/UIFocusManager")
	if uif != null:
		uif.call("dim_background", true)

	var backdrop: Panel = find_child("Backdrop", false, false)
	if backdrop != null:
		backdrop.visible = true


# =============================================================================
# HÀM REFRESH TABS (_refresh_tabs)
# =============================================================================

func _refresh_tabs() -> void:
	if _current_tab == 0:
		_apply_tab_active(buy_tab, true)
		_apply_tab_active(sell_tab, false)
		buy_tab.text = _tr("ui.shop.buy_tab", "> MUA <")
		sell_tab.text = _tr("ui.shop.sell_tab", "  BÁN  ")
		buy_tab.tooltip_text = _tr("ui.shop.buy_button", "Mua")
		sell_tab.tooltip_text = _tr("ui.shop.sell_button", "Bán")
	else:
		_apply_tab_active(buy_tab, false)
		_apply_tab_active(sell_tab, true)
		buy_tab.text = _tr("ui.shop.buy_tab_inactive", "  MUA  ")
		sell_tab.text = _tr("ui.shop.sell_tab_inactive", "> BÁN <")


# =============================================================================
# HÀM ÁP DỤNG TAB ACTIVE (_apply_tab_active)
# =============================================================================

func _apply_tab_active(btn: Button, active: bool) -> void:
	if btn == null:
		return
	if active:
		btn.add_theme_color_override("font_color", Color(1, 0.85, 0.50, 1))
		btn.add_theme_stylebox_override("normal", btn.get_theme_stylebox("hover"))
		btn.add_theme_stylebox_override("hover", btn.get_theme_stylebox("hover"))
		btn.add_theme_stylebox_override("pressed", btn.get_theme_stylebox("hover"))
	else:
		btn.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55, 1))
		btn.add_theme_stylebox_override("normal", btn.get_theme_stylebox("hover"))
		btn.add_theme_stylebox_override("hover", btn.get_theme_stylebox("hover"))
		btn.add_theme_stylebox_override("pressed", btn.get_theme_stylebox("hover"))


# =============================================================================
# HÀM XỬ LÝ TAB BUY (_on_tab_buy)
# =============================================================================

func _on_tab_buy() -> void:
	if _current_tab == 0:
		return
	_current_tab = 0
	_refresh_tabs()
	_refresh_shop()


# =============================================================================
# HÀM XỬ LÝ TAB SELL (_on_tab_sell)
# =============================================================================

func _on_tab_sell() -> void:
	if _current_tab == 1:
		return
	_current_tab = 1
	_refresh_tabs()
	_refresh_shop()


# =============================================================================
# HÀM LÀM MỚI SHOP (_refresh_shop)
# =============================================================================

func _refresh_shop() -> void:
	for child in items_list.get_children():
		child.queue_free()
	_row_item_cache.clear()

	if _current_tab == 0:
		_refresh_buy_list()
	else:
		_refresh_sell_list()


# =============================================================================
# HÀM LÀM MỚI DANH SÁCH MUA (_refresh_buy_list)
# =============================================================================

func _refresh_buy_list() -> void:
	var db = get_node_or_null("/root/ItemDB")
	if db == null:
		return
	var buyable_items: Array = db.get_buyable_items()
	for item_data: ItemData in buyable_items:
		items_list.add_child(_make_buy_row(item_data))
		_row_item_cache.append(item_data)


# =============================================================================
# HÀM LÀM MỚI DANH SÁCH BÁN (_refresh_sell_list)
# =============================================================================

func _refresh_sell_list() -> void:
	var has_items: bool = false

	# Gom item từ cả inventory (slot_kind=0) và hotbar/toolbar (slot_kind=1)
	# để bán. Thứ tự ưu tiên: inventory trước, hotbar sau. Nếu cùng item_id
	# xuất hiện ở cả 2 nơi thì gộp amount lại; bán 1 phát sẽ trừ từ inventory
	# trước, hết rồi trừ tiếp từ hotbar.
	var ordered_ids: Array[String] = []
	var merged_amounts: Dictionary = {}  # item_id -> int
	var sources_by_item: Dictionary = {}  # item_id -> Array[Dictionary] (theo thứ tự inv→hotbar)
	for slot_kind: int in [0, 1]:
		var list: Array = GameState.inventory if slot_kind == 0 else GameState.toolbar
		for i: int in range(list.size()):
			var entry: Dictionary = list[i]
			var item_id: String = entry.get("id", "")
			var amount: int = int(entry.get("amount", 0))
			if item_id == "" or amount <= 0:
				continue
			if not merged_amounts.has(item_id):
				ordered_ids.append(item_id)
				merged_amounts[item_id] = 0
				sources_by_item[item_id] = []
			merged_amounts[item_id] += amount
			sources_by_item[item_id].append({"slot_kind": slot_kind, "index": i, "amount": amount})

	for item_id: String in ordered_ids:
		var total_amount: int = int(merged_amounts[item_id])
		var row: Array = _make_sell_row(item_id, total_amount)
		row[0].set_meta("sell_item_id", item_id)
		row[0].set_meta("sell_sources", sources_by_item[item_id])
		items_list.add_child(row[0])
		_row_item_cache.append(row[1])
		has_items = true

	if not has_items:
		var empty_lbl := Label.new()
		empty_lbl.text = _tr("ui.shop.empty_sell_message", " Không có vật phẩm để bán")
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
		empty_lbl.add_theme_font_size_override("font_size", 10)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		items_list.add_child(empty_lbl)
		_row_item_cache.append(null)


# =============================================================================
# HÀM TẠO HÀNG MUA (_make_buy_row)
# =============================================================================

func _make_buy_row(item_data: ItemData) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 26)

	var hover_zone := HBoxContainer.new()
	hover_zone.name = "HoverZone"
	hover_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_zone.custom_minimum_size = Vector2(0, 26)
	row.add_child(hover_zone)

	var icon := Label.new()
	icon.custom_minimum_size = Vector2(20, 0)
	icon.text = "[%s]" % item_data.icon
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_color_override("font_color", item_data.item_color)
	icon.add_theme_font_size_override("font_size", 10)
	hover_zone.add_child(icon)

	var name_lbl := Label.new()
	name_lbl.text = item_data.get_display_name()
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85, 1))
	name_lbl.add_theme_font_size_override("font_size", 10)
	hover_zone.add_child(name_lbl)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(2, 0)
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var price_lbl := Label.new()
	price_lbl.custom_minimum_size = Vector2(42, 0)
	price_lbl.text = "%d G" % item_data.buy_price
	price_lbl.add_theme_color_override("font_color", Color(1, 0.90, 0.30, 1))
	price_lbl.add_theme_font_size_override("font_size", 10)
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var action_btn := Button.new()
	action_btn.text = _tr("ui.shop.buy_button", "Mua")
	action_btn.custom_minimum_size = Vector2(40, 0)
	action_btn.pressed.connect(_try_buy.bind(item_data))

	var action_zone := HBoxContainer.new()
	action_zone.name = "ActionZone"
	action_zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_zone.alignment = HBoxContainer.ALIGNMENT_END
	action_zone.add_child(price_lbl)
	action_zone.add_child(action_btn)
	row.add_child(action_zone)

	return row


# =============================================================================
# HÀM TẠO HÀNG BÁN (_make_sell_row)
# =============================================================================

func _make_sell_row(item_id: String, amount: int) -> Array:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 26)

	var db = get_node_or_null("/root/ItemDB")
	var item_data: ItemData = null
	if db != null:
		item_data = db.get_item(item_id)
	var icon_char := "?"
	var icon_color := Color(0.8, 0.8, 0.7, 1)
	var item_name := item_id.capitalize().replace("_", " ")
	if item_data != null:
		icon_char = item_data.icon
		icon_color = item_data.item_color
		item_name = item_data.get_display_name()

	var hover_zone := HBoxContainer.new()
	hover_zone.name = "HoverZone"
	hover_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_zone.custom_minimum_size = Vector2(0, 26)
	row.add_child(hover_zone)

	var icon := Label.new()
	icon.custom_minimum_size = Vector2(20, 0)
	icon.text = "[%s]" % icon_char
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_color_override("font_color", icon_color)
	icon.add_theme_font_size_override("font_size", 10)
	hover_zone.add_child(icon)

	var name_lbl := Label.new()
	name_lbl.text = item_name
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85, 1))
	name_lbl.add_theme_font_size_override("font_size", 10)
	hover_zone.add_child(name_lbl)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(2, 0)
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var amount_lbl := Label.new()
	amount_lbl.custom_minimum_size = Vector2(28, 0)
	amount_lbl.text = "x%d" % amount
	amount_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55, 1))
	amount_lbl.add_theme_font_size_override("font_size", 8)
	amount_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var sell_price: int = _get_sell_price(item_id)
	var price_lbl := Label.new()
	price_lbl.custom_minimum_size = Vector2(42, 0)
	price_lbl.text = "+%d G" % sell_price
	price_lbl.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5, 1))
	price_lbl.add_theme_font_size_override("font_size", 10)
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var action_btn := Button.new()
	action_btn.text = _tr("ui.shop.sell_button", "Bán")
	action_btn.custom_minimum_size = Vector2(40, 0)
	action_btn.pressed.connect(_try_sell.bind(item_id))

	var action_zone := HBoxContainer.new()
	action_zone.name = "ActionZone"
	action_zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_zone.alignment = HBoxContainer.ALIGNMENT_END
	action_zone.add_child(amount_lbl)
	action_zone.add_child(price_lbl)
	action_zone.add_child(action_btn)
	row.add_child(action_zone)

	return [row, item_data]


# =============================================================================
# HÀM LẤY GIÁ BÁN (_get_sell_price)
# =============================================================================

func _get_sell_price(item_id: String) -> int:
	var db = get_node_or_null("/root/ItemDB")
	if db != null:
		var item_data: ItemData = db.get_item(item_id)
		if item_data != null:
			return item_data.get_sell_price()
	return 5


# =============================================================================
# HÀM THỬ MUA (_try_buy)
# =============================================================================

func _try_buy(item_data: ItemData) -> void:
	if _player_gold < item_data.buy_price:
		print("[ShopUI] Not enough gold! Need %d, have %d" % [item_data.buy_price, _player_gold])
		return
	# Add the item first so a full inventory cannot consume the player's gold.
	if not GameState.add_item(item_data.item_id, 1):
		print("[ShopUI] Cannot buy %s: inventory is full." % item_data.item_id)
		return
	_player_gold -= item_data.buy_price
	GameState.gold = _player_gold
	_refresh_shop()


# =============================================================================
# HÀM THỬ BÁN (_try_sell)
# =============================================================================

func _try_sell(item_id: String) -> void:
	var row_button: Node = null
	# Tìm row đang chứa item_id này (row bán hiện tại). Mỗi row có metadata
	# "sell_sources" lưu thứ tự inventory → hotbar mà _refresh_sell_list đã set.
	for child in items_list.get_children():
		var row: Node = child
		if row.has_meta("sell_item_id") and row.get_meta("sell_item_id") == item_id:
			var sources: Array = row.get_meta("sell_sources", [])
			if sources.size() > 0:
				row_button = row
				break

	if row_button == null:
		return

	var sources: Array = row_button.get_meta("sell_sources")
	var remaining: int = 1  # bán 1 đơn vị mỗi lần click Sell
	var price: int = _get_sell_price(item_id)
	var sold_total: int = 0

	for src: Dictionary in sources:
		if remaining <= 0:
			break
		var slot_kind: int = int(src.get("slot_kind", 0))
		var index: int = int(src.get("index", -1))
		var available: int = int(src.get("amount", 0))
		var list: Array = GameState.inventory if slot_kind == 0 else GameState.toolbar
		if index < 0 or index >= list.size():
			continue
		var entry: Dictionary = list[index]
		if entry.get("id", "") != item_id:
			continue
		available = min(available, int(entry.get("amount", 0)))
		if available <= 0:
			continue
		var take: int = min(remaining, available)
		var removed: bool = GameState.remove_inventory_item_at(index, take) if slot_kind == 0 else GameState.remove_toolbar_item(index, take)
		if not removed:
			continue
		remaining -= take
		sold_total += take

	if sold_total <= 0:
		return

	_player_gold += price * sold_total
	GameState.gold = _player_gold
	_refresh_shop()


# =============================================================================
# HÀM ĐÓNG SHOP (close)
# =============================================================================

func close() -> void:
	# Đánh dấu shop không còn mở
	_shop_is_visible = false

	# Reset tất cả state liên quan đến shop
	_last_hover_item_id = ""
	_pending_item_data = null
	_hover_timer = 0.0
	_row_item_cache.clear()

	# Ẩn tooltip
	_hide_tooltip()

	# Ẩn backdrop
	var backdrop: Panel = find_child("Backdrop", false, false)
	if backdrop != null:
		backdrop.visible = false

	# Đóng shop UI
	visible = false
	GameState.game_interacting = false
	var uif: Node = get_node_or_null("/root/UIFocusManager")
	if uif != null:
		uif.call("dim_background", false)
	_try_show_hotbar()
	shop_closed.emit()
