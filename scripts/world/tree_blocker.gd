extends StaticBody2D
class_name TreeBlocker
## =============================================================================
## TREE BLOCKER — Vật cản môi trường dùng chung cho Forest shortcut & Farm.
## =============================================================================
## Chặn đường đi (collision thật) cho tới khi player dùng Axe tương tác.
## Mỗi blocker có `blocker_id` riêng — persistent qua GameState.world_flags
## (xem game_state.gd: is_farm_blocker_cleared/clear_farm_blocker).
##
## KHÔNG có health/durability/animation/drop/wood economy — chỉ 1 lần
## interact() với Axe equipped sẽ xóa vĩnh viễn blocker này.
## Xem .hermes/plans/*-level-design-spatial-phases.md (Phase 3).
## =============================================================================

## ID duy nhất của blocker này — dùng làm key trong world_flags. Bắt buộc set
## trong Inspector hoặc khi instantiate; hai blocker không được trùng id.
@export var blocker_id: String = ""

@export var interaction_priority: int = 10
@export var prompt_offset_y: float = -28.0

const REQUIRED_TOOL_ID: String = "axe"
const INTERACT_DISTANCE: float = 50.0

signal blocker_cleared(blocker_id: String)

var prompt: Label = null
var visual: Node = null
var collision: CollisionShape2D = null

var _player: Node = null
var _player_nearby: bool = false
var _cleared: bool = false


func _ready() -> void:
	add_to_group("tree_blocker")
	visual = get_node_or_null("Visual")
	collision = get_node_or_null("CollisionShape2D")
	_ensure_prompt_label()
	prompt.visible = false
	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		_player = _find_player_in_tree()

	if blocker_id == "":
		push_warning("[TreeBlocker] blocker_id trống — persistence sẽ không hoạt động đúng!")

	# Áp dụng trạng thái đã lưu ngay khi scene load lại — KHÔNG hồi sinh
	# blocker đã bị clear ở lần chơi trước.
	if blocker_id != "" and GameState.is_farm_blocker_cleared(blocker_id):
		_apply_cleared_visuals(false)


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
	if _cleared:
		return false
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		return false
	var dist := global_position.distance_to(_player.global_position)
	return dist <= INTERACT_DISTANCE


func _process(_delta: float) -> void:
	if _cleared:
		return
	if GameState.player_movement_locked or GameState.cinematic_intro_state != GameState.CINEMATIC_NONE or DialogueManager.is_active:
		return
	var nearby := is_player_nearby()
	if nearby != _player_nearby:
		_player_nearby = nearby
		prompt.visible = nearby
		_register_with_manager(nearby)


## Gọi bởi InteractionPromptManager khi player bấm [E] trong tầm.
## Nếu Axe đang equip → clear blocker vĩnh viễn (persistent qua GameState).
## Nếu không → giữ collision, hiện feedback tiếng Việt, KHÔNG trừ gì cả.
func interact(_player_ref: Node) -> void:
	if _cleared:
		return
	if GameState.player_movement_locked or GameState.cinematic_intro_state != GameState.CINEMATIC_NONE or DialogueManager.is_active:
		return

	var tool_handler: Node = get_node_or_null("/root/ToolHandler")
	var has_axe_equipped: bool = tool_handler != null and tool_handler.has_method("is_equipped") and tool_handler.call("is_equipped", REQUIRED_TOOL_ID)

	if not has_axe_equipped:
		_show_feedback("Cần có Rìu để chặt gốc cây này!")
		return

	_clear_blocker()


func _clear_blocker() -> void:
	if blocker_id != "":
		GameState.clear_farm_blocker(blocker_id)
	_apply_cleared_visuals(true)
	blocker_cleared.emit(blocker_id)


## show_persisted_feedback: true khi vừa được clear NGAY (hiện feedback);
## false khi chỉ đang áp dụng lại trạng thái đã lưu lúc _ready() (im lặng).
func _apply_cleared_visuals(show_persisted_feedback: bool) -> void:
	_cleared = true
	if collision != null:
		collision.set_deferred("disabled", true)
	if visual != null and is_instance_valid(visual):
		visual.visible = false
	if prompt != null:
		prompt.visible = false
	_register_with_manager(false)
	if show_persisted_feedback:
		_show_feedback("Đã chặt gốc cây!")


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


func is_cleared() -> bool:
	return _cleared
