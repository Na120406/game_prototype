extends Control

var _item_id: String = ""
var _type_label: Label = null

func _ready() -> void:
	visible = false

func show_for_item(item_id: String) -> void:
	if item_id == "":
		hide()
		return

	_item_id = item_id
	var data: ItemData = null
	var db = get_node("/root/ItemDB")
	if db != null:
		data = db.get_item(item_id)
	if data == null:
		hide()
		return

	var name_label: Label = $Margin/VBox/NameLabel
	var desc_label: Label = $Margin/VBox/DescLabel
	if _type_label == null:
		_type_label = Label.new()
		_type_label.add_theme_color_override("font_color", Color(0.6, 0.55, 0.5, 1))
		_type_label.add_theme_font_size_override("font_size", 7)
		$Margin/VBox.add_child(_type_label)

	name_label.text = data.display_name
	desc_label.text = data.description

	var type_str: String
	match data.item_type:
		ItemData.Type.CONSUMABLE: type_str = "Consumable"
		ItemData.Type.TOOL: type_str = "Tool"
		ItemData.Type.SEED: type_str = "Seed (%s)" % data.grow_season
		ItemData.Type.KEY_ITEM: type_str = "Key Item"
		ItemData.Type.CURRENCY: type_str = "Currency"
		_: type_str = "Item"
	_type_label.text = type_str

	var sell_str := "Sell: %d G" % data.sell_price if data.sell_price > 0 else ""
	var energy_str := "Energy: +%.0f" % data.energy_restore if data.energy_restore > 0 else ""
	var parts := [type_str, sell_str, energy_str].filter(func(s): return s != "")
	$Margin/VBox/DetailLabel.text = " | ".join(PackedStringArray(parts))

	visible = true

func _process(_delta: float) -> void:
	if visible:
		var mouse_pos := get_global_mouse_position()
		var screen_size := get_viewport_rect().size
		var tooltip_size := size

		var new_pos := mouse_pos + Vector2(12, -tooltip_size.y - 4)
		if new_pos.x + tooltip_size.x > screen_size.x:
			new_pos.x = mouse_pos.x - tooltip_size.x - 12
		if new_pos.y < 0:
			new_pos.y = mouse_pos.y + 20

		global_position = new_pos
