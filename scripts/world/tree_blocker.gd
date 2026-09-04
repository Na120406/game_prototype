extends StaticBody2D
class_name TreeBlocker
## =============================================================================
## TREE BLOCKER — Vật cản môi trường dùng chung cho Forest shortcut & Farm.
## =============================================================================
## Chặn đường đi (collision thật) cho tới khi player dùng Axe tương tác.
## Mỗi blocker có `blocker_id` riêng — persistent qua GameState.world_flags
## (xem game_state.gd: is_farm_blocker_cleared/clear_farm_blocker).
##
## Mỗi blocker cần 3 hit với Axe selected; số hit còn lại được lưu theo
## blocker_id để không reset khi đổi scene giữa các nhát chặt.
## Xem .hermes/plans/*-level-design-spatial-phases.md (Phase 3).
## =============================================================================

## ID duy nhất của blocker này — dùng làm key trong world_flags. Bắt buộc set
## trong Inspector hoặc khi instantiate; hai blocker không được trùng id.
@export var blocker_id: String = ""

@export var interaction_priority: int = 10
@export var prompt_offset_y: float = -28.0

const REQUIRED_TOOL_ID: String = "axe"
const INTERACT_DISTANCE: float = 50.0
const REQUIRED_HITS: int = 3
const HITS_FLAG_PREFIX: String = "spatial_tree_hits_"

signal blocker_cleared(blocker_id: String)

var prompt: Label = null
var visual: Node = null
var collision: CollisionShape2D = null

var _player: Node = null
var _player_nearby: bool = false
var _cleared: bool = false
var _hits_remaining: int = REQUIRED_HITS


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
	if _is_persisted_cleared():
		_apply_cleared_visuals(false)
	else:
		_hits_remaining = _load_hits_remaining()
		_update_prompt_text()


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

	prompt.text = "[E] Chặt (3)"
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
		_update_prompt_text()
		_register_with_manager(nearby)


## Gọi bởi InteractionPromptManager khi player bấm [E] trong tầm.
## Nếu Axe đang equip → clear blocker vĩnh viễn (persistent qua GameState).
## Nếu không → giữ collision, hiện feedback tiếng Việt, KHÔNG trừ gì cả.
func interact(_player_ref: Node) -> void:
	if _cleared:
		return
	if GameState.player_movement_locked or GameState.cinematic_intro_state != GameState.CINEMATIC_NONE or DialogueManager.is_active:
		return

	# Contract gameplay: Axe phải nằm trong slot đang selected và player phải
	# sở hữu Axe; không phụ thuộc trạng thái equip cũ của ToolHandler.
	if not GameState.check_selected_hotbar_item(REQUIRED_TOOL_ID, 1) or not GameState.has_axe():
		_show_feedback("Cần vật gì đó để xử lý.")
		return

	var energy_manager: Node = get_tree().root.get_node_or_null("EnergyManager") if get_tree() != null else null
	if energy_manager != null and energy_manager.has_method("spend_energy"):
		if not energy_manager.call("spend_energy", 1):
			return
	_hits_remaining = maxi(0, _hits_remaining - 1)
	_save_hits_remaining()
	if _hits_remaining <= 0:
		_clear_blocker()
	else:
		_update_prompt_text()
		_show_feedback("Đã chặt! Còn %d lần." % _hits_remaining)


func _clear_blocker() -> void:
	_hits_remaining = 0
	_save_hits_remaining()
	if _is_forest_shortcut():
		GameState.clear_forest_shortcut()
	elif blocker_id != "":
		GameState.clear_farm_blocker(blocker_id)
	_apply_cleared_visuals(true)
	blocker_cleared.emit(blocker_id)


func _is_forest_shortcut() -> bool:
	return blocker_id == "forest_shortcut" or blocker_id == "forest_shortcut_tree"


func _is_persisted_cleared() -> bool:
	if _is_forest_shortcut():
		return GameState.is_forest_shortcut_cleared()
	if blocker_id == "":
		return false
	return GameState.is_farm_blocker_cleared(blocker_id)

func _hits_flag_key() -> String:
	return HITS_FLAG_PREFIX + blocker_id

func _load_hits_remaining() -> int:
	if blocker_id == "":
		return REQUIRED_HITS
	return clampi(int(GameState.get_flag(_hits_flag_key(), REQUIRED_HITS)), 0, REQUIRED_HITS)

func _save_hits_remaining() -> void:
	if blocker_id != "":
		GameState.set_flag(_hits_flag_key(), _hits_remaining)

func get_chops_remaining() -> int:
	return _hits_remaining

func _update_prompt_text() -> void:
	if prompt != null and not _cleared:
		prompt.text = "[E] Chặt (%d)" % _hits_remaining


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
	_update_prompt_text()
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
