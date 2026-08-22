extends Control
# =============================================================================
# TOOLTIP PANEL (Bảng Thông tin Vật phẩm)
# =============================================================================
# Chức năng: Hiển thị thông tin vật phẩm khi hover
#
# Bug đã fix:
#   - Tooltip không bị stuck khi chuyển scene
#   - Thêm kiểm tra visibility trước khi xử lý
#   - Reset state khi bị hide
# =============================================================================

var _item_id: String = ""
var _type_label: Label = null

# =============================================================================
# BIẾN THEO DÕI TRẠNG THÁI
# =============================================================================
# Cờ đánh dấu tooltip có đang active không
var _tooltip_active: bool = false

func _ready() -> void:
	visible = false
	_tooltip_active = false


# =============================================================================
# HÀM HIỂN THỊ TOOLTIP (show_for_item)
# =============================================================================

func show_for_item(item_id: String) -> void:
	if item_id == "":
		hide()
		return

	_item_id = item_id
	var data: ItemData = null
	var db = get_node_or_null("/root/ItemDB")
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

	# =================================================================
	# SỬA LỖI: Đánh dấu tooltip đang active
	# =================================================================
	_tooltip_active = true
	visible = true


# =============================================================================
# HÀM ẨN TOOLTIP (hide)
# =============================================================================

func hide() -> void:
	# =================================================================
	# SỬA LỖI: Reset state khi ẩn tooltip
	# =================================================================
	visible = false
	_tooltip_active = false
	_item_id = ""


# =============================================================================
# HÀM CẬP NHẬT MỖI FRAME (_process)
# =============================================================================
# KIỂM TRA: Chỉ cập nhật vị trí khi tooltip thực sự visible

func _process(_delta: float) -> void:
	# =================================================================
	# SỬA LỖI: Kiểm tra tooltip có đang active không
	# Nếu không active hoặc không visible, không làm gì
	# =================================================================
	if not _tooltip_active or not visible:
		return
	
	# Kiểm tra viewport còn tồn tại không
	if not is_instance_valid(get_viewport()):
		hide()
		return
	
	var mouse_pos := get_global_mouse_position()
	var screen_size := get_viewport_rect().size
	var tooltip_size := size

	var new_pos := mouse_pos + Vector2(12, -tooltip_size.y - 4)
	if new_pos.x + tooltip_size.x > screen_size.x:
		new_pos.x = mouse_pos.x - tooltip_size.x - 12
	if new_pos.y < 0:
		new_pos.y = mouse_pos.y + 20

	global_position = new_pos
