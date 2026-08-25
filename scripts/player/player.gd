extends CharacterBody2D

signal direction_changed(new_dir: Vector2)
signal state_changed(new_state: String, old_state: String)
signal cinematic_walk_complete

enum State { IDLE, WALKING, RUNNING, SPRINTING, INTERACTING, SLEEPING, DEAD }
enum Direction { DOWN, UP, LEFT, RIGHT }

# Speed values (load from ConfigManager)
var move_speed: float = 100.0
var run_speed: float = 180.0
var sprint_speed: float = 250.0
var acceleration: float = 800.0
var friction: float = 1200.0
var interaction_range: float = 80.0

var current_state: State = State.IDLE
var current_direction: Direction = Direction.DOWN
var facing_dir: Vector2 = Vector2.DOWN

var _is_moving: bool = false
var _is_running: bool = false
var _is_sprinting: bool = false

var _current_interact_target: Node = null
var _last_position: Vector2 = Vector2.ZERO
var _current_anim: String = ""

# Cinematic intro target position (đi tới NPC)
var _cinematic_target_pos: Vector2 = Vector2.ZERO
var _cinematic_target_reached: bool = false

# Sleep deadline values (load from ConfigManager)
var _sleep_deadline_hour: float = 24.0
var _warning_hour: float = 22.0
var _warning_late_hour: float = 23.5
var _sleep_deadline_triggered: bool = false
var _floating_warning: Node = null

@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var interaction_ray: RayCast2D = $InteractionRay
@onready var footstep_timer: Timer = $FootstepTimer

func _ready() -> void:
	add_to_group("player")
	GameState.set_flag("player_spawned")
	_set_state(State.IDLE)
	DialogueManager.dialogue_closed.connect(_on_dialogue_closed)
	
	# Load config from ConfigManager
	_load_config_from_manager()
	
	print("[Player] Ready at position: %s" % str(position))


func _load_config_from_manager() -> void:
	var cm := _get_config_manager()
	if cm == null:
		push_warning("[Player] ConfigManager not found, using defaults")
		return
	
	move_speed = cm.get_player_move_speed()
	run_speed = cm.get_player_run_speed()
	sprint_speed = cm.get_player_sprint_speed()
	acceleration = cm.get_player_acceleration()
	friction = cm.get_player_friction()
	interaction_range = cm.get_player_interaction_range()
	
	_sleep_deadline_hour = cm.get_sleep_deadline_hour()
	_warning_hour = cm.get_sleep_warning_hour()
	
	print("[Player] Loaded player config from ConfigManager")


func _get_config_manager() -> Node:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("ConfigManager")

func _physics_process(delta: float) -> void:
	if current_state == State.SLEEPING or current_state == State.DEAD:
		velocity = Vector2.ZERO
		return

	# Lock movement khi đang cutscene/dialogue đặc biệt (nhưng cho phép đi tự động trong cinematic intro)
	if GameState.player_movement_locked and GameState.cinematic_intro_state == GameState.CINEMATIC_NONE:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		move_and_slide()
		return

	# Xử lý cinematic intro - cho phép di chuyển tự động tới vị trí NPC
	if GameState.cinematic_intro_state == GameState.CINEMATIC_WALKING_TO_NPC:
		_handle_cinematic_walk(delta)
		move_and_slide()
		return

	if DialogueManager.is_active or GameState.game_interacting:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		move_and_slide()
		return

	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_is_moving = input_dir.length() > 0.1
	_is_running = Input.is_action_pressed("ui_focus_next")
	_is_sprinting = Input.is_action_pressed("ui_cancel") and GameState.energy > 10.0

	if _is_moving:
		_update_direction(input_dir)

		var target_speed: float = move_speed * GameState.move_speed_mult
		if _is_sprinting:
			target_speed = sprint_speed * GameState.move_speed_mult
		elif _is_running:
			target_speed = run_speed * GameState.move_speed_mult

		var target_velocity := input_dir * target_speed
		velocity = velocity.move_toward(target_velocity, acceleration * delta)

		var moving_state: State = State.WALKING
		if _is_sprinting:
			moving_state = State.SPRINTING
		elif _is_running:
			moving_state = State.RUNNING
		_set_state(moving_state)
		_update_animation(input_dir)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		if velocity.length() < 1.0:
			velocity = Vector2.ZERO
			_set_state(State.IDLE)
			_update_animation(Vector2.ZERO)

	# Năng lượng KHÔNG tiêu hao khi chạy/sprint — chỉ tiêu hao khi dùng
	# hoe/water can tương tác với đất (xem farm_plot.gd _try_farm_action).
	# if _is_moving and (_is_running or _is_sprinting):
	# 	GameState.modify_energy(-delta * GameState.stamina_drain_rate * 0.3)

	move_and_slide()

	# Phạt khi quá giờ đi ngủ — áp dụng cho mọi trạng thái (đứng yên, đi, chạy…)
	_check_sleep_deadline()

