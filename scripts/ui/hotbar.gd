extends Control
# =============================================================================
# HOTBAR v2 - 5 slot cố định map 1:1 với GameState.toolbar
# =============================================================================
# Hiển thị dưới màn hình gameplay. Mỗi slot gắn phím 1-5 (đã đăng ký trong
# InputMap và xử lý qua HotkeyInputManager).
# Không dùng scroll wheel nữa; thay vào đó player chọn trực tiếp bằng phím
# hoặc click vào slot trên hotbar.
# =============================================================================

const NUM_SLOTS: int = 5

@export_group("Slot Layout")
## Tên các node slot trong SlotsContainer (sửa nếu muốn đổi tên slot)
@export var slot_node_names: PackedStringArray = PackedStringArray([
	"Slot0", "Slot1", "Slot2", "Slot3", "Slot4"
])
## Khoảng cách giữa các slot (px)
@export var slot_separation: int = 6

@export_group("Number Label (góc trên-trái)")
## Font size cho số "1"..."5"
@export var number_font_size: int = 7
## Màu số "1"..."5"
@export var number_color: Color = Color(1.0, 0.92, 0.55, 1.0)
## Padding trái (px) — cách mép trái slot
@export var number_padding_left: int = 3
## Padding trên (px) — cách mép trên slot
@export var number_padding_top: int = 1

@export_group("Icon Label (giữa slot)")
## Font size cho icon item
@export var icon_font_size: int = 14
## Màu icon khi không có item_data
@export var icon_default_color: Color = Color(1.0, 1.0, 1.0, 1.0)

@export_group("Count Label (góc dưới-phải)")
## Font size cho số lượng ("99")
@export var count_font_size: int = 7
## Font size cho chữ "x" tiền tố (nhỏ hơn số)
@export var count_x_font_size: int = 5
## Màu số lượng
@export var count_color: Color = Color(1.0, 0.9, 0.5, 1.0)
## Padding phải (px)
@export var count_padding_right: int = 1
## Padding dưới (px)
@export var count_padding_bottom: int = 1

@export_group("Selection Style")
## Border color khi slot đang active
@export var selected_border_color: Color = Color(1.0, 0.85, 0.3, 1.0)
## Border color khi slot không active, có item
@export var item_border_color: Color = Color(0.8, 0.65, 0.3, 0.9)
## Border color khi slot rỗng
@export var empty_border_color: Color = Color(0.5, 0.4, 0.3, 0.6)
## Border width khi active (px)
@export var selected_border_width: int = 2
## Border width khi không active (px)
@export var unselected_border_width: int = 1

var _slot_panels: Array[PanelContainer] = []
var _slot_labels: Array[RichTextLabel] = []  # count labels
var _slot_icons: Array[Label] = []
var _slot_numbers: Array[Label] = []  # number labels "1"..."5"

# Vị trí đang "active" (mặc định = 0) - slot mà player vừa chọn/dùng.
# Track để biết khi GameState.remove_item() nên trừ từ inventory hay toolbar.
var active_slot: int = 0

signal selected_item_changed(item_id: String, item_data: ItemData)

func _ready() -> void:
	add_to_group("hotbar")
	_setup_slots()
	_refresh()
	_apply_selection_style(active_slot)
	# Sync với GameState
	GameState.selected_toolbar_slot = active_slot
	GameState.toolbar_changed.connect(_on_toolbar_changed)
	# Force refresh khi scene chuyển xong: lúc này GameState.toolbar đã được
	# _ready của Hotbar đọc 1 lần, nhưng nếu scene B khác với scene A về layout
	# (anchor, position) → offsets của NumLabel đã set ở scene A có thể không
	# khớp slot panel của scene B. Đợi 2 frame rồi refresh lại.
	SceneManager.scene_changed.connect(_on_scene_changed_refresh)
	mouse_exited.connect(_on_hotbar_leave)

func _on_scene_changed_refresh(_scene_path: String) -> void:
	# Đợi 1 frame để WorldUIManager ở scene mới spawn xong layout, sau đó
	# tính lại vị trí NumLabel và refresh data từ GameState.toolbar.
	# Lưu ý: ở scene mới, Hotbar MỚI sẽ _ready riêng — handler này gắn vào
	# Hotbar CŨ (đang bị free). Khi scene_changed emit, Hotbar cũ đã hoặc đang
	# bị queue_free — guard is_instance_valid để tránh chạy trên node đã free.
	if not is_instance_valid(self):
		return
	# Tính lại vị trí NumLabel theo panel slot hiện tại (chỉ thực sự cần nếu
	# cùng instance qua scene change, nhưng an toàn khi gọi).
	var tree := get_tree()
	if tree == null:
		return
	await tree.process_frame
	if not is_instance_valid(self):
		return
	_recompute_number_positions()
	_refresh()
	_apply_selection_style(active_slot)

