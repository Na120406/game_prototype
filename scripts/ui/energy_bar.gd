extends Node

# EnergyBar — thanh năng lượng persistent ở góc dưới phải màn hình.
# Là autoload singleton: chạy trên root SceneTree, không bị destroy khi chuyển map.
# Thanh là 1 dải màu xanh liền, fill từ dưới lên theo % năng lượng.
# Hover theo cùng delay tooltip vật phẩm trong Inventory → hiển thị "E XX/XX".

const GREEN_COLOR := Color(0.30, 0.78, 0.35, 1.0)
const RED_COLOR := Color(0.85, 0.25, 0.20, 1.0)
const EMPTY_COLOR := Color(0.12, 0.09, 0.06, 0.9)

const BAR_W: float = 14.0
const BAR_H: float = 40.0
const BORDER_THICK: float = 1.0

var _fill: ColorRect = null
var _bar: Control = null
var _tooltip: Label = null
var _canvas: CanvasLayer = null

var _hover_timer: float = 0.0

func _ready() -> void:
	print("[EnergyBar] EnergyBar singleton ready.")
	_build_persistent_bar()
	if not GameState.energy_changed.is_connected(_on_energy_changed):
		GameState.energy_changed.connect(_on_energy_changed)
	_refresh()

func _build_persistent_bar() -> void:
	_canvas = CanvasLayer.new()
	_canvas.name = "EnergyBarCanvas"
	# Layer thấp (10) để EnergyBar KHÔNG che các UI popup/hội thoại.
	# Thứ tự layer mới:
	#   1:  UI canvas (hotbar, day info, map label)
	#   10: EnergyBar
	#   50: Dialogue (hội thoại)
	#   100: Inventory / Shop / Sleep prompt / FloatingWarning
	#   200+: Transition / scene change overlay
	_canvas.layer = 10
	add_child(_canvas)

	# Container thanh bar — neo góc dưới phải.
	_bar = Control.new()
	_bar.name = "EnergyBar"
	_bar.custom_minimum_size = Vector2(BAR_W + BORDER_THICK * 2, BAR_H + BORDER_THICK * 2)
	_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 0)
	_bar.offset_left = -BAR_W - BORDER_THICK * 2 - 12.0
	_bar.offset_top = -BAR_H - BORDER_THICK * 2 - 12.0
	_bar.offset_right = -12.0
	_bar.offset_bottom = -12.0
	_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_bar.mouse_entered.connect(_on_bar_mouse_entered)
	_bar.mouse_exited.connect(_on_bar_mouse_exited)
	_canvas.add_child(_bar)

	# Nền rỗng (màu empty).
	var empty_bg := ColorRect.new()
	empty_bg.name = "EmptyBG"
	empty_bg.color = EMPTY_COLOR
	empty_bg.offset_left = BORDER_THICK
	empty_bg.offset_top = BORDER_THICK
	empty_bg.offset_right = BAR_W + BORDER_THICK
	empty_bg.offset_bottom = BAR_H + BORDER_THICK
	empty_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(empty_bg)

	# Thanh fill — 1 dải màu liền, scale chiều cao = % năng lượng.
	_fill = ColorRect.new()
	_fill.name = "Fill"
	_fill.color = GREEN_COLOR
	_fill.offset_left = BORDER_THICK
	_fill.offset_right = BAR_W + BORDER_THICK
	_fill.offset_bottom = BAR_H + BORDER_THICK
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(_fill)

	# Viền trái.
	var bl := ColorRect.new()
	bl.name = "BL"
	bl.color = Color(0.55, 0.45, 0.25, 0.8)
	bl.offset_left = 0.0
	bl.offset_top = 0.0
	bl.offset_right = BORDER_THICK
	bl.offset_bottom = BAR_H + BORDER_THICK * 2
	bl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(bl)

	# Viền phải.
	var br := ColorRect.new()
	br.name = "BR"
	br.color = Color(0.55, 0.45, 0.25, 0.8)
	br.offset_left = BAR_W + BORDER_THICK
	br.offset_top = 0.0
	br.offset_right = BAR_W + BORDER_THICK * 2
	br.offset_bottom = BAR_H + BORDER_THICK * 2
	br.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(br)

	# Viền dưới.
	var bb := ColorRect.new()
	bb.name = "BB"
	bb.color = Color(0.55, 0.45, 0.25, 0.8)
	bb.offset_left = 0.0
	bb.offset_top = BAR_H + BORDER_THICK
	bb.offset_right = BAR_W + BORDER_THICK * 2
	bb.offset_bottom = BAR_H + BORDER_THICK * 2
	bb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(bb)

	# Viền trên.
	var bt := ColorRect.new()
	bt.name = "BT"
	bt.color = Color(0.55, 0.45, 0.25, 0.8)
	bt.offset_left = 0.0
	bt.offset_top = 0.0
	bt.offset_right = BAR_W + BORDER_THICK * 2
	bt.offset_bottom = BORDER_THICK
	bt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(bt)

	# Tooltip label — ẩn mặc định, hiện sau hover 2s.
	_tooltip = Label.new()
	_tooltip.name = "Tooltip"
	_tooltip.text = "20/20"
	_tooltip.add_theme_color_override("font_color", Color(1, 0.9, 0.6, 1))
	_tooltip.add_theme_font_size_override("font_size", 5)
	_tooltip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tooltip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tooltip.set_anchors_preset(Control.PRESET_CENTER)
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.visible = false
	_bar.add_child(_tooltip)

func _process(delta: float) -> void:
	if _hover_timer <= 0.0:
		return
	_hover_timer += delta
	if _hover_timer >= _get_tooltip_hover_delay():
		_tooltip.visible = true

func _get_tooltip_hover_delay() -> float:
	var config_manager: Node = get_node_or_null("/root/ConfigManager")
	if config_manager != null and config_manager.has_method("get_tooltip_hover_delay"):
		return float(config_manager.call("get_tooltip_hover_delay"))
	return 0.3

func _on_bar_mouse_entered() -> void:
	_hover_timer = 0.01

func _on_bar_mouse_exited() -> void:
	_hover_timer = 0.0
	_tooltip.visible = false

func _on_energy_changed(_new_value: float) -> void:
	_refresh()

func _refresh() -> void:
	var cur: float = clampf(GameState.energy, 0.0, GameState.max_energy)
	var max_e: float = GameState.max_energy
	var ratio: float = clampf(cur / max_e if max_e > 0 else 0.0, 0.0, 1.0)
	var low: bool = cur <= 5.0
	_fill.color = RED_COLOR if low else GREEN_COLOR

	var filled_h: float = BAR_H * ratio
	_fill.offset_top = BORDER_THICK + (BAR_H - filled_h)
	_fill.offset_bottom = BORDER_THICK + BAR_H

	if _tooltip != null:
		var cm: Node = get_node_or_null("/root/ConfigManager")
		_tooltip.text = "%d/%d" % [int(round(cur)), int(round(max_e))]