# Xử lý di chuyển tự động trong cinematic intro (đi tới NPC)
func _handle_cinematic_walk(delta: float) -> void:
	if _cinematic_target_reached:
		return

	# Tính hướng tới target
	var dir := (_cinematic_target_pos - global_position)
	var dist := dir.length()

	# Nếu đã đến gần đủ thì dừng lại
	if dist < 5.0:
		_cinematic_target_reached = true
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		_set_state(State.IDLE)
		_update_animation(Vector2.ZERO)
		cinematic_walk_complete.emit()
		return

	# Normalize direction
	dir = dir.normalized()

	# Di chuyển với tốc độ bình thường
	var target_speed: float = move_speed * GameState.move_speed_mult
	var target_velocity := dir * target_speed
	velocity = velocity.move_toward(target_velocity, acceleration * delta)

	# Cập nhật animation
	_update_animation(dir)
	_set_state(State.WALKING)

# Bắt đầu cinematic intro - đi tới vị trí NPC
func start_cinematic_intro(target_pos: Vector2) -> void:
	print("[Player] Starting cinematic intro to: %s" % str(target_pos))
	_cinematic_target_pos = target_pos
	_cinematic_target_reached = false
	GameState.cinematic_intro_state = GameState.CINEMATIC_WALKING_TO_NPC

# Hủy cinematic intro
func cancel_cinematic_intro() -> void:
	_cinematic_target_reached = true
	GameState.cinematic_intro_state = GameState.CINEMATIC_NONE
	velocity = velocity.move_toward(Vector2.ZERO, friction * 0.016)
	_set_state(State.IDLE)

func _update_direction(dir: Vector2) -> void:
	var new_dir: Direction = current_direction

	if absf(dir.x) > absf(dir.y):
		if dir.x > 0:
			new_dir = Direction.RIGHT
			facing_dir = Vector2.RIGHT
		else:
			new_dir = Direction.LEFT
			facing_dir = Vector2.LEFT
	else:
		if dir.y > 0:
			new_dir = Direction.DOWN
			facing_dir = Vector2.DOWN
		else:
			new_dir = Direction.UP
			facing_dir = Vector2.UP

	if new_dir != current_direction:
		current_direction = new_dir
		direction_changed.emit(facing_dir)
		_update_sprite_flip()

func _update_animation(dir: Vector2) -> void:
	if animation_player == null:
		return

	var anim_name: String = _get_animation_name(dir)
	if anim_name != _current_anim:
		_current_anim = anim_name
		if animation_player.has_animation(anim_name):
			animation_player.play(anim_name)
		else:
			animation_player.play("idle")

func _update_sprite_flip() -> void:
	if sprite == null or not is_instance_valid(sprite):
		return
	match current_direction:
		Direction.LEFT:
			sprite.flip_h = true
		Direction.RIGHT:
			sprite.flip_h = false