func _recompute_number_positions() -> void:
	# Tính lại anchor/offset của NumLabel cho từng slot dựa trên
	# global_rect hiện tại (sau khi PanelContainer đã layout xong).
	var root_global_rect: Rect2 = get_global_rect()
	for i: int in range(NUM_SLOTS):
		if i >= _slot_panels.size():
			continue
		var panel: PanelContainer = _slot_panels[i]
		if panel == null:
			continue
		var num_lbl: Label = panel.get_node_or_null("NumLabel") as Label
		if num_lbl == null:
			continue
		# Đảm bảo NumLabel là con của Hotbar root (không phải PanelContainer)
		if num_lbl.get_parent() != self:
			var parent := num_lbl.get_parent()
			if parent != null:
				parent.remove_child(num_lbl)
			add_child(num_lbl)
		var slot_global_rect: Rect2 = panel.get_global_rect()
		var local_pos: Vector2 = slot_global_rect.position - root_global_rect.position
		var font: Font = num_lbl.get_theme_font("font")
		var font_height: float = 10.0
		if font != null:
			font_height = font.get_height(num_lbl.get_theme_font_size("font_size"))
		num_lbl.anchor_left = 0.0
		num_lbl.anchor_top = 0.0
		num_lbl.anchor_right = 0.0
		num_lbl.anchor_bottom = 0.0
		num_lbl.offset_left = local_pos.x + float(number_padding_left)
		num_lbl.offset_top = local_pos.y + float(number_padding_top)
		num_lbl.offset_right = local_pos.x + float(number_padding_left) + 8.0
		num_lbl.offset_bottom = local_pos.y + float(number_padding_top) + font_height + 2.0
		num_lbl.z_index = 10

func _on_hotbar_leave() -> void:
	# Mouse rời hoàn toàn khỏi hotbar -> ẩn tooltip của shop
	var shop_ui: CanvasLayer = get_tree().get_first_node_in_group("shop_ui")
	if shop_ui != null:
		if shop_ui.has_method("_hide_tooltip"):
			shop_ui._hide_tooltip()
		if shop_ui.has_method("_reset_hotbar_hover"):
			shop_ui._reset_hotbar_hover()

