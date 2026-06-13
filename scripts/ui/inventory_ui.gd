extends Control

const COLS: int = 4
const TOTAL_SLOTS: int = 16
const SLOT_SIZE: Vector2 = Vector2(32, 32)
const SLOT_BG_COLOR := Color(0.12, 0.09, 0.18, 1.0)
const SLOT_HOVER_COLOR := Color(0.22, 0.16, 0.32, 1.0)
const SLOT_SELECTED_COLOR := Color(1.0, 0.82, 0.28, 0.9)
const SLOT_BORDER := Color(0.35, 0.28, 0.18, 0.8)
const SLOT_EMPTY := Color(0.18, 0.14, 0.25, 0.6)

var _slot_panels: Array[Panel] = []
var _slot_icons: Array[Label] = []
var _slot_counts: Array[Label] = []
var _slot_item_ids: Array[String] = []
var _hovered_slot: int = -1
var _tooltip: Label = null
var _tooltip_panel: Panel = null
var _tooltip_timer: Timer = null
var _pending_tooltip_slot: int = -1
var _game_paused_before: bool = false

func _ready() -> void:
	add_to_group("inventory_ui")
	visible = false
	_maybe_pause_tree(false)
	_build_grid()
	_build_tooltip()
	_refresh()
	GameState.inventory_changed.connect(_on_inventory_changed)

func _build_grid() -> void:
	var grid: GridContainer = get_node_or_null("Panel/VBox/GridContainer")
	if grid == null:
		return
	for i: int in range(TOTAL_SLOTS):
		var panel := Panel.new()
		panel.custom_minimum_size = SLOT_SIZE
		panel.name = "Slot%d" % i

		var style := StyleBoxFlat.new()
		style.bg_color = SLOT_BG_COLOR
		style.border_color = SLOT_EMPTY
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.corner_radius_top_left = 2
		style.corner_radius_top_right = 2
		style.corner_radius_bottom_right = 2
		style.corner_radius_bottom_left = 2
		panel.add_theme_stylebox_override("panel", style)

		panel.gui_input.connect(_on_slot_input.bind(i))
		panel.mouse_entered.connect(_on_slot_enter.bind(i))
		panel.mouse_exited.connect(_on_slot_leave.bind(i))

		var icon := Label.new()
		icon.name = "Icon"
		icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon.add_theme_font_size_override("font_size", 14)
		panel.add_child(icon)
		_slot_icons.append(icon)

		var count := Label.new()
		count.name = "Count"
		count.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		count.anchor_left = 1.0
		count.anchor_top = 1.0
		count.anchor_right = 1.0
		count.anchor_bottom = 1.0
		count.offset_left = -8.0
		count.offset_top = -8.0
		count.offset_right = -1.0
		count.offset_bottom = -1.0
		count.grow_horizontal = Control.GROW_DIRECTION_END
		count.grow_vertical = Control.GROW_DIRECTION_END
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		count.add_theme_font_size_override("font_size", 8)
		count.add_theme_color_override("font_color", Color(1, 0.92, 0.5, 1))
		panel.add_child(count)
		_slot_counts.append(count)

		grid.add_child(panel)
		_slot_panels.append(panel)
		_slot_item_ids.append("")

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

	_tooltip = Label.new()
	_tooltip.name = "TooltipLabel"
	_tooltip.add_theme_font_size_override("font_size", 7)
	_tooltip.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85, 1))
	_tooltip.text = ""
	_tooltip_panel.add_child(_tooltip)

	_tooltip_timer = Timer.new()
	_tooltip_timer.wait_time = 0.3
	_tooltip_timer.one_shot = true
	_tooltip_timer.timeout.connect(_show_tooltip)
	add_child(_tooltip_timer)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		_toggle()
		get_viewport().set_input_as_handled()
		return

	if not visible:
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion:
		var local := make_input_local(event as InputEventMouseMotion)
		var rect := get_global_rect()
		if not rect.has_point(get_global_mouse_position()):
			_clear_hover()

func _toggle() -> void:
	if visible:
		_close()
	else:
		_open()

func _open() -> void:
	_game_paused_before = GameState.is_paused
	GameState.is_paused = true
	visible = true
	_refresh()
	_hide_tooltip()

func _close() -> void:
	visible = false
	GameState.is_paused = _game_paused_before
	_hide_tooltip()
	_clear_hover()

func _refresh() -> void:
	for i: int in range(TOTAL_SLOTS):
		_update_slot(i)

func _update_slot(slot_idx: int) -> void:
	if slot_idx >= _slot_panels.size():
		return
	var panel: Panel = _slot_panels[slot_idx]
	var icon: Label = _slot_icons[slot_idx]
	var count: Label = _slot_counts[slot_idx]
	var style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat

	var item_id: String = ""
	var amount: int = 0

	if slot_idx < GameState.inventory.size():
		var entry: Dictionary = GameState.inventory[slot_idx]
		item_id = entry.get("id", "")
		amount = entry.get("amount", 1)

	_slot_item_ids[slot_idx] = item_id

	if item_id == "":
		icon.text = ""
		icon.visible = false
		count.visible = false
		if style != null:
			style.bg_color = SLOT_BG_COLOR
			style.border_color = SLOT_EMPTY
	else:
		var data: ItemData = ItemDB.get_item(item_id)
		if data != null:
			icon.text = data.icon
			icon.add_theme_color_override("font_color", data.item_color)
			icon.visible = true
			if style != null:
				style.bg_color = SLOT_BG_COLOR
				style.border_color = SLOT_BORDER
			if amount > 1:
				count.text = str(amount)
				count.visible = true
			else:
				count.visible = false
		else:
			icon.text = "?"
			icon.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
			icon.visible = true
			count.visible = false
			if style != null:
				style.border_color = SLOT_BORDER

	if slot_idx == _hovered_slot:
		_apply_hover_style(slot_idx)

