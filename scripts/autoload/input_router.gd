extends Node
# =============================================================================
# INPUT ROUTER (Autoload)
# =============================================================================
# Bắt các phím tắt "luôn phải hoạt động" ở mọi scene, mọi trạng thái UI focus.
# Đây là autoload nên _input chạy ngay từ khi game boot — đảm bảo toggle
# inventory (TAB) hoạt động dù:
#   - InventoryUI CanvasLayer bị ẩn
#   - Packed scene chưa instantiate xong
#   - Control nào đó đang focus và nuốt focus traversal
#
# Các phím tắt hiện hỗ trợ:
#   - TAB: toggle inventory UI (toggle_inventory action)
# =============================================================================

func _input(event: InputEvent) -> void:
	# DEBUG — chỉ print cho key event
	if event is InputEventKey:
		print("[InputRouter] key event pressed=", event.pressed, " echo=", event.echo, " physkey=", event.physical_keycode, " keycode=", event.keycode)
	# Bỏ qua release/echo — chỉ quan tâm press
	if not event.is_pressed() or event.is_echo():
		return
	# TAB detection: thử qua action trước (an toàn cho mọi event type),
	# sau đó check physical_keycode/keycode nếu là InputEventKey.
	var is_tab: bool = event.is_action_pressed("toggle_inventory")
	if not is_tab and event is InputEventKey:
		var key_event: InputEventKey = event
		is_tab = key_event.physical_keycode == KEY_TAB or key_event.keycode == KEY_TAB
	if is_tab:
		print("[InputRouter] TAB detected, calling _handle_toggle_inventory")
		_handle_toggle_inventory()
		get_viewport().set_input_as_handled()
		return

func _handle_toggle_inventory() -> void:
	print("[InputRouter] _handle_toggle_inventory entered")
	# Không toggle khi đang dialogue
	if DialogueManager != null and DialogueManager.is_active:
		print("[InputRouter] blocked by DialogueManager")
		return

	var tree := get_tree()
	if tree == null:
		return

	# Tìm InventoryUI qua group (đăng ký trong _ready của InventoryUI)
	var inv: CanvasLayer = tree.get_first_node_in_group("inventory_ui") as CanvasLayer
	print("[InputRouter] found inventory_ui: ", inv)
	if inv == null:
		# Fallback: tìm qua class_name nếu không có group
		var nodes := tree.get_nodes_in_group("inventory_ui")
		if nodes.size() > 0:
			inv = nodes[0] as CanvasLayer

	if inv == null:
		push_warning("[InputRouter] InventoryUI not found in scene")
		return

	if inv.has_method("_toggle"):
		print("[InputRouter] calling _toggle, current visible=", inv.visible)
		inv.call("_toggle")
	else:
		push_warning("[InputRouter] InventoryUI has no _toggle method")