func _check_sleep_deadline() -> void:
	# Flag `sleep_warning_shown_for_day` được lưu trong GameState (autoload)
	# nên PERSISTENT qua scene changes — không bị reset khi Player bị
	# queue_free khi chuyển scene. Cờ tự reset khi current_day đổi (lúc 6:00
	# hoặc khi player ngủ tại giường) vì ta so sánh với `current_day`.

	# Cảnh báo 23:30 - "zzZZ" (ngủ rất muộn)
	if GameState.sleep_late_2330_warning_shown_for_day != GameState.current_day:
		if GameState.current_time >= _warning_late_hour:
			GameState.sleep_late_2330_warning_shown_for_day = GameState.current_day
			var fw := _get_floating_warning()
			if fw != null:
				fw.call("show_text_plain_for", "zzZZ", 1.5)
			print("[Player] Very late sleep warning at hour %.1f" % GameState.current_time)

	# Cảnh báo 22:00 - "It's late"
	if GameState.sleep_warning_shown_for_day == GameState.current_day:
		return # đã hiện warning cho ngày này rồi

	if GameState.current_time < _warning_hour:
		return

	# Khi đạt 22:00 và chưa ngủ → hiện cảnh báo (1 lần/ngày). Text trắng,
	# cỡ 8, KHÔNG outline/tint, sát trên đầu player, tổng thời gian hiện 1.5s.
	GameState.sleep_warning_shown_for_day = GameState.current_day
	var fw := _get_floating_warning()
	if fw != null:
		fw.call("show_text_plain_for", "It's late", 1.5)
	print("[Player] Sleep deadline warning at hour %.1f" % GameState.current_time)

	# Sau khi TimeManager gọi advance_day(), current_time được reset về 6.0
	# và current_day tăng lên → trigger knock-out bằng energy manager hoặc
	# penalty riêng. Ở đây ta chỉ chịu trách nhiệm CẢNH BÁO; phạt (giảm tốc độ
	# + qua ngày) đã được xử lý ở TimeManager._process thông qua
	# EnergyManager.trigger_knock_out() nếu player chưa về giường.

func _get_animation_name(dir: Vector2) -> String:
	var base: String = "idle"
	if _is_moving:
		if _is_sprinting:
			base = "sprint"
		elif _is_running:
			base = "run"
		else:
			base = "walk"

	match current_direction:
		Direction.DOWN: return base
		Direction.UP: return base + "_up"
		Direction.LEFT: return base
		Direction.RIGHT: return base
	return base

func _set_state(new_state: State) -> void:
	if new_state == current_state:
		return
	var old_state_str: String = State.keys()[current_state]
	current_state = new_state
	state_changed.emit(State.keys()[new_state], old_state_str)

func _unhandled_input(event: InputEvent) -> void:
	# E chỉ dùng cho dialogue next trong cinematic intro
	if GameState.cinematic_intro_state == GameState.CINEMATIC_WAITING_DIALOGUE:
		if event.is_action_pressed("interact"):
			return  # Chặn E, dialogue tự xử lý

	if event.is_action_pressed("interact"):
		if current_state == State.INTERACTING:
			return
		if DialogueManager.is_active:
			return
		# Chặn E khi đang trong cinematic intro (đang chờ dialogue)
		if GameState.cinematic_intro_state == GameState.CINEMATIC_WAITING_DIALOGUE:
			return
		# E chỉ để portal tự xử lý ở world_transition.gd._process (đã có flag
		# pending_portal_interaction để tránh double-handle). Player không gọi
		# _interact() cho E nữa — _interact() phục vụ NPC/counter/apple/bed,
		# và bây giờ cũng bỏ luôn fallback consumable (consumable dùng chuột
		# phải để tách khỏi portal — tránh bug "đứng cạnh cửa ấn E thì cả
		# portal đổi scene lẫn consumable bị consume cùng lúc").
		if not _is_ui_blocking_movement():
			_interact()

	# Chuột phải → dùng item đang select. Tùy theo item mà handler phù hợp
	# chạy:
	#   - TOOL/SEED: farm_plot._input xử lý (plow/water/plant/harvest) trong
	#     farm zone. Nếu click NGOÀI farm zone → tool/seed không có tác dụng,
	#     Player bỏ qua (không cần phản hồi gì).
	#   - CONSUMABLE: Player tự xử lý ở đây (dùng được mọi nơi, kể cả khi
	#     inventory đang đóng hay đang mở — chỉ block khi UI lớn đang che:
	#     shop/dialogue/sleep). Khi inventory đang mở mà click phải vào ô
	#     inventory có CONSUMABLE → inventory UI bắt riêng để hiện context
	#     menu "Use" (giữ behavior cũ cho UX trong inventory).
	#   - Ô trống / item không xác định: bỏ qua.
	# Tách biệt hoàn toàn với E (portal) và chuột trái (show-info/harvest)
	# nên không xung đột 3 loại input.
	if event.is_action_pressed("mouse_right"):
		if current_state == State.SLEEPING or current_state == State.DEAD:
			return
		if DialogueManager.is_active:
			return
		# Chặn khi đang trong cinematic intro
		if GameState.cinematic_intro_state != GameState.CINEMATIC_NONE:
			return
		# Block khi shop/sleep-prompt đang che. KHÔNG block vì inventory —
		# inventory mở vẫn cho phép consum item hotbar active nếu click phải
		# ngoài vùng context menu (inventory chỉ xử lý nếu click trúng ô có
		# CONSUMABLE để hiện nút Use).
		if _is_modal_ui_blocking():
			return
		# Nếu click phải trúng ô inventory có CONSUMABLE → inventory UI đã
		# (hoặc sẽ) bắt event để hiện context menu. Để tránh consume đúp cùng
		# frame, ta bỏ qua ở đây khi inventory đang mở. Các vùng khác của UI
		# inventory (grid trống, title, panel background) → vẫn cho Player xử
		# lý để consume item hotbar active.
		if _is_mouse_over_inventory_consumable_slot():
			return
		_try_use_active_consumable()

	if event.is_action_pressed("ui_cancel"):
		if current_state == State.INTERACTING:
			_exit_interaction()