func _setup_slots() -> void:
	if slot_node_names.size() != NUM_SLOTS:
		push_warning("hotbar: slot_node_names phải có đúng %d phần tử" % NUM_SLOTS)
		return

	# DEBUG: in trạng thái GameState.toolbar để verify persist
	print("[Hotbar] _setup_slots ENTER, scene=", get_tree().current_scene.scene_file_path if get_tree().current_scene else "<none>", " toolbar=", GameState.toolbar)

	var container: Node = get_node_or_null("SlotsContainer")
	if container == null:
		push_error("hotbar: thiếu node 'SlotsContainer'")
		return
	container.add_theme_constant_override("separation", slot_separation)
	# SlotsContainer và Hotbar root mặc định mouse_filter = STOP sẽ nuốt
	# click phải khi bubble từ slot PanelContainer, khiến HotkeyInputManager/
	# Player không nhận được _unhandled_input. Đổi sang PASS để event tiếp
	# tục đi xuống unhandled chain → consume item hotbar active bất kể
	# click vào slot nào (không bắt buộc trúng đúng slot active).
	if container is Control:
		(container as Control).mouse_filter = Control.MOUSE_FILTER_PASS
	if self is Control:
		mouse_filter = Control.MOUSE_FILTER_PASS

	for i: int in range(NUM_SLOTS):
		var slot: Node = container.get_node_or_null(slot_node_names[i])
		if slot == null:
			push_warning("hotbar: thiếu node '%s' trong SlotsContainer" % slot_node_names[i])
			continue
		var panel: PanelContainer = slot as PanelContainer
		_slot_panels.append(panel)
		panel.gui_input.connect(_on_slot_input.bind(i))
		panel.mouse_entered.connect(_on_slot_hover.bind(i))
		panel.mouse_exited.connect(_on_slot_leave.bind(i))
		# Click phải chỉ select slot (xem _on_slot_input) — để Player/
		# HotkeyInputManager xử lý consume dựa trên slot active. Để event
		# bubble xuống _unhandled_input sau khi hotbar xử lý, đổi filter
		# sang PASS (mặc định STOP sẽ nuốt event trước khi tới _unhandled).
		panel.mouse_filter = Control.MOUSE_FILTER_PASS

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

		# Bind 3 label nodes đã có trong scene
		var num_lbl: Label = slot.get_node_or_null("NumLabel") as Label
		var icon_lbl: Label = slot.get_node_or_null("IconLabel") as Label
		var count_lbl: RichTextLabel = slot.get_node_or_null("CountLabel") as RichTextLabel

		if num_lbl != null:
			num_lbl.add_theme_font_size_override("font_size", number_font_size)
			num_lbl.add_theme_color_override("font_color", number_color)
			num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			num_lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
			# Click xuyên qua để PanelContainer cha nhận gui_input (kéo item).
			num_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_slot_numbers.append(num_lbl)
		else:
			push_warning("hotbar: slot '%s' thiếu NumLabel" % slot_node_names[i])

		if icon_lbl != null:
			icon_lbl.add_theme_font_size_override("font_size", icon_font_size)
			icon_lbl.add_theme_color_override("font_color", icon_default_color)
			# Click xuyên qua để PanelContainer cha nhận gui_input (kéo item).
			icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_slot_icons.append(icon_lbl)

		if count_lbl != null:
			count_lbl.add_theme_font_size_override("normal_font_size", count_font_size)
			count_lbl.add_theme_color_override("default_color", count_color)
			count_lbl.bbcode_enabled = true
			count_lbl.fit_content = true
			count_lbl.scroll_active = false
			count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			count_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			count_lbl.offset_left = -10.0
			count_lbl.offset_top = -10.0
			count_lbl.offset_right = -float(count_padding_right)
			count_lbl.offset_bottom = -float(count_padding_bottom)
			# RichTextLabel mặc định mouse_filter = STOP sẽ nuốt event khi
			# click vào vùng text, khiến PanelContainer cha không nhận được
			# gui_input → drag không hoạt động khi amount > 1 (CountLabel
			# visible và chiếm diện tích). Set IGNORE để click xuyên qua.
			count_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_slot_labels.append(count_lbl)

	# PanelContainer đã layout xong ở process frame tiếp theo → tính vị trí
	# NumLabel (reparent ra ngoài PanelContainer để container không ép resize).
	var tree := get_tree()
	if tree == null:
		return
	await tree.process_frame
	if not is_instance_valid(self):
		return
	_recompute_number_positions()

func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event
	if not mb.pressed:
		return
	if mb.button_index != MOUSE_BUTTON_WHEEL_UP and mb.button_index != MOUSE_BUTTON_WHEEL_DOWN:
		return
	# Không đổi slot khi đang ở UI khác (inventory / dialogue / shop đang mở)
	# để cuộn trong các panel này không bị nuốt.
	if _is_blocking_ui_open():
		return
	if GameState.toolbar.is_empty():
		return
	var direction: int = -1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1
	var next: int = (active_slot + direction) % GameState.toolbar.size()
	if next < 0:
		next += GameState.toolbar.size()
	set_active_slot(next)

func _is_blocking_ui_open() -> bool:
	var tree: SceneTree = get_tree()
	if tree == null:
		return false
	# Hội thoại đang mở
	var dm: Node = tree.get_first_node_in_group("dialogue_manager")
	if dm != null and dm.is_active:
		return true
	# Inventory / shop đang mở (các node này là CanvasLayer nên dùng .visible)
	for g: String in ["inventory_ui", "shop_ui"]:
		var node: Node = tree.get_first_node_in_group(g)
		if node != null and node.visible:
			return true
	return false

func get_selected_item() -> Dictionary:
	if GameState.toolbar.is_empty():
		return {}
	if active_slot < 0 or active_slot >= GameState.toolbar.size():
		active_slot = 0
	return GameState.toolbar[active_slot]

func get_selected_item_id() -> String:
	if GameState.toolbar.is_empty():
		return ""
	if active_slot < 0 or active_slot >= GameState.toolbar.size():
		active_slot = 0
	return GameState.toolbar[active_slot].get("id", "")