func _on_inventory_changed() -> void:
	if visible:
		_refresh()

func _on_slot_enter(slot_idx: int) -> void:
	_hovered_slot = slot_idx
	_apply_hover_style(slot_idx)
	_pending_tooltip_slot = slot_idx
	_tooltip_timer.start()

func _on_slot_leave(slot_idx: int) -> void:
	_tooltip_timer.stop()
	if _hovered_slot == slot_idx:
		_hovered_slot = -1
		_apply_normal_style(slot_idx)
	_hide_tooltip()

func _apply_hover_style(slot_idx: int) -> void:
	if slot_idx >= _slot_panels.size():
		return
	var panel: Panel = _slot_panels[slot_idx]
	var style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style != null:
		style.bg_color = SLOT_HOVER_COLOR
		style.border_color = SLOT_SELECTED_COLOR
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2

func _apply_normal_style(slot_idx: int) -> void:
	if slot_idx >= _slot_panels.size():
		return
	var panel: Panel = _slot_panels[slot_idx]
	var style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style != null:
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		if _slot_item_ids[slot_idx] != "":
			style.bg_color = SLOT_BG_COLOR
			style.border_color = SLOT_BORDER
		else:
			style.bg_color = SLOT_BG_COLOR
			style.border_color = SLOT_EMPTY

func _on_slot_input(event: InputEvent, slot_idx: int) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if slot_idx >= GameState.inventory.size():
		return

	var entry: Dictionary = GameState.inventory[slot_idx]
	var item_id: String = entry.get("id", "")
	if item_id == "":
		return

	if event.button_index == MOUSE_BUTTON_LEFT:
		_use_item(slot_idx)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		_show_item_info(slot_idx)

func _use_item(slot_idx: int) -> void:
	if slot_idx >= GameState.inventory.size():
		return
	var entry: Dictionary = GameState.inventory[slot_idx]
	var item_id: String = entry.get("id", "")
	if item_id == "":
		return

	var data: ItemData = ItemDB.get_item(item_id)
	if data == null:
		return

	match data.item_type:
		ItemData.Type.CONSUMABLE:
			ItemHandler.use_item(item_id, true)
		ItemData.Type.TOOL:
			ItemHandler.use_item(item_id, false)
		ItemData.Type.SEED:
			ItemHandler.use_item(item_id, true)
		ItemData.Type.KEY_ITEM:
			_show_item_info(slot_idx)
		_:
			_show_item_info(slot_idx)

func _show_item_info(slot_idx: int) -> void:
	if slot_idx >= GameState.inventory.size():
		return
	var entry: Dictionary = GameState.inventory[slot_idx]
	var item_id: String = entry.get("id", "")
	if item_id == "":
		return

	var data: ItemData = ItemDB.get_item(item_id)
	if data == null:
		return

	var lines: Array[String] = []
	lines.append("[color=#FFD866]%s[/color]" % data.get_display_name())
	lines.append("[color=#AAA]%s[/color]" % data.get_type_name())
	if data.description != "":
		lines.append("[color=#CCC]%s[/color]" % data.description)
	lines.append("")
	var amount: int = entry.get("amount", 1)
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

	var panel_rect := get_global_rect()
	var slot_global_pos: Vector2
	if slot_idx < _slot_panels.size():
		slot_global_pos = _slot_panels[slot_idx].get_global_rect().position
	else:
		slot_global_pos = get_global_mouse_position()

	var tt_size := Vector2(120, 60)
	var tt_pos := slot_global_pos + Vector2(SLOT_SIZE.x + 4, 0)
	if tt_pos.x + tt_size.x > get_viewport_rect().size.x:
		tt_pos.x = slot_global_pos.x - tt_size.x - 4

	_tooltip_panel.position = tt_pos
	_tooltip_panel.custom_minimum_size = tt_size
	_tooltip_panel.visible = true
	_tooltip_timer.stop()

func _show_tooltip() -> void:
	if _pending_tooltip_slot < 0 or _pending_tooltip_slot >= GameState.inventory.size():
		_hide_tooltip()
		return
	var entry: Dictionary = GameState.inventory[_pending_tooltip_slot]
	var item_id: String = entry.get("id", "")
	if item_id == "":
		_hide_tooltip()
		return

	var data: ItemData = ItemDB.get_item(item_id)
	if data == null:
		_hide_tooltip()
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

	var slot_global_pos: Vector2
	if _pending_tooltip_slot < _slot_panels.size():
		slot_global_pos = _slot_panels[_pending_tooltip_slot].get_global_rect().position
	else:
		slot_global_pos = get_global_mouse_position()

	var tt_size := Vector2(100, 36)
	var tt_pos := slot_global_pos + Vector2(SLOT_SIZE.x + 4, 0)
	if tt_pos.x + tt_size.x > get_viewport_rect().size.x:
		tt_pos.x = slot_global_pos.x - tt_size.x - 4

	_tooltip_panel.position = tt_pos
	_tooltip_panel.custom_minimum_size = tt_size
	_tooltip_panel.visible = true

func _hide_tooltip() -> void:
	if _tooltip_panel != null:
		_tooltip_panel.visible = false
	_pending_tooltip_slot = -1

func _clear_hover() -> void:
	var prev := _hovered_slot
	_hovered_slot = -1
	_tooltip_timer.stop()
	_hide_tooltip()
	if prev >= 0:
		_apply_normal_style(prev)

func _maybe_pause_tree(pause: bool) -> void:
	get_tree().paused = pause
