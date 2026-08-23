extends Node
# =============================================================================
# HOTKEY INPUT MANAGER (Autoload)
# =============================================================================
# Quản lý input mapping giữa player action và toolbar item.
#
# QUY TẮC:
# - Phím 1-5 CHỈ select slot (highlight) — KHÔNG tự động dùng item.
#   Việc dùng item là tách biệt:
#     * Click phải (mouse right) trong farm zone → TOOL/SEED (farm_plot).
#     * Click phải NGOÀI farm zone → dùng CONSUMABLE đang select.
#     * Phím E → ưu tiên interactable gần (player._interact); nếu không
#       có thì dùng CONSUMABLE đang select (cùng mục đích như click phải).
#     * TOOL/SEED KHÔNG dùng được qua phím E — chỉ dùng qua click chuột.
# - Khi có UI/popup đang mở (Inventory / Shop / Sleep prompt / Dialogue /
#   Pause), toàn bộ input chọn/dùng item bị chặn.
# - Di chuyển WASD không xử lý ở đây — player.gd tự block dựa trên
#   DialogueManager.is_active, GameState.game_interacting, State.SLEEPING.
# =============================================================================

const TOOLBAR_ACTIONS: Array[String] = [
	"toolbar_slot_1",
	"toolbar_slot_2",
	"toolbar_slot_3",
	"toolbar_slot_4",
	"toolbar_slot_5",
]

func _ready() -> void:
	# PROCESS_MODE_ALWAYS để _unhandled_input chạy kể cả khi tree paused (UI popup).
	# Tuy nhiên ta chỉ dùng event để đánh dấu "đã xử lý", không thực sự dùng item
	# trong khi UI đang mở — đảm bảo rule trên.
	process_mode = Node.PROCESS_MODE_ALWAYS

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return

	# Phát hiện UI/popup đang mở → chặn hoàn toàn
	if _is_blocking_popup_open():
		# Nếu player vô tình nhấn 1-5 / E / click chuột trong khi UI mở → nuốt
		# event để không rơi vào logic khác. Tuy nhiên vẫn cho phép event tiếp
		# tục tới UI đang focus — nên KHÔNG set_input_as_handled ở đây.
		return

	if GameState.is_sleeping:
		return

	# Phím 1-5: CHỈ chọn slot (highlight), KHÔNG tự động dùng item.
	for i: int in range(TOOLBAR_ACTIONS.size()):
		if event.is_action_pressed(TOOLBAR_ACTIONS[i]):
			var hotbar: Node = get_tree().get_first_node_in_group("hotbar")
			if hotbar != null and hotbar.has_method("set_active_slot"):
				hotbar.set_active_slot(i)
			# KHÔNG gọi _activate_toolbar_slot(i) nữa — chỉ select.
			get_viewport().set_input_as_handled()
			return

	# Mouse right → dùng CONSUMABLE đang select (NGOÀI farm zone).
	# Trong farm zone, farm_plot._input đã handle TOOL/SEED qua mouse right;
	# nếu item_type là CONSUMABLE thì _try_farm_action silent fail → event
	# tiếp tục xuống _unhandled_input → dùng CONSUMABLE như thường.
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			if _try_use_active_consumable():
				get_viewport().set_input_as_handled()
				return

# =============================================================================
# POPUP DETECTION
# =============================================================================

func _is_blocking_popup_open() -> bool:
	# Inventory UI
	var inv: CanvasLayer = get_tree().get_first_node_in_group("inventory_ui")
	if inv != null and inv.visible:
		return true
	# Shop UI
	var shop: CanvasLayer = get_tree().get_first_node_in_group("shop_ui")
	if shop != null and shop.visible:
		return true
	# Dialogue
	if DialogueManager != null and DialogueManager.is_active:
		return true
	# Pause
	if GameState.is_paused:
		return true
	# Sleep prompt (find by class_name nếu có group, fallback to class lookup)
	var sleep_nodes := get_tree().get_nodes_in_group("sleep_prompt")
	for n: Node in sleep_nodes:
		if n is Control and (n as Control).visible:
			return true
	# Fallback: detect qua tree nếu không có group
	var fallback := get_node_or_null("/root/Main/SleepPrompt")
	if fallback != null and fallback is Control and (fallback as Control).visible:
		return true
	return false

# =============================================================================
# CONSUMABLE USAGE
# =============================================================================

# Thử dùng CONSUMABLE ở toolbar slot đang active.
# Trả về true nếu đã dùng (slot có consumable).
# Trả về false nếu slot rỗng / không phải consumable (để caller xử lý tiếp).
func _try_use_active_consumable() -> bool:
	if GameState.game_interacting:
		return false
	var hotbar: Node = get_tree().get_first_node_in_group("hotbar")
	if hotbar == null:
		return false
	var active_idx: int = hotbar.get_active_slot()
	if active_idx < 0 or active_idx >= GameState.toolbar.size():
		return false
	var slot: Dictionary = GameState.toolbar[active_idx]
	if slot.get("id", "") == "":
		return false
	var db = get_node_or_null("/root/ItemDB")
	if db == null:
		return false
	var data: ItemData = db.get_item(slot.get("id", ""))
	if data == null or data.item_type != ItemData.Type.CONSUMABLE:
		return false
	if ItemHandler != null and ItemHandler.has_method("use_toolbar_slot"):
		return ItemHandler.use_toolbar_slot(active_idx)
	return false