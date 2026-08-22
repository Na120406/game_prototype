extends CanvasLayer
# =============================================================================
# FloatingWarning (Autoload)
# =============================================================================
# Hiển thị text cảnh báo lơ lửng trên đầu player (label chỉ vào player node).
# Auto-spawn Label, gắn vào player, fade in/out, queue_free sau khi xong.
#
# Cách dùng:
#   FloatingWarning.show_text("Đã muộn rồi!")
#   FloatingWarning.show_text_for("Đã muộn rồi!", 3.0)
# =============================================================================

const PLAYER_GROUP := "player"
const ABOVE_HEAD_OFFSET := Vector2(0, -40)
const DEFAULT_DURATION := 2.5
const FADE_DURATION := 0.4
const FONT_SIZE := 14

var _current_label: Label = null
var _current_player: Node2D = null
var _current_tween: Tween = null

func _ready() -> void:
	layer = 100
	print("[FloatingWarning] Ready.")

func _process(_delta: float) -> void:
	if _current_label == null or not is_instance_valid(_current_label):
		return
	if _current_player == null or not is_instance_valid(_current_player):
		return
	_current_label.global_position = _current_player.global_position + ABOVE_HEAD_OFFSET

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
	add_child(label)
	if _current_player != null:
		label.global_position = _current_player.global_position + ABOVE_HEAD_OFFSET
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