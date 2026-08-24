extends Area2D
# =============================================================================
# QUEST BOARD (Bảng nhiệm vụ)
# =============================================================================
# Area2D trong world — khi player vào vùng + nhấn E → mở UI popup hiển thị
# quest available hôm nay. Player có thể Accept quest (chỉ 1 quest / NPC / ngày
# từ pool).
#
# Workflow:
#   1. Player E + QuestBoard → spawn UI (CanvasLayer)
#   2. UI liệt kê `get_quests_for_board(quest_giver_npc_id)`
#   3. Player nhấn Accept → QuestSystem.accept_quest() + đóng UI
# =============================================================================

@export var board_id: String = "neighbor_board"
@export var quest_giver_npc_id: String = "neighbor"

var _player_inside: bool = false
var _current_ui: Node = null

func _ready() -> void:
	add_to_group("quest_board")
	add_to_group("quest_board_" + board_id)
	# Tương tự portal/world_transition: body_entered/exit để check player.
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(_delta: float) -> void:
	if _player_inside and Input.is_action_just_pressed("interact"):
		_toggle_ui()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_inside = false
		_close_ui()

# Mở UI nếu chưa mở, đóng nếu đã mở (toggle).
func _toggle_ui() -> void:
	if _current_ui != null and is_instance_valid(_current_ui):
		_close_ui()
		return
	_open_ui()

func _open_ui() -> void:
	# Tạo UI popup runtime (tránh phụ thuộc .tscn cho đơn giản). UI là CanvasLayer
	# add vào root để tồn tại xuyên scene change.
	var ui_scene := load("res://scenes/world/quest_board_ui.tscn") as PackedScene
	if ui_scene == null:
		push_error("[QuestBoard] Cannot load quest_board_ui.tscn")
		return
	_current_ui = ui_scene.instantiate()
	_current_ui.set("board_id", board_id)
	_current_ui.set("quest_giver_npc_id", quest_giver_npc_id)
	get_tree().root.add_child(_current_ui)

func _close_ui() -> void:
	if _current_ui != null and is_instance_valid(_current_ui):
		_current_ui.queue_free()
	_current_ui = null
