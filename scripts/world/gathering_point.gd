extends Area2D
class_name GatheringPoint
## =============================================================================
## GATHERING POINT — Điểm thu thập vật phẩm trên bản đồ (Forest/Mountain)
## =============================================================================
## Interactive object cho phép player thu thập item một lần (persistent), hoặc
## dùng chế độ daily_spawn để mỗi điểm tự roll khả năng xuất hiện theo ngày.
## Daily roll được giữ ổn định qua scene change và reset bằng marker ngày mới.
## =============================================================================

@export var gathering_id: String = ""
@export var item_id: String = "apple"
@export var quantity: int = 1
@export var interaction_priority: int = 10
@export var prompt_offset_y: float = -32.0
@export_range(0.0, 1.0, 0.01) var daily_spawn_chance: float = 0.0
@export var respawn_daily: bool = false

const INTERACT_DISTANCE: float = 18.0

var prompt: Label = null
var visual: Node = null
var _player: Node = null
var _player_nearby: bool = false
var _collected: bool = false
var _daily_available: bool = true
var _current_day: int = -1

signal item_collected(gathering_id: String, item_id: String, quantity: int)

func _ready() -> void:
	add_to_group("gathering_point")
	visual = get_node_or_null("Visual")
	_ensure_prompt_label()
	prompt.visible = false
	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		_player = _find_player_in_tree()

	if gathering_id == "":
		push_warning("[GatheringPoint] gathering_id trống — persistence sẽ không hoạt động!")

	if respawn_daily:
		if not GameState.day_changed.is_connected(_on_day_changed):
			GameState.day_changed.connect(_on_day_changed)
		_refresh_daily_state()
	# Áp dụng trạng thái đã lưu — nếu đã thu thập thì ẩn ngay.
	elif gathering_id != "" and GameState.is_gathering_collected(gathering_id):
		_apply_collected_state(false)

func _on_day_changed(new_day: int) -> void:
	if respawn_daily and new_day != _current_day:
		_refresh_daily_state()

func _refresh_daily_state() -> void:
	_current_day = GameState.current_day
	_daily_available = GameState.roll_daily_gathering_spawn(gathering_id, _current_day, daily_spawn_chance)
	_collected = _daily_available and GameState.is_daily_gathering_collected(gathering_id, _current_day)
	_player_nearby = false
	if visual != null and is_instance_valid(visual):
		visual.visible = _daily_available and not _collected
	if prompt != null:
		prompt.visible = false
	_register_with_manager(false)

func _ensure_prompt_label() -> void:
	if has_node("Prompt"):
		prompt = $Prompt
	else:
		prompt = Label.new()
		prompt.name = "Prompt"
		add_child(prompt)

	prompt.anchor_left = 0.0
	prompt.anchor_top = 0.0
	prompt.anchor_right = 0.0
	prompt.anchor_bottom = 0.0
	prompt.offset_left = -16.0
	prompt.offset_top = prompt_offset_y
	prompt.offset_right = 16.0
	prompt.offset_bottom = prompt_offset_y + 8.0

	prompt.text = "[E]"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 6)
	prompt.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	prompt.z_index = 20

func _find_player_in_tree() -> Node:
	var root: Node = get_tree().root
	if root == null:
		return null
	return _find_child_by_group(root, "player")

func _find_child_by_group(node: Node, group: String) -> Node:
	if node == null:
		return null
	if node.is_in_group(group):
		return node
	for child in node.get_children():
		var found := _find_child_by_group(child, group)
		if found != null:
			return found
	return null

func is_player_nearby() -> bool:
	if _collected:
		return false
	if respawn_daily and not _daily_available:
		return false
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		return false
	var dist := global_position.distance_to(_player.global_position)
	return dist <= INTERACT_DISTANCE

func _process(_delta: float) -> void:
	if _collected:
		return
	if respawn_daily and not _daily_available:
		return
	if GameState.player_movement_locked or GameState.cinematic_intro_state != GameState.CINEMATIC_NONE or DialogueManager.is_active:
		return
	var nearby := is_player_nearby()
	if nearby != _player_nearby:
		_player_nearby = nearby
		prompt.visible = nearby
		_register_with_manager(nearby)

## Gọi bởi InteractionPromptManager khi player bấm [E]
func interact(_player_ref: Node) -> void:
	if _collected:
		return
	if respawn_daily and not _daily_available:
		return
	if GameState.player_movement_locked or GameState.cinematic_intro_state != GameState.CINEMATIC_NONE or DialogueManager.is_active:
		return

	# Thêm item vào inventory
	var added: bool = GameState.add_item(item_id, quantity)
	if not added:
		_show_feedback("Túi đồ đã đầy!")
		return

	# Đánh dấu đã thu thập theo đúng loại điểm.
	if gathering_id != "":
		if respawn_daily:
			GameState.mark_daily_gathering_collected(gathering_id, _current_day)
		else:
			GameState.mark_gathering_collected(gathering_id)
	
	_apply_collected_state(true)
	item_collected.emit(gathering_id, item_id, quantity)

## show_feedback: true khi vừa thu thập (hiện feedback); false khi chỉ load state
func _apply_collected_state(show_feedback: bool) -> void:
	_collected = true
	if visual != null and is_instance_valid(visual):
		visual.visible = false
	if prompt != null:
		prompt.visible = false
	_register_with_manager(false)
	
	if show_feedback:
		var item_name: String = _get_item_display_name(item_id)
		_show_feedback("Đã nhặt %s x%d!" % [item_name, quantity])

func _get_item_display_name(id: String) -> String:
	var db: Node = get_node_or_null("/root/ItemDB")
	if db != null and db.has_method("get_item"):
		var data: ItemData = db.call("get_item", id)
		if data != null and data.display_name != "":
			return data.display_name
	return id

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

func is_collected() -> bool:
	return _collected
