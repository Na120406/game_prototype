extends CharacterBody2D

signal direction_changed(new_dir: Vector2)
signal state_changed(new_state: String, old_state: String)

enum State { IDLE, WALKING, RUNNING, SPRINTING, INTERACTING, SLEEPING, DEAD }
enum Direction { DOWN, UP, LEFT, RIGHT }

@export var move_speed: float = 100.0
@export var run_speed: float = 180.0
@export var sprint_speed: float = 250.0
@export var acceleration: float = 800.0
@export var friction: float = 1200.0
@export var interaction_range: float = 80.0

var current_state: State = State.IDLE
var current_direction: Direction = Direction.DOWN
var facing_dir: Vector2 = Vector2.DOWN

var _is_moving: bool = false
var _is_running: bool = false
var _is_sprinting: bool = false

var _current_interact_target: Node = null
var _last_position: Vector2 = Vector2.ZERO
var _current_anim: String = ""

@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var interaction_ray: RayCast2D = $InteractionRay
@onready var footstep_timer: Timer = $FootstepTimer

# Phạt khi quá giờ đi ngủ (24:00) mà vẫn chưa ngủ — không phụ thuộc vào việc
# player có đang di chuyển hay không. Áp dụng như nhau cho mọi trạng thái.
const SLEEP_DEADLINE_HOUR: float = 24.0   # quá nửa đêm là quá giờ
const WARNING_HOUR: float = 24.0          # hiện cảnh báo "Đã muộn rồi!" khi tới mốc này
var _sleep_warning_shown_today: bool = false
var _last_day_warning_state: int = -1
var _sleep_deadline_triggered: bool = false
var _floating_warning: Node = null

func _ready() -> void:
	add_to_group("player")
	GameState.set_flag("player_spawned")
	_set_state(State.IDLE)
	DialogueManager.dialogue_closed.connect(_on_dialogue_closed)
	print("[Player] Ready at position: %s" % str(position))

func _physics_process(delta: float) -> void:
	if current_state == State.SLEEPING or current_state == State.DEAD:
		velocity = Vector2.ZERO
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
	# Reset trạng thái cảnh báo khi sang ngày mới.
	if _last_day_warning_state != GameState.current_day:
		_last_day_warning_state = GameState.current_day
		_sleep_warning_shown_today = false
		_sleep_deadline_triggered = false

	# Khi đạt 24:00 và chưa ngủ → hiện cảnh báo (1 lần/ngày).
	if not _sleep_warning_shown_today and GameState.current_time >= WARNING_HOUR:
		_sleep_warning_shown_today = true
		var fw := _get_floating_warning()
		if fw != null:
			fw.call("show_text", "Đã muộn rồi! Cần đi ngủ, nếu không sắp bị phạt.")
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
	if event.is_action_pressed("interact"):
		if current_state == State.INTERACTING:
			return
		if DialogueManager.is_active:
			return
		_interact()

	if event.is_action_pressed("ui_cancel"):
		if current_state == State.INTERACTING:
			_exit_interaction()

func _interact() -> void:
	if current_state == State.SLEEPING or current_state == State.DEAD:
		return

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
				_current_interact_target = collider
				collider.interact(self)

	# Fallback: check proximity for interactables
	if _current_interact_target == null:
		var apple: Node = _find_nearby_item()
		if apple != null:
			_current_interact_target = apple
			apple.interact(self)

	if _current_interact_target == null:
		var bed: Node = _find_nearby_bed()
		if bed != null and bed.has_method("is_player_nearby") and bed.is_player_nearby():
			bed.interact(self)
			_current_interact_target = bed

	if _current_interact_target == null:
		var npc: Node = _find_nearby_npc()
		if npc != null:
			npc.interact(self)
			_current_interact_target = npc

	if _current_interact_target == null:
		var counter: Node = _find_nearby_counter()
		if counter != null:
			counter.interact(self)
			_current_interact_target = counter

	if _current_interact_target == null:
		# Không có interactable nào → dùng CONSUMABLE ở slot đang select
		# (táo hồi energy, bình máu hồi health). Nếu item đang select là
		# TOOL/SEED thì E không có tác dụng (dùng TOOL/SEED phải click chuột).
		var consumed: bool = _try_use_active_consumable()
		if not consumed:
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

func _find_nearby_bed() -> Node:
	var world: Node = get_parent()
	if world == null:
		return null
	return world.find_child("Bed", true, false)

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
