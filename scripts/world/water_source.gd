extends Area2D
class_name WaterSource
## =============================================================================
## WATER SOURCE — Nguồn nước để refill Watering Can
## =============================================================================
## Interactive object đặt trên Farm (ví dụ: Well) cho phép player refill
## Watering Can capacity về max. Chỉ hiện prompt khi player gần và có
## water_can trong hotbar.
## =============================================================================

@export var interaction_priority: int = 10
@export var prompt_offset_y: float = -40.0

const REFILL_ENERGY_COST: float = 3.0

var prompt: Label = null
var _player: Node = null
var _player_nearby: bool = false
var _selected_water_can: bool = false

signal water_refilled()

func _ready() -> void:
	add_to_group("water_source")
	_ensure_prompt_label()
	prompt.visible = false
	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		_player = _find_player_in_tree()
	if not GameState.inventory_changed.is_connected(_on_inventory_changed):
		GameState.inventory_changed.connect(_on_inventory_changed)
	if not GameState.toolbar_changed.is_connected(_on_inventory_changed):
		GameState.toolbar_changed.connect(_on_inventory_changed)
	refresh_interaction_state()

func _exit_tree() -> void:
	if GameState.inventory_changed.is_connected(_on_inventory_changed):
		GameState.inventory_changed.disconnect(_on_inventory_changed)
	if GameState.toolbar_changed.is_connected(_on_inventory_changed):
		GameState.toolbar_changed.disconnect(_on_inventory_changed)

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

	prompt.text = "[E] Đổ nước"
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
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		return false
	var dist := global_position.distance_to(_player.global_position)
	return dist <= 60.0

func _process(_delta: float) -> void:
	if GameState.player_movement_locked or GameState.cinematic_intro_state != GameState.CINEMATIC_NONE or DialogueManager.is_active:
		return
	
	var nearby := is_player_nearby()
	var selected_water_can := _is_selected_water_can()
	if nearby != _player_nearby or selected_water_can != _selected_water_can:
		_player_nearby = nearby
		_selected_water_can = selected_water_can
		refresh_interaction_state()

func _on_inventory_changed() -> void:
	refresh_interaction_state()

## Đồng bộ prompt và target tương tác khi inventory thay đổi trong vùng.
func refresh_interaction_state() -> void:
	var can_interact: bool = _player_nearby and _is_selected_water_can()
	if prompt != null:
		prompt.visible = can_interact
	_register_with_manager(can_interact)

## Gọi bởi InteractionPromptManager hoặc portal system khi player bấm [E]
func interact(_player_ref: Node) -> void:
	if GameState.player_movement_locked or GameState.cinematic_intro_state != GameState.CINEMATIC_NONE or DialogueManager.is_active:
		return
	
	if not _is_selected_water_can():
		_show_feedback("Hãy chọn Bình Tưới Nước trên hotbar!")
		return
	
	var current_level: int = GameState.get_watering_can_level()
	var max_capacity: int = GameState.get_watering_can_max_capacity()
	
	if current_level >= max_capacity:
		_show_feedback("Bình nước đã đầy!")
		return
	var energy_manager: Node = get_tree().root.get_node_or_null("EnergyManager") if get_tree() != null else null
	if energy_manager != null and energy_manager.has_method("spend_energy"):
		if not energy_manager.call("spend_energy", REFILL_ENERGY_COST):
			return
	
	GameState.refill_watering_can()
	_show_feedback("Đã đổ đầy bình nước! (%d/%d)" % [max_capacity, max_capacity])
	water_refilled.emit()

func _is_selected_water_can() -> bool:
	return GameState.check_selected_hotbar_item("water_can", 1)

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