func _interact() -> void:
	if current_state == State.SLEEPING or current_state == State.DEAD:
		return

	# Reset cờ pending_portal_interaction nếu có (phòng trường hợp portal
	# set flag ở frame này nhưng Player được gọi _interact() bởi E — tuy giờ
	# E không còn trigger consume ở Player, nhưng các interactable khác
	# (npc/counter/apple/bed) vẫn chạy qua đây, nên reset cho sạch).
	GameState.pending_portal_interaction = false

	_set_state(State.INTERACTING)
	_current_interact_target = null

	# Lưu lại trạng thái game_interacting trước khi tương tác để restore
	# sau khi action one-shot kết thúc (pickup apple, mở scene transition,
	# examine object). Đây là các action không nên block di chuyển player.
	var prev_game_interacting: bool = GameState.game_interacting

	# Try raycast first
	if interaction_ray != null:
		interaction_ray.target_position = facing_dir * interaction_range
		interaction_ray.force_raycast_update()
		if interaction_ray.is_colliding():
			var collider: Object = interaction_ray.get_collider()
			if collider.has_method("interact"):
				# Gán target TRƯỚC khi gọi interact() để các khối fallback
				# bị skip. Nếu collider.interact() trigger change_scene (portal)
				# hoặc mở UI/dialogue, scene/UI tự set game_interacting và clear.
				_current_interact_target = collider
				collider.interact(self)

	# Fallback: check proximity for interactables (kiểm tra theo thứ tự ưu tiên
	# giảm dần).
	# Thứ tự: apple → bed → npc → counter → consumable (cuối cùng).
	# PORTAL KHÔNG ở đây: portal Area2D tự xử lý E qua _process (giữ behavior
	# cũ) và set GameState.pending_portal_interaction = true trước khi đổi
	# scene → Player skip consume ở cuối hàm (xem check `portal_will_handle`).
	# Logic: assign target TRƯỚC khi gọi interact() để các khối sau bị skip.
	if _current_interact_target == null:
		var apple: Node = _find_nearby_item()
		if apple != null:
			_current_interact_target = apple
			apple.interact(self)

	if _current_interact_target == null:
		var bed: Node = _find_nearby_bed()
		if bed != null and bed.has_method("is_player_nearby") and bed.is_player_nearby():
			_current_interact_target = bed
			bed.interact(self)

	if _current_interact_target == null:
		var npc: Node = _find_nearby_npc()
		if npc != null and npc.has_method("interact"):
			_current_interact_target = npc
			npc.interact(self)

	if _current_interact_target == null:
		var counter: Node = _find_nearby_counter()
		if counter != null and counter.has_method("interact"):
			_current_interact_target = counter
			counter.interact(self)

	if _current_interact_target == null:
		# KHÔNG fallback consumable ở đây — consumable giờ dùng riêng chuột
		# phải (mouse_right) để tách khỏi E (portal) và chuột trái (farm plot).
		# Nếu E được nhấn mà không có apple/bed/npc/counter nào gần → idle,
		# tránh những consume ngoài ý muốn khi player chỉ muốn mở cửa.
		_set_state(State.IDLE)

	# Restore game_interacting về giá trị ban đầu sau one-shot actions.
	# Đây là lý do trước đây player bị "đứng im" sau khi nhặt táo bằng E:
	# apple.interact() chỉ queue_free() mà không mở UI/dialogue nào, nên
	# game_interacting cần được trả về false ngay sau khi action kết thúc.
	# Các tương tác KHÁC (shop, dialogue, sleep, scene change) tự set
	# game_interacting = true/false ở script của chúng khi mở/đóng UI.
	# Nếu một UI đang mở → giữ game_interacting=true (UI đó tự clear khi đóng).
	if not _is_ui_blocking_movement():
		GameState.game_interacting = prev_game_interacting
		_set_state(State.IDLE)
		_current_interact_target = null

