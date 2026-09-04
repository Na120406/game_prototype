extends StaticBody2D

# Táo có kích thước 12×12 px; chỉ cho nhặt khi player đứng sát vật thể.
const INTERACT_DISTANCE: float = 18.0

@export var prompt_offset_y: float = -28.0
@export var interaction_priority: int = 0

var prompt: Label = null

var _player: Node = null
var _player_nearby: bool = false
var _collected: bool = false

func _ready() -> void:
	# Táo là vật phẩm theo ngày: nếu đã nhặt trong ngày hiện tại thì không tồn tại.
	if GameState.get_flag("apple_collected_day", -1) == GameState.current_day:
		queue_free()
		return
	_ensure_prompt_label()
	prompt.visible = false
	_player = get_tree().get_first_node_in_group("player")
	_set_prompt_visible(false)


func _ensure_prompt_label() -> void:
	if has_node("Prompt"):
		prompt = $Prompt
	else:
		prompt = Label.new()
		prompt.name = "Prompt"
		add_child(prompt)

	# Thuần text trắng cỡ nhỏ
	prompt.anchor_left = 0.0
	prompt.anchor_top = 0.0
	prompt.anchor_right = 0.0
	prompt.anchor_bottom = 0.0
	prompt.offset_left = -12.0
	prompt.offset_top = prompt_offset_y
	prompt.offset_right = 12.0
	prompt.offset_bottom = prompt_offset_y + 8.0

	prompt.text = "[E]"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 6)
	prompt.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	prompt.z_index = 20


func is_player_nearby() -> bool:
	if _collected:
		return false
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		return false
	return global_position.distance_to(_player.global_position) <= INTERACT_DISTANCE


func _process(_delta: float) -> void:
	if _collected:
		return
	var nearby := is_player_nearby()
	if nearby != _player_nearby:
		_player_nearby = nearby
		_set_prompt_visible(nearby)
		_register_with_manager(nearby)


func _set_prompt_visible(v: bool) -> void:
	if prompt != null:
		prompt.text = "[E]"
		prompt.visible = v


func interact(_player_ref: Node) -> void:
	if _collected:
		return
	_collect()


func _collect() -> void:
	if not ItemManager.on_item_pickup("apple"):
		_show_feedback("Túi đồ đã đầy!")
		return
	_collected = true
	_set_prompt_visible(false)
	_register_with_manager(false)
	GameState.set_flag("apple_collected_day", GameState.current_day)
	_show_feedback("Đã nhặt Táo x1!")
	queue_free()


func _show_feedback(text: String) -> void:
	var warning: Node = get_node_or_null("/root/FloatingWarning")
	if warning != null and warning.has_method("show_text_plain"):
		warning.call("show_text_plain", text)


func _register_with_manager(nearby: bool) -> void:
	var mgr := _get_prompt_manager()
	if mgr == null:
		return
	if nearby:
		mgr.register_nearby(self)
	else:
		mgr.unregister_nearby(self)


func _get_prompt_manager() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("InteractionPromptManager")