func get_selected_item_data() -> ItemData:
	var item_id: String = get_selected_item_id()
	if item_id == "":
		return null
	var db = get_node_or_null("/root/ItemDB")
	if db != null:
		return db.get_item(item_id)
	return null

func get_active_slot() -> int:
	if GameState.toolbar.is_empty():
		return 0
	if active_slot < 0 or active_slot >= GameState.toolbar.size():
		active_slot = 0
	return active_slot

func set_active_slot(slot_idx: int) -> void:
	if GameState.toolbar.is_empty():
		return
	var prev := active_slot
	active_slot = clamp(slot_idx, 0, GameState.toolbar.size() - 1)
	GameState.selected_toolbar_slot = active_slot  # Sync với GameState
	if prev != active_slot:
		_apply_selection_style(prev)
		_apply_selection_style(active_slot)
		_emit_selected_changed()

func get_slot_item_id(slot_idx: int) -> String:
	if slot_idx < 0 or slot_idx >= GameState.toolbar.size():
		return ""
	return GameState.toolbar[slot_idx].get("id", "")

func _apply_selection_style(slot_index: int) -> void:
	# Backward-compat: highlight slot đang active (default = 0) để tool khác
	# (farm_plot, v.v.) biết slot nào đang chọn.
	if _slot_panels.is_empty():
		return
	for i: int in range(_slot_panels.size()):
		var style: StyleBoxFlat = _slot_panels[i].get_theme_stylebox("panel") as StyleBoxFlat
		if style == null:
			continue
		if i == active_slot:
			style.border_color = selected_border_color
			style.border_width_left = selected_border_width
			style.border_width_top = selected_border_width
			style.border_width_right = selected_border_width
			style.border_width_bottom = selected_border_width
		else:
			style.border_color = empty_border_color
			style.border_width_left = unselected_border_width
			style.border_width_top = unselected_border_width
			style.border_width_right = unselected_border_width
			style.border_width_bottom = unselected_border_width

func _on_toolbar_changed() -> void:
	# Clamp active_slot về range hợp lệ nếu toolbar bị thu ngắn.
	if not GameState.toolbar.is_empty():
		if active_slot < 0 or active_slot >= GameState.toolbar.size():
			active_slot = 0
	_refresh()
	# Re-apply selection style để slot active (kể cả khi rỗng) giữ viền
	# selected sau khi item bị consume/đặt.
	_apply_selection_style(active_slot)
	_emit_selected_changed()

func _refresh() -> void:
	for i: int in range(NUM_SLOTS):
		_update_slot(i)

func _update_slot(slot_index: int) -> void:
	if slot_index >= _slot_icons.size() or slot_index >= _slot_labels.size() or slot_index >= _slot_panels.size():
		return
	if slot_index >= GameState.toolbar.size():
		return
	var icon_lbl: Label = _slot_icons[slot_index]
	var count_lbl: RichTextLabel = _slot_labels[slot_index]
	var panel: PanelContainer = _slot_panels[slot_index]

	var entry: Dictionary = GameState.toolbar[slot_index]
	var item_id: String = entry.get("id", "")
	var amount: int = int(entry.get("amount", 0))

	if item_id == "" or amount <= 0:
		icon_lbl.text = ""
		icon_lbl.visible = false
		count_lbl.visible = false
		var style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
		if style != null:
			style.border_color = empty_border_color
		return

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
		icon_lbl.add_theme_color_override("font_color", icon_default_color)
		icon_lbl.visible = true

	if amount > 1:
		count_lbl.text = "[font_size=%d]x[/font_size][font_size=%d]%d[/font_size]" % [
			count_x_font_size, count_font_size, amount
		]
		count_lbl.visible = true
	else:
		count_lbl.visible = false

	var style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style != null:
		style.border_color = item_border_color

