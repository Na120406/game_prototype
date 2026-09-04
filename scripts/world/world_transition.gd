extends Area2D

@export var portal_id: String = ""
@export var target_scene: String = ""
@export var transition_type: String = "instant"
@export var prompt: String = "[E]"
@export var prompt_offset_y: float = -28.0
# Ưu tiên hiển thị khi nhiều interactable cùng gần player (cao = ưu tiên hơn)
@export var interaction_priority: int = 10
@export var metadata: PortalData = null

var _player_inside: bool = false
var _traversal_cost_applied: bool = false

var prompt_label: Label = null

func _ready() -> void:
	if metadata != null:
		if metadata.portal_id != &"":
			portal_id = String(metadata.portal_id)
		if metadata.target_scene != "":
			target_scene = metadata.target_scene
		if metadata.prompt != "":
			prompt = metadata.prompt
		interaction_priority = metadata.interaction_priority
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Đảm bảo local label (back-up nếu InteractionPromptManager chưa autoload)
	_ensure_prompt_label()
	if prompt_label != null:
		prompt_label.visible = false


# =============================================================================
# ĐẢM BẢO PROMPT LABEL TỒN TẠI + STYLE ĐẸP
# =============================================================================

func _ensure_prompt_label() -> void:
	if has_node("Prompt"):
		prompt_label = $Prompt
	else:
		prompt_label = Label.new()
		prompt_label.name = "Prompt"
		add_child(prompt_label)

	# Thuần text trắng cỡ nhỏ, đặt phía trên portal
	prompt_label.anchor_left = 0.0
	prompt_label.anchor_top = 0.0
	prompt_label.anchor_right = 0.0
	prompt_label.anchor_bottom = 0.0
	prompt_label.offset_left = -12.0
	prompt_label.offset_top = prompt_offset_y
	prompt_label.offset_right = 12.0
	prompt_label.offset_bottom = prompt_offset_y + 8.0

	prompt_label.text = prompt
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 6)
	prompt_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	prompt_label.z_index = 20


func _process(_delta: float) -> void:
	# Không cho portal nhận E trong toàn bộ intro; khi đang dialogue chỉ E/mouse
	# trái được DialogueUI xử lý, tuyệt đối không đổi scene.
	if GameState.player_movement_locked or GameState.cinematic_intro_state != GameState.CINEMATIC_NONE or DialogueManager.is_active:
		return

	# Portal tự check Input E để đổi scene. Trước khi đổi scene, set flag để
	# Player không xử lý thêm thao tác item trong cùng frame.
	if _player_inside and Input.is_action_just_pressed("interact"):
		GameState.pending_portal_interaction = true
		_change_scene()


func _change_scene() -> void:
	if target_scene == "":
		return
	if not ResourceLoader.exists(target_scene):
		push_error("[WorldTransition] Scene không tồn tại: %s" % target_scene)
		return
	if not can_traverse():
		GameState.pending_portal_interaction = false
		_show_locked_feedback()
		return
	if _traversal_cost_applied:
		return
	_traversal_cost_applied = true
	var traversal_cost: float = get_traversal_cost()
	if traversal_cost > 0.0:
		_apply_traversal_cost(traversal_cost)
	SceneManager.change_scene(target_scene, portal_id)


## Enforce gate ngay tại portal boundary. TreeBlocker vẫn giữ vai trò visual và
## collision, nhưng portal không thể bị bypass khi placeholder map cho đi vòng.
func can_traverse() -> bool:
	# Enforce the same shortcut gate from both sides.  The Town-side portal
	# used to be open unconditionally, which allowed bypassing the blocker by
	# entering the portal from the new Town map.
	if portal_id == "portal_forest_short_to_town" or portal_id == "portal_town_to_forest_short":
		return GameState.is_forest_shortcut_cleared()
	return true


func _show_locked_feedback() -> void:
	var warning: Node = get_node_or_null("/root/FloatingWarning")
	if warning != null and warning.has_method("show_text_plain"):
		var message := "đường này bị chặn rồi" if portal_id == "portal_town_to_forest_short" else "Cần vật gì đó để xử lý."
		warning.call("show_text_plain", message)


## Route cost là clock travel, không phải ngủ/knock-out. Không dùng
## GameState.advance_time() vì API đó reset ngày về 06:00 và hồi energy khi
## vượt 24:00. TimeManager giữ phần dư qua nửa đêm và tự xử lý clock boundary.
func _apply_traversal_cost(hours: float) -> void:
	var next_time: float = GameState.current_time + maxf(0.0, hours)
	var time_manager: Node = get_node_or_null("/root/TimeManager")
	if time_manager != null and time_manager.has_method("advance_clock"):
		time_manager.call("advance_clock", hours)
		return
	if time_manager != null and time_manager.has_method("set_time"):
		time_manager.call("set_time", next_time)
		return
	GameState.current_time = next_time
	var t24: float = fposmod(next_time, 24.0)
	GameState.is_day = t24 >= 6.0 and t24 < 22.0


## Thời gian di chuyển của portal. Chỉ Forest route dùng cost gameplay;
## các portal khác giữ cost bằng 0 để không thay đổi hành vi cũ.
func get_traversal_cost() -> float:
	var cm: Node = get_node_or_null("/root/ConfigManager")
	if cm == null:
		return 0.0
	if portal_id == "portal_forest_long_to_town":
		return maxf(0.0, float(cm.get_forest_long_route_time()))
	if portal_id == "portal_forest_short_to_town" or portal_id == "portal_town_to_forest_short":
		return maxf(0.0, float(cm.get_forest_shortcut_time()))
	return 0.0


# =============================================================================
# PUBLIC API — Player dùng để check proximity khi nhấn E
# =============================================================================

# Trả về true nếu player đang overlap Area2D portal này. Player._interact()
# dùng để quyết định ưu tiên portal > consumable. Đây là nguồn duy nhất
# của "Player biết portal gần", vì Area2D không thể raycast bằng RayCast2D.
func is_player_nearby() -> bool:
	return _player_inside


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = true
		add_to_group("nearby_portal")
		_register_with_manager(true)
		if prompt_label != null:
			prompt_label.text = prompt
			prompt_label.visible = true


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = false
		remove_from_group("nearby_portal")
		_register_with_manager(false)
		if prompt_label != null:
			prompt_label.visible = false


func _register_with_manager(nearby: bool) -> void:
	var mgr := _get_prompt_manager()
	if mgr == null:
		return
	if nearby:
		mgr.register_nearby(self)
	else:
		mgr.unregister_nearby(self)


func _get_prompt_manager() -> Node:
	if not is_instance_valid(self):
		return null
	var tree := get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("InteractionPromptManager")


func interact(_player: Node) -> void:
	_change_scene()


func get_portal_id() -> String:
	return portal_id
