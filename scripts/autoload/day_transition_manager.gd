extends Node

# DayTransitionManager — hiệu ứng chuyển ngày dùng chung cho mọi nguyên nhân:
# ngủ tại giường, hết năng lượng hoặc quá giờ không ngủ.
#
# Timeline cố định:
#   - 0.75s: hai mí đen kéo từ trên và dưới vào giữa
#   - 0.50s: giữ màn hình đen, chạy callback đổi ngày
#   - 0.75s: hai mí mở ra
# Tổng cộng đúng 2.0 giây.

signal transition_started
signal transition_black
signal transition_finished

const CLOSE_DURATION: float = 0.75
const BLACK_HOLD_DURATION: float = 0.50
const OPEN_DURATION: float = 0.75
const DIM_ALPHA: float = 0.28
const CANVAS_LAYER: int = 10000

var _active: bool = false
var _canvas: CanvasLayer = null
var _root: Control = null
var _top_lid: ColorRect = null
var _bottom_lid: ColorRect = null
var _dim_overlay: ColorRect = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func is_transition_active() -> bool:
	return _active

func play_day_transition(midpoint: Callable = Callable(), finished: Callable = Callable()) -> void:
	if _active:
		return
	_active = true
	GameState.player_movement_locked = true
	GameState.game_interacting = true
	_build_overlay()
	transition_started.emit()

	var close_tween := create_tween()
	close_tween.set_parallel(true)
	close_tween.set_trans(Tween.TRANS_SINE)
	close_tween.set_ease(Tween.EASE_IN_OUT)
	var half_height: float = get_viewport().get_visible_rect().size.y * 0.5
	close_tween.tween_property(_top_lid, "offset_bottom", half_height, CLOSE_DURATION)
	close_tween.tween_property(_bottom_lid, "offset_top", -half_height, CLOSE_DURATION)
	close_tween.tween_property(_dim_overlay, "color", Color(0.0, 0.0, 0.0, DIM_ALPHA), CLOSE_DURATION)
	await close_tween.finished

	transition_black.emit()
	if midpoint.is_valid():
		midpoint.call()
	await get_tree().create_timer(BLACK_HOLD_DURATION).timeout

	var open_tween := create_tween()
	open_tween.set_parallel(true)
	open_tween.set_trans(Tween.TRANS_SINE)
	open_tween.set_ease(Tween.EASE_IN_OUT)
	open_tween.tween_property(_top_lid, "offset_bottom", 0.0, OPEN_DURATION)
	open_tween.tween_property(_bottom_lid, "offset_top", 0.0, OPEN_DURATION)
	open_tween.tween_property(_dim_overlay, "color", Color(0.0, 0.0, 0.0, 0.0), OPEN_DURATION)
	await open_tween.finished

	if finished.is_valid():
		finished.call()
	_cleanup_overlay()
	# Tất cả luồng chuyển ngày đều kết thúc ở trạng thái có thể chơi lại.
	GameState.player_movement_locked = false
	GameState.game_interacting = false
	_active = false
	transition_finished.emit()

func _build_overlay() -> void:
	_cleanup_overlay()
	_canvas = CanvasLayer.new()
	_canvas.name = "DayTransitionLayer"
	_canvas.layer = CANVAS_LAYER
	_canvas.process_mode = Node.PROCESS_MODE_ALWAYS

	_root = Control.new()
	_root.name = "DayTransitionRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.add_child(_root)

	_dim_overlay = ColorRect.new()
	_dim_overlay.name = "BackgroundDim"
	_dim_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_dim_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_dim_overlay)

	_top_lid = ColorRect.new()
	_top_lid.name = "TopEyelid"
	_top_lid.color = Color.BLACK
	_top_lid.anchor_left = 0.0
	_top_lid.anchor_right = 1.0
	_top_lid.anchor_top = 0.0
	_top_lid.anchor_bottom = 0.0
	_top_lid.offset_left = 0.0
	_top_lid.offset_right = 0.0
	_top_lid.offset_top = 0.0
	_top_lid.offset_bottom = 0.0
	_top_lid.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_top_lid)

	_bottom_lid = ColorRect.new()
	_bottom_lid.name = "BottomEyelid"
	_bottom_lid.color = Color.BLACK
	_bottom_lid.anchor_left = 0.0
	_bottom_lid.anchor_right = 1.0
	_bottom_lid.anchor_top = 1.0
	_bottom_lid.anchor_bottom = 1.0
	_bottom_lid.offset_left = 0.0
	_bottom_lid.offset_right = 0.0
	_bottom_lid.offset_top = 0.0
	_bottom_lid.offset_bottom = 0.0
	_bottom_lid.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_bottom_lid)

	get_tree().root.add_child(_canvas)

func _input(event: InputEvent) -> void:
	if _active:
		get_viewport().set_input_as_handled()

func _cleanup_overlay() -> void:
	if _canvas != null and is_instance_valid(_canvas):
		_canvas.queue_free()
	_canvas = null
	_root = null
	_top_lid = null
	_bottom_lid = null
	_dim_overlay = null