# Highlight hotbar slot khi inventory đang drag — đã tắt theo yêu cầu
# (drag preview di chuyển theo chuột là đủ tín hiệu). Hàm giữ lại để reset
# style về default nếu bị override từ nơi khác; on=true không còn tác dụng.
func highlight_slot(slot_index: int, on: bool) -> void:
	if slot_index < 0 or slot_index >= _slot_panels.size():
		return
	var panel: PanelContainer = _slot_panels[slot_index]
	var style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style == null:
		return
	# on=true: bỏ — không highlight drop target
	if on:
		return
	# Reset về style mặc định (active / unselected) sau khi drag kết thúc.
	if slot_index == active_slot:
		style.border_color = selected_border_color
		style.border_width_left = selected_border_width
		style.border_width_top = selected_border_width
		style.border_width_right = selected_border_width
		style.border_width_bottom = selected_border_width
	else:
		var has_item: bool = GameState.toolbar[slot_index].get("id", "") != ""
		style.border_color = item_border_color if has_item else empty_border_color
		style.border_width_left = unselected_border_width
		style.border_width_top = unselected_border_width
		style.border_width_right = unselected_border_width
		style.border_width_bottom = unselected_border_width

func _on_slot_input(event: InputEvent, slot_index: int) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if slot_index >= GameState.toolbar.size():
		return

	# Chuột phải: KHÔNG consume trực tiếp tại đây. Hotbar chỉ chịu trách
	# nhiệm CHỌN slot — việc consume để HotkeyInputManager/Player xử lý
	# dựa trên slot đang active. Nếu ta xử lý consume ở đây thì bắt buộc
	# player phải click đúng vào slot active mới dùng được → trái với
	# mong muốn: chuột phải ở bất kỳ đâu khi slot active là CONSUMABLE đều
	# dùng được. Hơn nữa, PanelContainer mặc định mouse_filter = STOP sẽ
	# nuốt event trước khi tới _unhandled_input — để Player/HotkeyInputManager
	# xử lý được, hotbar phải bỏ qua (không gọi accept_event, không return).
	#
	# Tuy nhiên PanelContainer vẫn nuốt event theo cơ chế GUI dispatch —
	# nên ta chủ động gọi accept_event() để không nhân đôi logic, nhưng vẫn
	# không tự consume. Hệ quả: click phải vào hotbar slot chỉ đổi active
	# slot và bỏ qua — Player/HotkeyInputManager sẽ KHÔNG nhận event này.
	# Do đó flow đúng là: gọi set_active_slot() rồi ĐỂ event tiếp tục.
	if event.button_index == MOUSE_BUTTON_RIGHT:
		set_active_slot(slot_index)
		# Không accept_event — để HotkeyInputManager/Player nhận event và
		# consume item đang active (theo mong muốn: click ở đâu cũng dùng
		# được item active, không cần trúng đúng slot đó).
		return

	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	# Khi inventory đang mở, click vào hotbar slot vẫn phải select slot
	# (đổi active_slot). Đồng thời delegate sang inventory để bắt đầu drag
	# — preview sẽ di theo chuột; nếu thả cùng slot thì không swap, slot
	# vẫn ở trạng thái "selected" (đã select trước đó).
	var inv_ui: CanvasLayer = get_tree().get_first_node_in_group("inventory_ui")
	if inv_ui != null and inv_ui.visible:
		var entry: Dictionary = GameState.toolbar[slot_index]
		if entry.get("id", "") != "":
			set_active_slot(slot_index)
			inv_ui._start_drag(100 + slot_index, entry.get("id", ""), int(entry.get("amount", 0)))
		else:
			set_active_slot(slot_index)
		return

	var item_id: String = GameState.toolbar[slot_index].get("id", "")
	if item_id == "":
		# Click vào slot rỗng vẫn set active (để tool/seed không hoạt động)
		set_active_slot(slot_index)
		return
	# Click = chọn slot này làm active (không auto-use như phím 1-5; chỉ chọn)
	set_active_slot(slot_index)

func _emit_selected_changed() -> void:
	var item_id: String = get_selected_item_id()
	var data: ItemData = get_selected_item_data()
	selected_item_changed.emit(item_id, data)

func _on_slot_hover(slot_index: int) -> void:
	if slot_index >= GameState.toolbar.size():
		return
	var entry: Dictionary = GameState.toolbar[slot_index]
	var item_id: String = entry.get("id", "")
	if item_id == "":
		return

	var shop_ui: CanvasLayer = get_tree().get_first_node_in_group("shop_ui")
	if shop_ui != null and shop_ui.has_method("_show_tooltip_for_hotbar"):
		shop_ui._show_tooltip_for_hotbar(item_id)

func _on_slot_leave(slot_index: int) -> void:
	var shop_ui: CanvasLayer = get_tree().get_first_node_in_group("shop_ui")
	if shop_ui != null and shop_ui.has_method("_reset_hotbar_hover"):
		shop_ui._reset_hotbar_hover()
