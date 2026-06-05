extends Control

const NUM_SLOTS: int = 3

var _slot_panels: Array[PanelContainer] = []
var _slot_labels: Array[Label] = []
var _slot_icons: Array[Label] = []
var _scroll_offset: int = 0
var _selected_index: int = 0
var _item_icons: Dictionary = {
	"apple": "A",
	"seed_turnip": "T",
	"water_can": "W",
	"health_potion": "H",
	"rope": "R",
}
var _item_colors: Dictionary = {
	"apple": Color(0.85, 0.2, 0.15, 1),
	"seed_turnip": Color(0.6, 0.8, 0.4, 1),
	"water_can": Color(0.3, 0.5, 0.8, 1),
	"health_potion": Color(0.8, 0.2, 0.6, 1),
	"rope": Color(0.6, 0.45, 0.3, 1),
}

func _ready() -> void:
	add_to_group("hotbar")
	_setup_slots()
	_refresh()
	GameState.inventory_changed.connect(_on_inventory_changed)
	print("[Hotbar] Ready.")

func _setup_slots() -> void:
	var slot_names: Array[String] = ["Slot0", "Slot1", "Slot2"]

	for i: int in range(NUM_SLOTS):
		var slot: Node = get_node_or_null("SlotsContainer/" + slot_names[i])
		if slot == null:
			continue
		_slot_panels.append(slot as PanelContainer)

		var icon_lbl := Label.new()
		icon_lbl.name = "IconLabel"
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon_lbl.add_theme_font_size_override("font_size", 14)
		icon_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		slot.add_child(icon_lbl)
		_slot_icons.append(icon_lbl)

		var count_lbl := Label.new()
		count_lbl.name = "CountLabel"
		count_lbl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		count_lbl.anchor_left = 1.0
		count_lbl.anchor_top = 1.0
		count_lbl.anchor_right = 1.0
		count_lbl.anchor_bottom = 1.0
		count_lbl.offset_left = -10.0
		count_lbl.offset_top = -10.0
		count_lbl.offset_right = -1.0
		count_lbl.offset_bottom = -1.0
		count_lbl.grow_horizontal = Control.GROW_DIRECTION_END
		count_lbl.grow_vertical = Control.GROW_DIRECTION_END
		count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		count_lbl.add_theme_font_size_override("font_size", 8)
		count_lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.5, 1))
		slot.add_child(count_lbl)
		_slot_labels.append(count_lbl)
		_apply_selection_style(i)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_change_selection(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_change_selection(1)

func _change_selection(direction: int) -> void:
	_selected_index = wrapi(_selected_index + direction, 0, NUM_SLOTS)
	for i: int in range(NUM_SLOTS):
		_apply_selection_style(i)
	_refresh()

func _apply_selection_style(slot_index: int) -> void:
	var panel: PanelContainer = _slot_panels[slot_index] if slot_index < _slot_panels.size() else null
	if panel == null:
		return
	var style: StyleBoxFlat = panel.get_theme_stylebox("panel")
	if style == null:
		return
	if slot_index == _selected_index:
		style.border_color = Color(1, 0.85, 0.3, 1)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
	else:
		style.border_color = Color(0.5, 0.4, 0.3, 0.6)
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1

func _on_inventory_changed() -> void:
	_refresh()

func _refresh() -> void:
	for i: int in range(NUM_SLOTS):
		_update_slot(i)

func _update_slot(slot_index: int) -> void:
	var icon_lbl: Label = _slot_icons[slot_index] if slot_index < _slot_icons.size() else null
	var count_lbl: Label = _slot_labels[slot_index] if slot_index < _slot_labels.size() else null
	var panel: PanelContainer = _slot_panels[slot_index] if slot_index < _slot_panels.size() else null

	if icon_lbl == null or count_lbl == null or panel == null:
		return

	var inv_idx: int = _scroll_offset + slot_index
	if inv_idx < GameState.inventory.size():
		var item: Dictionary = GameState.inventory[inv_idx]
		var item_id: String = item.get("id", "")
		var amount: int = item.get("amount", 1)

		icon_lbl.text = _item_icons.get(item_id, "?")
		icon_lbl.add_theme_color_override("font_color", _item_colors.get(item_id, Color(1, 1, 1, 1)))
		icon_lbl.visible = true

		if amount > 1:
			count_lbl.text = str(amount)
			count_lbl.visible = true
		else:
			count_lbl.visible = false

		var style: StyleBoxFlat = panel.get_theme_stylebox("panel")
		if style != null:
			style.border_color = Color(0.8, 0.65, 0.3, 0.9)
	else:
		icon_lbl.text = ""
		icon_lbl.visible = false
		count_lbl.visible = false
		var style: StyleBoxFlat = panel.get_theme_stylebox("panel")
		if style != null:
			style.border_color = Color(0.5, 0.4, 0.3, 0.6)