# Thử dùng CONSUMABLE ở toolbar slot đang active.
# Trả về true nếu đã consume (kể cả khi không hồi được energy/health do đầy),
# false nếu slot rỗng / không phải consumable.
func _try_use_active_consumable() -> bool:
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

# Trả về true nếu có UI đang giữ player (shop/dialogue/sleep/pause).
# Khi UI mở, player KHÔNG được restore state về IDLE — UI tự clear
# game_interacting = false khi đóng. Đây là cách tránh "đứng im" sau
# khi nhặt táo bằng E (pickup one-shot) mà vẫn giữ chặn đúng khi
# tương tác mở UI (counter/shop, bed/sleep, npc/dialogue).
func _is_ui_blocking_movement() -> bool:
	if DialogueManager != null and DialogueManager.is_active:
		return true
	var shop: CanvasLayer = get_tree().get_first_node_in_group("shop_ui")
	if shop != null and shop.visible:
		return true
	var sleep_nodes := get_tree().get_nodes_in_group("sleep_prompt")
	for n: Node in sleep_nodes:
		if n is Control and (n as Control).visible:
			return true
	if GameState.is_paused:
		return true
	return false

# Kiểm tra có UI modal đang che không (shop/sleep/dialogue/pause). Tách từ
# _is_ui_blocking_movement ra để chuột phải vẫn consume được consumable khi
# inventory đang mở — inventory không phải modal, chỉ pause gameplay.
func _is_modal_ui_blocking() -> bool:
	if DialogueManager != null and DialogueManager.is_active:
		return true
	var shop: CanvasLayer = get_tree().get_first_node_in_group("shop_ui")
	if shop != null and shop.visible:
		return true
	var sleep_nodes := get_tree().get_nodes_in_group("sleep_prompt")
	for n: Node in sleep_nodes:
		if n is Control and (n as Control).visible:
			return true
	return false

# Trả về true nếu chuột đang nằm trên 1 ô inventory có CONSUMABLE — để
# Player bỏ qua và để inventory_ui xử lý context menu "Use". Khi click ra
# ngoài các ô đó (panel background, hotbar, world) → Player consume item
# hotbar active bình thường.
func _is_mouse_over_inventory_consumable_slot() -> bool:
	var inv: CanvasLayer = get_tree().get_first_node_in_group("inventory_ui")
	if inv == null or not inv.visible:
		return false
	var mp: Vector2 = get_viewport().get_mouse_position()
	# Hotbar nằm dưới inventory; click phải vào hotbar KHÔNG nên skip consume —
	# nếu skip, hotbar sẽ "nuốt" event và Player không consume được. Chỉ skip
	# khi chuột trên 1 ô inventory (không phải hotbar).
	var hotbar: Node = get_tree().get_first_node_in_group("hotbar")
	if hotbar != null:
		var slot_names := ["Slot0", "Slot1", "Slot2", "Slot3", "Slot4"]
		for i: int in range(slot_names.size()):
			var slot: Control = hotbar.get_node_or_null("SlotsContainer/" + slot_names[i]) as Control
			if slot != null and is_instance_valid(slot) and slot.get_global_rect().has_point(mp):
				return false
	# Gọi helper của inventory_ui nếu có (test nhanh có phải slot consumable).
	if inv.has_method("_is_mouse_over_consumable_slot"):
		return inv.call("_is_mouse_over_consumable_slot")
	return false

