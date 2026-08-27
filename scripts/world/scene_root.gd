extends Node
class_name SceneRoot
# =============================================================================
# SCENE ROOT — Generic component gắn vào mọi map/world scene.
# =============================================================================
# Vai trò:
#   - Chuẩn hóa spawn position khi F5 playtest trực tiếp scene này.
#   - Cho phép các scene designer tự quyết vị trí spawn bằng Marker2D "PlayerSpawn"
#     (hoặc bất kỳ Node2D nào trong group "player_spawn") mà không cần đụng code.
#   - Không xung đột với SceneManager: chỉ chạy khi SceneManager chưa xử lý
#     (i.e. player chưa bị force_position trước đó trong frame này).
#
# Cách dùng:
#   1. Thêm Node này làm child của root scene (đặt tên "SceneRoot" cho dễ tìm).
#   2. Thêm Marker2D tên "PlayerSpawn" (hoặc Node2D trong group "player_spawn")
#      đặt tại vị trí muốn player spawn khi F5.
#   3. (Tùy chọn) đổi default_spawn_name để dùng tên marker khác.
# =============================================================================

@export var default_spawn_name: String = "PlayerSpawn"

func _ready() -> void:
	add_to_group("scene_root")
	# Đợi 1 frame để player instance kịp tồn tại trong scene mới (đặc biệt khi F5).
	call_deferred("_ensure_player_at_default")


func _ensure_player_at_default() -> void:
	var tree := get_tree()
	if tree == null:
		return

	# Nếu SceneManager đã xử lý spawn (đã gọi player.force_position),
	# ta KHÔNG ghi đè vị trí vừa được set. Cờ `_player_has_moved` ban đầu
	# false → capture không chạy ở lần chuyển kế tiếp khi chưa di chuyển thật.
	# Để phát hiện "SceneManager đã spawn", ta kiểm tra: nếu player có pos KHÁC
	# pos default (Vector2.ZERO lúc instance) thì SceneManager đã chạm vào.
	# An toàn hơn: đọc cờ `last_change_was_portal` từ SceneManager — nếu false
	# và player có saved pos, SceneManager đã spawn.
	var sm := _get_scene_manager()
	if sm != null and sm.get("_is_via_portal") == true:
		# Đang chuyển scene qua portal → SceneManager lo. KHÔNG override.
		return
	var player := tree.get_first_node_in_group("player")
	if player == null or not player.has_method("force_position"):
		return
	if player == null or not player.has_method("force_position"):
		return

	# Tìm Marker2D hoặc Node2D trong group "player_spawn"
	var marker := find_child(default_spawn_name, true, false)
	if marker == null:
		for child in find_children("*", "Node2D", true, false):
			if child.is_in_group("player_spawn"):
				marker = child
				break

	if marker != null and marker is Node2D:
		player.force_position((marker as Node2D).global_position)
		print("[SceneRoot] Spawned player at PlayerSpawn marker: %s" % str((marker as Node2D).global_position))


func _get_scene_manager() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("SceneManager")