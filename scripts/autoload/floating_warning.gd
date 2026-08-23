extends CanvasLayer
# =============================================================================
# FloatingWarning (Autoload)
# =============================================================================
# Hiển thị text cảnh báo lơ lửng trên đầu player.
#
# Cách dùng:
#   FloatingWarning.show_text("Đã muộn rồi!")
#   FloatingWarning.show_text_plain("It's late")  # text trắng, cỡ 12, no style
#
# Implementation notes:
#   - "above head" labels được gắn vào Player node (Node2D) để camera 2D tự
#     transform theo player. KHÔNG gắn vào CanvasLayer vì CanvasLayer không bị
#     camera 2D ảnh hưởng → label sẽ "đứng yên" ở world coords và có thể
#     nằm ngoài viewport khi camera di chuyển.
#   - "center" labels (fallback khi không tìm thấy player) gắn vào canvas
#     layer vì là UI giữa màn hình, không cần world transform.
# =============================================================================

const PLAYER_GROUP := "player"
# Đặt label ngay phía trên đầu player. Offset Y âm đủ để text "hover" sát
# mép trên sprite player (sprite 16x16 → head ở Y ≈ -8 so với player origin).
# -20 là khoảng cách vừa đủ để text không chạm sprite nhưng vẫn sát đầu.
const ABOVE_HEAD_OFFSET := Vector2(0, -20)
const DEFAULT_DURATION := 2.5
const DEFAULT_DURATION_PLAIN := 1.5
const FADE_DURATION := 0.4
const FONT_SIZE := 14
const FONT_SIZE_PLAIN := 8

var _current_label: CanvasItem = null
var _current_player: Node2D = null
var _current_tween: Tween = null

func _ready() -> void:
	layer = 100
	print("[FloatingWarning] Ready.")

func _process(_delta: float) -> void:
	# center label (gắn vào CanvasLayer) không cần update — đã ở giữa màn hình
	# bằng anchors. above-head label là child của Player → cũng tự follow, không
	# cần set position mỗi frame.
	pass

func show_text(text: String) -> void:
	show_text_for(text, DEFAULT_DURATION)

func show_text_for(text: String, duration: float) -> void:
	_hide_current()
	_current_player = _find_player()
	if _current_player == null:
		_current_label = _spawn_center_label(text)
	else:
		_current_label = _spawn_above_head_label(text)
	if _current_label == null:
		return
	_current_label.modulate.a = 0.0
	_current_tween = create_tween()
	_current_tween.tween_property(_current_label, "modulate:a", 1.0, FADE_DURATION)
	_current_tween.tween_interval(duration)
	_current_tween.tween_property(_current_label, "modulate:a", 0.0, FADE_DURATION)
	_current_tween.tween_callback(_on_fade_finished)

# Variant "plain" — text trắng cơ bản, cỡ 12, KHÔNG outline/tint vàng.
# Dùng cho các cảnh báo nhẹ như "It's late" — không muốn trông như popup
# nặng, chỉ cần thông tin nhanh trên đầu player.
func show_text_plain(text: String) -> void:
	show_text_plain_for(text, DEFAULT_DURATION_PLAIN)

func show_text_plain_for(text: String, duration: float) -> void:
	_hide_current()
	_current_player = _find_player()
	if _current_player == null:
		_current_label = _spawn_center_label_plain(text)
	else:
		_current_label = _spawn_above_head_label_plain(text)
	if _current_label == null:
		return
	_current_label.modulate.a = 0.0
	_current_tween = create_tween()
	_current_tween.tween_property(_current_label, "modulate:a", 1.0, FADE_DURATION)
	_current_tween.tween_interval(duration)
	_current_tween.tween_property(_current_label, "modulate:a", 0.0, FADE_DURATION)
	_current_tween.tween_callback(_on_fade_finished)

func _spawn_above_head_label_plain(text: String) -> Label:
	var label := Label.new()
	label.text = text
	# Cỡ chữ 8, trắng cơ bản — KHÔNG outline và KHÔNG tint.
	label.add_theme_font_size_override("font_size", FONT_SIZE_PLAIN)
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.z_index = 999
	# Gắn vào Player để camera 2D transform label theo player.
	if _current_player != null:
		_current_player.add_child(label)
		# Đợi 1 frame để Label tính size từ font + text, rồi căn GIỮA trên
		# đầu player.
		_attach_above_head_centered.call_deferred(label)
	else:
		add_child(label)
	return label

# Sau khi label vào scene tree và tính xong size, căn giữa X + đặt tại
# ABOVE_HEAD_OFFSET (top-left của text rect nằm tại offset).
func _attach_above_head_centered(label: Label) -> void:
	if not is_instance_valid(label):
		return
	var sz: Vector2 = label.size
	# Đặt tâm text tại X=0 (giữa player), top của text ở ABOVE_HEAD_OFFSET.y.
	label.position = Vector2(-sz.x * 0.5, ABOVE_HEAD_OFFSET.y)

func _spawn_center_label_plain(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", FONT_SIZE_PLAIN)
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_CENTER)
	add_child(label)
	label.position.x = -label.size.x * 0.5
	label.position.y = -label.size.y * 0.5
	return label

func _on_fade_finished() -> void:
	if is_instance_valid(_current_label):
		_current_label.queue_free()
	_current_label = null
	_current_player = null

func _hide_current() -> void:
	if _current_tween != null and _current_tween.is_running():
		_current_tween.kill()
	if _current_label != null and is_instance_valid(_current_label):
		_current_label.queue_free()
	_current_label = null

func _find_player() -> Node2D:
	var tree := get_tree()
	if tree == null:
		return null
	var node := tree.get_first_node_in_group(PLAYER_GROUP)
	if node is Node2D:
		return node
	return null

func _spawn_above_head_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1.0))
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.z_index = 999
	# Gắn vào Player để camera 2D transform label theo player.
	if _current_player != null:
		_current_player.add_child(label)
		label.position = ABOVE_HEAD_OFFSET
	else:
		add_child(label)
	return label

func _spawn_center_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1.0))
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Đặt ở giữa màn hình bằng anchors
	label.set_anchors_preset(Control.PRESET_CENTER)
	add_child(label)
	# Căn giữa text trong rect của chính nó
	label.position.x = -label.size.x * 0.5
	label.position.y = -label.size.y * 0.5
	return label