func _find_nearby_bed() -> Node:
	var world: Node = get_parent()
	if world == null:
		return null
	return world.find_child("Bed", true, false)

# (Hàm _find_nearby_portal và _collect_nodes_by_script đã bị xóa — portal
# không còn trong chuỗi fallback của Player. Portal tự xử lý E qua _process
# của Area2D world_transition.gd và set flag pending_portal_interaction để
# Player biết skip consume ở cùng frame nếu cần.)

func _find_nearby_item() -> Node:
	var world: Node = get_parent()
	if world == null:
		return null
	var apple: Node = world.find_child("Apple", true, false)
	if apple != null and apple.has_method("is_player_nearby") and apple.is_player_nearby():
		return apple
	return null

func _find_nearby_counter() -> Node:
	var world: Node = get_parent()
	if world == null:
		return null
	var counter: Node = world.find_child("Counter", true, false)
	if counter == null:
		return null

	var is_nearby_area: bool = counter.has_method("is_player_nearby") and counter.is_player_nearby()
	var dist: float = global_position.distance_to(counter.global_position)

	if is_nearby_area:
		var npcs: Array = world.get_tree().get_nodes_in_group("npc")
		for npc: Node in npcs:
			if npc.has_method("is_player_nearby") and npc.is_player_nearby():
				return null
		return counter

	if dist > interaction_range:
		return null

	var npcs: Array = world.get_tree().get_nodes_in_group("npc")
	for npc: Node in npcs:
		if npc.has_method("is_player_nearby") and npc.is_player_nearby():
			return null
	return counter

func _find_nearby_npc() -> Node:
	var world: Node = get_parent()
	if world == null:
		return null
	var npcs: Array = world.get_tree().get_nodes_in_group("npc")
	var closest: Node = null
	var closest_dist: float = INF
	for npc: Node in npcs:
		if npc.has_method("is_player_nearby") and npc.is_player_nearby():
			var dist: float = global_position.distance_to(npc.global_position)
			if dist < closest_dist:
				closest_dist = dist
				closest = npc
	if closest_dist > interaction_range:
		return null
	return closest

func _exit_interaction() -> void:
	if _current_interact_target != null:
		if _current_interact_target.has_method("on_dialogue_ended"):
			_current_interact_target.on_dialogue_ended()
		_current_interact_target = null
	GameState.game_interacting = false
	_set_state(State.IDLE)

func _on_dialogue_closed() -> void:
	_exit_interaction()

func get_facing_cell() -> Vector2i:
	var layer: TileMapLayer = get_tree().get_first_node_in_group("world_tiles")
	if layer == null:
		return Vector2i.ZERO
	return layer.local_to_map(position + facing_dir * interaction_range)

func force_position(new_pos: Vector2) -> void:
	global_position = new_pos

func show_sleep_prompt() -> void:
	pass

func on_sleep_prompt_shown() -> void:
	_set_state(State.INTERACTING)

func on_sleep_prompt_closed() -> void:
	_set_state(State.IDLE)

func set_sleeping(sleeping: bool) -> void:
	if sleeping:
		_set_state(State.SLEEPING)
		velocity = Vector2.ZERO
	else:
		_set_state(State.IDLE)

# Lazy-resolve FloatingWarning autoload. Tránh identifier chưa được parser
# nhận khi editor chưa reload project sau khi thêm autoload mới.
func _get_floating_warning() -> Node:
	if _floating_warning != null and is_instance_valid(_floating_warning):
		return _floating_warning
	var tree := get_tree()
	if tree == null:
		return null
	var node := tree.root.get_node_or_null("FloatingWarning")
	if node != null:
		_floating_warning = node
	return _floating_warning
