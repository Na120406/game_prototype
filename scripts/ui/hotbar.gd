extends Control

const NUM_SLOTS: int = 3

var _slot_panels: Array[PanelContainer] = []
var _slot_labels: Array[Label] = []
var _slot_icons: Array[Label] = []
var _scroll_offset: int = 0
var _selected_index: int = 0

signal selected_item_changed(item_id: String, item_data: ItemData)

const _STYLE_SELECTED_COLOR := Color(1.0, 0.85, 0.3, 1.0)
const _STYLE_UNSELECTED_COLOR := Color(0.5, 0.4, 0.3, 0.6)
const _STYLE_ITEM_COLOR := Color(0.8, 0.65, 0.3, 0.9)

func _ready() -> void:
	add_to_group("hotbar")
	_setup_slots()
	_refresh()
	GameState.inventory_changed.connect(_on_inventory_changed)
	_apply_selection_style(_selected_index)
	mouse_exited.connect(_on_hotbar_leave)

func _on_hotbar_leave() -> void:
	# Mouse rời hoàn toàn khỏi hotbar -> ẩn tooltip
	var shop_ui: CanvasLayer = get_tree().get_first_node_in_group("shop_ui")
	if shop_ui != null:
		if shop_ui.has_method("_hide_tooltip"):
			shop_ui._hide_tooltip()
		if shop_ui.has_method("_reset_hotbar_hover"):
			shop_ui._reset_hotbar_hover()

