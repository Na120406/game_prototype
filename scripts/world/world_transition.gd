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
	# Chặn toàn bộ input E (và mọi input khác) khi đang trong cutscene intro.
	# Cutscene intro Day 1: player không được tự bật dialogue bằng E cho tới khi
	# cutscene auto-walk hoàn tất. Sau đó cutscene chuyển sang WAITING_DIALOGUE,
	# cho phép E để next dialogue line.
	if GameState.cinematic_intro_state == GameState.CINEMATIC_WALKING_TO_NPC:
		return  # Không làm gì cả, chặn hoàn toàn input E

	# Portal tự check Input E để đổi scene (giữ behavior gốc — player có thể
	# vẫn trigger scene change ngay cả khi cutscene/vẫn giữ chân player).
	# Tuy nhiên, TRƯỚC KHI đổi scene, set GameState.pending_portal_interaction
	# = true để Player._interact() biết mà SKIP _try_use_active_consumable()
	# ở frame đó — tránh bug "cầm consumable đứng cạnh cửa ấn E thì cả
	# consume lẫn portal cùng chạy".
	if _player_inside and Input.is_action_just_pressed("interact"):
		GameState.pending_portal_interaction = true
		_change_scene()


func _change_scene() -> void:
	if target_scene == "":
		return
	SceneManager.change_scene(target_scene, portal_id)


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