extends Control

signal shop_closed()

const SHOP_ITEMS: Array[Dictionary] = [
	{
		"id": "seed_turnip",
		"name": "Turnip Seeds",
		"desc": "Plant in spring. Grows in 4 days.",
		"price": 10,
		"icon": "S"
	},
	{
		"id": "water_can",
		"name": "Watering Can",
		"desc": "Waters crops automatically.",
		"price": 30,
		"icon": "W"
	},
	{
		"id": "health_potion",
		"name": "Health Potion",
		"desc": "Restores 30 energy.",
		"price": 15,
		"icon": "H"
	},
	{
		"id": "rope",
		"name": "Rope",
		"desc": "Useful for climbing.",
		"price": 8,
		"icon": "R"
	},
]

var _player_gold: int = 100
var _items_bought: int = 0

@onready var backdrop: ColorRect = $Backdrop
@onready var gold_label: Label = $Panel/VBox/TitleBar/GoldLabel
@onready var items_list: VBoxContainer = $Panel/VBox/ItemsScroll/ItemsList
@onready var close_btn: Button = $Panel/VBox/Footer/CloseBtn
@onready var title_close_btn: Button = $Panel/VBox/TitleBar/CloseBtn
@onready var status_label: Label = $Panel/VBox/Footer/StatusLabel

func _ready() -> void:
	add_to_group("shop_ui")
	visible = false
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	close_btn.pressed.connect(_on_close)
	title_close_btn.pressed.connect(_on_close)

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_close()

func open(gold: int = 100) -> void:
	_player_gold = gold
	_items_bought = 0
	_refresh_shop()
	visible = true

func _refresh_shop() -> void:
	for child in items_list.get_children():
		child.queue_free()

	gold_label.text = "Gold: %d" % _player_gold

	for item in SHOP_ITEMS:
		var row := _make_item_row(item)
		items_list.add_child(row)

func _make_item_row(item: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()

	var icon := Label.new()
	icon.custom_minimum_size = Vector2(20, 0)
	icon.text = "[%s]" % item.get("icon", "?")
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(icon)

	var info := VBoxContainer.new()
	var name_lbl := Label.new()
	name_lbl.text = item.get("name", "???")
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85, 1))
	name_lbl.add_theme_font_size_override("font_size", 10)
	info.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = item.get("desc", "")
	desc_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
	desc_lbl.add_theme_font_size_override("font_size", 8)
	info.add_child(desc_lbl)
	row.add_child(info)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var price_lbl := Label.new()
	price_lbl.text = "%d G" % item.get("price", 0)
	price_lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.3, 1))
	price_lbl.add_theme_font_size_override("font_size", 10)
	price_lbl.custom_minimum_size = Vector2(40, 0)
	row.add_child(price_lbl)

	var buy_btn := Button.new()
	buy_btn.text = "Buy"
	buy_btn.custom_minimum_size = Vector2(40, 0)
	buy_btn.pressed.connect(_on_buy.bind(item))
	row.add_child(buy_btn)

	return row

func _on_buy(item: Dictionary) -> void:
	var price: int = item.get("price", 0)
	if _player_gold < price:
		status_label.text = "Not enough gold!"
		status_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4, 1))
		await get_tree().create_timer(1.5).timeout
		status_label.text = "Talk to buy"
		status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.8))
		return

	_player_gold -= price
	_items_bought += 1
	GameState.add_item(item.get("id", ""), 1)

	gold_label.text = "Gold: %d" % _player_gold
	status_label.text = "Bought: %s" % item.get("name", "???")
	status_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5, 1))
	await get_tree().create_timer(1.5).timeout
	status_label.text = "Talk to buy"
	status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.8))

func _on_close() -> void:
	visible = false
	shop_closed.emit()

func get_gold() -> int:
	return _player_gold