func _setup_slots() -> void:
	var slot_names := ["Slot0", "Slot1", "Slot2"]

	for i: int in range(NUM_SLOTS):
		var slot: Node = get_node_or_null("SlotsContainer/" + slot_names[i])
		if slot == null:
			continue
		var panel: PanelContainer = slot as PanelContainer
		_slot_panels.append(panel)
		panel.gui_input.connect(_on_slot_input.bind(i))
		panel.mouse_entered.connect(_on_slot_hover.bind(i))
		panel.mouse_exited.connect(_on_slot_leave.bind(i))

		var original_style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
		var copy_style := StyleBoxFlat.new()
		if original_style != null:
			copy_style.bg_color = original_style.bg_color
			copy_style.border_color = original_style.border_color
			copy_style.border_width_left = original_style.border_width_left
			copy_style.border_width_top = original_style.border_width_top
			copy_style.border_width_right = original_style.border_width_right
			copy_style.border_width_bottom = original_style.border_width_bottom
			copy_style.corner_radius_top_left = original_style.corner_radius_top_left
			copy_style.corner_radius_top_right = original_style.corner_radius_top_right
			copy_style.corner_radius_bottom_right = original_style.corner_radius_bottom_right
			copy_style.corner_radius_bottom_left = original_style.corner_radius_bottom_left
			copy_style.content_margin_left = original_style.content_margin_left
			copy_style.content_margin_top = original_style.content_margin_top
			copy_style.content_margin_right = original_style.content_margin_right
			copy_style.content_margin_bottom = original_style.content_margin_bottom
		panel.add_theme_stylebox_override("panel", copy_style)

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

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_change_selection(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_change_selection(-1)

func get_selected_item() -> Dictionary:
	var inv_idx: int = _scroll_offset + _selected_index
	if inv_idx < GameState.inventory.size():
		return GameState.inventory[inv_idx]
	return {}

func get_selected_item_id() -> String:
	var item: Dictionary = get_selected_item()
	return item.get("id", "")

func get_selected_item_data() -> ItemData:
	var item_id: String = get_selected_item_id()
	if item_id == "":
		return null
	var db = get_node_or_null("/root/ItemDB")
	if db != null:
		return db.get_item(item_id)
	return null

func _change_selection(direction: int) -> void:
	var prev := _selected_index
	_selected_index = wrapi(_selected_index + direction, 0, NUM_SLOTS)
	_apply_selection_style(prev)
	_apply_selection_style(_selected_index)
	_emit_selected_changed()

func _apply_selection_style(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _slot_panels.size():
		return
	var panel: PanelContainer = _slot_panels[slot_index]
	var style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style == null:
		return
	if slot_index == _selected_index:
		style.border_color = _STYLE_SELECTED_COLOR
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
	else:
		style.border_color = _STYLE_UNSELECTED_COLOR
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1

func _on_inventory_changed() -> void:
	_refresh()
	_emit_selected_changed()

func _refresh() -> void:
	for i: int in range(NUM_SLOTS):
		_update_slot(i)

func _update_slot(slot_index: int) -> void:
	if slot_index >= _slot_icons.size() or slot_index >= _slot_labels.size() or slot_index >= _slot_panels.size():
		return
	var icon_lbl: Label = _slot_icons[slot_index]
	var count_lbl: Label = _slot_labels[slot_index]
	var panel: PanelContainer = _slot_panels[slot_index]

	var inv_idx: int = _scroll_offset + slot_index
	if inv_idx < GameState.inventory.size():
		var item: Dictionary = GameState.inventory[inv_idx]
		var item_id: String = item.get("id", "")
		var amount: int = item.get("amount", 1)

		var item_data: ItemData = null
		var db = get_node_or_null("/root/ItemDB")
		if db != null:
			item_data = db.get_item(item_id)
		if item_data != null:
			icon_lbl.text = item_data.icon
			icon_lbl.add_theme_color_override("font_color", item_data.item_color)
			icon_lbl.visible = true
		else:
			icon_lbl.text = "?"
			icon_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
			icon_lbl.visible = true

		if amount > 1:
			count_lbl.text = str(amount)
			count_lbl.visible = true
		else:
			count_lbl.visible = false

		var style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
		if style != null:
			style.border_color = _STYLE_ITEM_COLOR
	else:
		icon_lbl.text = ""
		icon_lbl.visible = false
		count_lbl.visible = false
		var style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
		if style != null:
			style.border_color = _STYLE_UNSELECTED_COLOR

func _on_slot_input(event: InputEvent, slot_index: int) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	var inv_idx: int = _scroll_offset + slot_index
	if inv_idx >= GameState.inventory.size():
		return

	var item: Dictionary = GameState.inventory[inv_idx]
	var item_id: String = item.get("id", "")
	if item_id == "":
		return

	_scroll_offset = 0
	_apply_selection_style(_selected_index)
	_selected_index = slot_index
	_apply_selection_style(_selected_index)

	if get_node_or_null("/root/ItemHandler") != null:
		if get_node_or_null("/root/ItemHandler").use_item(item_id):
			GameState.inventory_changed.emit()
	_emit_selected_changed()

func _emit_selected_changed() -> void:
	var item_id: String = get_selected_item_id()
	var data: ItemData = get_selected_item_data()
	selected_item_changed.emit(item_id, data)

func _on_slot_hover(slot_index: int) -> void:
	var inv_idx: int = _scroll_offset + slot_index
	if inv_idx >= GameState.inventory.size():
		return
	var item: Dictionary = GameState.inventory[inv_idx]
	var item_id: String = item.get("id", "")
	if item_id == "":
		return

	var shop_ui: CanvasLayer = get_tree().get_first_node_in_group("shop_ui")
	if shop_ui != null and shop_ui.has_method("_show_tooltip_for_hotbar"):
		shop_ui._show_tooltip_for_hotbar(item_id)

func _on_slot_leave(slot_index: int) -> void:
	# Không gọi hide ngay khi rời slot, vì có thể chuột chỉ di chuyển sang slot kế bên.
	# Việc hide/show sẽ do _on_slot_hover của slot tiếp theo xử lý.
	# Chỉ reset hotbar hover state (dùng để cancel tooltip timer nếu user rời hẳn).
	var shop_ui: CanvasLayer = get_tree().get_first_node_in_group("shop_ui")
	if shop_ui != null and shop_ui.has_method("_reset_hotbar_hover"):
		shop_ui._reset_hotbar_hover()
