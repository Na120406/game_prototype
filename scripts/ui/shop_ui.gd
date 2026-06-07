extends Control

signal shop_closed()

const SELL_PRICE_RATIO: float = 0.5

var _player_gold: int = 100
var _hotbar: Control = null
var _current_tab: int = 0

var _tooltip_panel: Control = null
var _tooltip_name: Label = null
var _tooltip_desc: Label = null
var _tooltip_detail: Label = null
var _tooltip_layer: CanvasLayer = null
var _last_hover_item_id: String = ""
var _row_item_cache: Array[ItemData] = []
var _hover_timer: float = 0.0
var _pending_item_data: ItemData = null

var _hotbar_last_id: String = ""
var _hotbar_pending_id: String = ""
var _hotbar_hover_timer: float = 0.0
const HOTBAR_HOVER_DELAY: float = 1.5

@onready var items_scroll: ScrollContainer = $Win/Col/ItemsScroll
@onready var items_list: VBoxContainer = $Win/Col/ItemsScroll/Margin/ItemsList
@onready var buy_tab: Button = $Win/Col/Tabs/BuyTab
@onready var sell_tab: Button = $Win/Col/Tabs/SellTab

func _ready() -> void:
	add_to_group("shop_ui")
	visible = false
	buy_tab.pressed.connect(_on_tab_buy)
	sell_tab.pressed.connect(_on_tab_sell)
	shop_closed.connect(_on_shop_closed)
	_create_tooltip()
	_refresh_tabs()
	items_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	items_scroll.get_v_scroll_bar().visible = false
	items_scroll.get_h_scroll_bar().visible = false
	print("[ShopUI] Ready.")

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

func _show_tooltip(item_data: ItemData) -> void:
	if item_data == null:
		return

	_tooltip_name.text = item_data.get_display_name()
	_tooltip_desc.text = item_data.description

	var type_str: String
	match item_data.item_type:
		ItemData.Type.CONSUMABLE: type_str = "Consumable"
		ItemData.Type.TOOL: type_str = "Tool"
		ItemData.Type.SEED: type_str = "Seed (%s)" % item_data.grow_season
		ItemData.Type.KEY_ITEM: type_str = "Key Item"
		ItemData.Type.CURRENCY: type_str = "Currency"
		_: type_str = "Item"

	var sell_str := "Sell: %d G" % item_data.sell_price if item_data.sell_price > 0 else ""
	var parts := [type_str, sell_str].filter(func(s): return s != "")
	_tooltip_detail.text = " | ".join(PackedStringArray(parts))

	_tooltip_desc.size.x = 128
	_tooltip_desc.emit_signal("size_flags_changed")
	var text_h: int = _tooltip_desc.get_minimum_size().y
	var total_h: int = 10 + 12 + text_h + 2 + 10
	_tooltip_panel.custom_minimum_size = Vector2(140, total_h)
	_tooltip_panel.size = Vector2(140, total_h)

	var mouse_pos := get_global_mouse_position()
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

func _hide_tooltip() -> void:
	_tooltip_panel.visible = false

func _show_tooltip_for_hotbar(item_id: String) -> void:
	if item_id.is_empty():
		return
	if item_id != _hotbar_last_id:
		_hotbar_last_id = item_id
		_hotbar_pending_id = item_id
		_hotbar_hover_timer = 0.0
		_hide_tooltip()

func _process(_delta: float) -> void:
	var mouse_pos := get_global_mouse_position()
	var item_data := _get_item_data_at_mouse(mouse_pos)

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

	if _hotbar_pending_id != "":
		_hotbar_hover_timer += _delta
		if _hotbar_hover_timer >= HOTBAR_HOVER_DELAY:
			var db = get_node("/root/ItemDB")
			if db != null:
				var data: ItemData = db.get_item(_hotbar_pending_id)
				if data != null:
					_show_tooltip(data)
			_hotbar_pending_id = ""
	elif _hotbar_last_id != "" and not _tooltip_panel.visible:
		_hotbar_last_id = ""
		_hotbar_hover_timer = 0.0

func _reset_hotbar_hover() -> void:
	_hotbar_last_id = ""
	_hotbar_pending_id = ""
	_hotbar_hover_timer = 0.0

