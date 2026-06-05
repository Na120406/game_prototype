extends Control

signal shop_closed()

const SHOP_ITEMS: Array[Dictionary] = [
	{"id": "seed_turnip",  "name": "Turnip Seeds",    "desc": "Plant in spring. Grows in 4 days.",  "price": 10, "icon": "S"},
	{"id": "water_can",    "name": "Watering Can",     "desc": "Waters crops automatically.",          "price": 30, "icon": "W"},
	{"id": "health_potion","name": "Health Potion",   "desc": "Restores 30 energy.",                 "price": 15, "icon": "H"},
	{"id": "rope",         "name": "Rope",             "desc": "Useful for climbing.",                "price":  8, "icon": "R"},
]

const SELL_PRICE_RATIO: float = 0.5

var _player_gold: int = 100
var _hotbar: Control = null
var _current_tab: int = 0

@onready var gold_amt: Label = $Win/Col/TitleBar/HB/GoldAmt
@onready var items_list: VBoxContainer = $Win/Col/ItemsScroll/Margin/ItemsList
@onready var buy_tab: Button = $Win/Col/Tabs/BuyTab
@onready var sell_tab: Button = $Win/Col/Tabs/SellTab

func _ready() -> void:
	add_to_group("shop_ui")
	visible = false
	buy_tab.pressed.connect(_on_tab_buy)
	sell_tab.pressed.connect(_on_tab_sell)
	shop_closed.connect(_on_shop_closed)
	_refresh_tabs()
	print("[ShopUI] Ready.")

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
	print("[ShopUI] Switched to BUY tab")

func _on_tab_sell() -> void:
	if _current_tab == 1:
		return
	_current_tab = 1
	_refresh_tabs()
	_refresh_shop()
	print("[ShopUI] Switched to SELL tab — inventory=%s" % GameState.inventory)

func _refresh_shop() -> void:
	for child in items_list.get_children():
		child.queue_free()
	gold_amt.text = "%d" % _player_gold

	if _current_tab == 0:
		_refresh_buy_list()
	else:
		_refresh_sell_list()

func _refresh_buy_list() -> void:
	for item in SHOP_ITEMS:
		items_list.add_child(_make_buy_row(item))

func _refresh_sell_list() -> void:
	var has_items: bool = false
	for item: Dictionary in GameState.inventory:
		var item_id: String = item.get("id", "")
		var amount: int = GameState.get_item_count(item_id)
		print("[ShopUI] SELL: item_id=%s amount=%d" % [item_id, amount])
		if amount > 0:
			has_items = true
			items_list.add_child(_make_sell_row(item_id, amount))

	if not has_items:
		var empty_lbl := Label.new()
		empty_lbl.text = "No items to sell"
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
		empty_lbl.add_theme_font_size_override("font_size", 10)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		items_list.add_child(empty_lbl)

func _make_buy_row(item: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 26)

	var icon := Label.new()
	icon.custom_minimum_size = Vector2(20, 0)
	icon.text = "[%s]" % item.get("icon", "?")
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_color_override("font_color", Color(0.8, 0.8, 0.7, 1))
	icon.add_theme_font_size_override("font_size", 10)
	row.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_lbl := Label.new()
	name_lbl.text = item.get("name", "???")
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85, 1))
	name_lbl.add_theme_font_size_override("font_size", 10)
	info.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = item.get("desc", "")
	desc_lbl.add_theme_color_override("font_color", Color(0.50, 0.50, 0.50, 1))
	desc_lbl.add_theme_font_size_override("font_size", 8)
	info.add_child(desc_lbl)
	row.add_child(info)

	var price_lbl := Label.new()
	price_lbl.custom_minimum_size = Vector2(42, 0)
	price_lbl.text = "%d G" % item.get("price", 0)
	price_lbl.add_theme_color_override("font_color", Color(1, 0.90, 0.30, 1))
	price_lbl.add_theme_font_size_override("font_size", 10)
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(price_lbl)

	var action_btn := Button.new()
	action_btn.text = "Buy"
	action_btn.custom_minimum_size = Vector2(40, 0)
	action_btn.pressed.connect(_try_buy.bind(item))
	row.add_child(action_btn)

	return row

func _make_sell_row(item_id: String, amount: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 26)

	var icon := Label.new()
	icon.custom_minimum_size = Vector2(20, 0)
	icon.text = "[%s]" % (item_id[0].to_upper() if item_id.length() > 0 else "?")
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_color_override("font_color", Color(0.8, 0.8, 0.7, 1))
	icon.add_theme_font_size_override("font_size", 10)
	row.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_lbl := Label.new()
	name_lbl.text = item_id.capitalize().replace("_", " ")
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85, 1))
	name_lbl.add_theme_font_size_override("font_size", 10)
	info.add_child(name_lbl)

	var amount_lbl := Label.new()
	amount_lbl.text = "x%d" % amount
	amount_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55, 1))
	amount_lbl.add_theme_font_size_override("font_size", 8)
	info.add_child(amount_lbl)
	row.add_child(info)

	var sell_price: int = _get_sell_price(item_id)
	var price_lbl := Label.new()
	price_lbl.custom_minimum_size = Vector2(42, 0)
	price_lbl.text = "+%d G" % sell_price
	price_lbl.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5, 1))
	price_lbl.add_theme_font_size_override("font_size", 10)
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(price_lbl)

	var action_btn := Button.new()
	action_btn.text = "Sell"
	action_btn.custom_minimum_size = Vector2(40, 0)
	action_btn.pressed.connect(_try_sell.bind(item_id))
	row.add_child(action_btn)

	return row

func _get_sell_price(item_id: String) -> int:
	for shop_item in SHOP_ITEMS:
		if shop_item.get("id") == item_id:
			return int(shop_item.get("price", 0) * SELL_PRICE_RATIO)
	return 5

func _try_buy(item: Dictionary) -> void:
	print("[ShopUI] _try_buy: item=%s gold=%d" % [item.get("id", ""), _player_gold])
	var price: int = item.get("price", 0)
	if _player_gold < price:
		print("[ShopUI] Not enough gold! Need %d, have %d" % [price, _player_gold])
		return
	_player_gold -= price
	GameState.gold = _player_gold
	var item_id: String = item.get("id", "")
	GameState.add_item(item_id, 1)
	print("[ShopUI] Bought: %s — inventory=%s" % [item.get("name", "???"), GameState.inventory])
	_refresh_shop()

func _try_sell(item_id: String) -> void:
	print("[ShopUI] _try_sell: item_id=%s" % item_id)
	var amount: int = GameState.get_item_count(item_id)
	print("[ShopUI] _try_sell: current amount=%d" % amount)
	if amount <= 0:
		print("[ShopUI] No %s to sell!" % item_id)
		return
	var price: int = _get_sell_price(item_id)
	GameState.remove_item(item_id, 1)
	_player_gold += price
	GameState.gold = _player_gold
	print("[ShopUI] Sold: %s (+%d G) — new gold=%d" % [item_id, price, _player_gold])
	_refresh_shop()

func close() -> void:
	visible = false
	_try_show_hotbar()
	shop_closed.emit()