func _get_item_data_at_mouse(mouse_pos: Vector2) -> ItemData:
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

func _update_tooltip_position(mouse_pos: Vector2) -> void:
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

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("interact"):
		close()
		get_viewport().set_input_as_handled()

func _on_shop_closed() -> void:
	_try_show_hotbar()

func _try_hide_hotbar() -> void:
	if _hotbar == null:
		_hotbar = get_tree().get_first_node_in_group("hotbar")
	if _hotbar != null:
		_hotbar.visible = false

func _try_show_hotbar() -> void:
	if _hotbar == null:
		_hotbar = get_tree().get_first_node_in_group("hotbar")
	if _hotbar != null:
		_hotbar.visible = true

func open(gold: int = 100) -> void:
	_player_gold = gold
	_current_tab = 0
	_refresh_tabs()
	_refresh_shop()
	_try_hide_hotbar()
	visible = true

func _refresh_tabs() -> void:
	if _current_tab == 0:
		_apply_tab_active(buy_tab, true)
		_apply_tab_active(sell_tab, false)
		buy_tab.text = "> BUY <"
		sell_tab.text = "  SELL  "
	else:
		_apply_tab_active(buy_tab, false)
		_apply_tab_active(sell_tab, true)
		buy_tab.text = "  BUY  "
		sell_tab.text = "> SELL <"

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

func _on_tab_buy() -> void:
	if _current_tab == 0:
		return
	_current_tab = 0
	_refresh_tabs()
	_refresh_shop()

func _on_tab_sell() -> void:
	if _current_tab == 1:
		return
	_current_tab = 1
	_refresh_tabs()
	_refresh_shop()

func _refresh_shop() -> void:
	for child in items_list.get_children():
		child.queue_free()
	_row_item_cache.clear()

	if _current_tab == 0:
		_refresh_buy_list()
	else:
		_refresh_sell_list()

func _refresh_buy_list() -> void:
	var db = get_node("/root/ItemDB")
	if db == null:
		return
	var buyable_items: Array = db.get_buyable_items()
	for item_data: ItemData in buyable_items:
		items_list.add_child(_make_buy_row(item_data))
		_row_item_cache.append(item_data)

func _refresh_sell_list() -> void:
	var has_items: bool = false
	for item: Dictionary in GameState.inventory:
		var item_id: String = item.get("id", "")
		var amount: int = GameState.get_item_count(item_id)
		if amount > 0:
			has_items = true
			var data: Array = _make_sell_row(item_id, amount)
			items_list.add_child(data[0])
			_row_item_cache.append(data[1])

	if not has_items:
		var empty_lbl := Label.new()
		empty_lbl.text = "No items to sell"
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
		empty_lbl.add_theme_font_size_override("font_size", 10)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		items_list.add_child(empty_lbl)
		_row_item_cache.append(null)

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
	action_btn.text = "Buy"
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

func _make_sell_row(item_id: String, amount: int) -> Array:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 26)

	var db = get_node("/root/ItemDB")
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
	action_btn.text = "Sell"
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

func _get_sell_price(item_id: String) -> int:
	var db = get_node("/root/ItemDB")
	if db != null:
		var item_data: ItemData = db.get_item(item_id)
		if item_data != null:
			return item_data.get_sell_price()
	return 5

func _try_buy(item_data: ItemData) -> void:
	if _player_gold < item_data.buy_price:
		print("[ShopUI] Not enough gold! Need %d, have %d" % [item_data.buy_price, _player_gold])
		return
	_player_gold -= item_data.buy_price
	GameState.gold = _player_gold
	GameState.add_item(item_data.item_id, 1)
	_refresh_shop()

func _try_sell(item_id: String) -> void:
	var amount: int = GameState.get_item_count(item_id)
	if amount <= 0:
		return
	var price: int = _get_sell_price(item_id)
	GameState.remove_item(item_id, 1)
	_player_gold += price
	GameState.gold = _player_gold
	_refresh_shop()

func close() -> void:
	_last_hover_item_id = ""
	_pending_item_data = null
	_hover_timer = 0.0
	_hide_tooltip()
	visible = false
	_try_show_hotbar()
	shop_closed.emit()
