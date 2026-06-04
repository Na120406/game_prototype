extends CharacterBody2D

signal direction_changed(new_dir: Vector2)
signal state_changed(new_state: String, old_state: String)

enum State { IDLE, WALKING, RUNNING, INTERACTING, SLEEPING, DEAD }
enum Direction { DOWN, UP, LEFT, RIGHT }

@export var move_speed: float = 100.0
@export var run_speed: float = 180.0
@export var sprint_speed: float = 250.0
@export var acceleration: float = 800.0
@export var friction: float = 1200.0
@export var interaction_range: float = 24.0

var current_state: State = State.IDLE
var current_direction: Direction = Direction.DOWN
var facing_dir: Vector2 = Vector2.DOWN

var _is_moving: bool = false
var _is_running: bool = false
var _is_sprinting: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var interaction_ray: RayCast2D = $InteractionRay
@onready var footstep_timer: Timer = $FootstepTimer

var _last_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("player")
	GameState.set_flag("player_spawned")
	print("[Player] Ready at position: %s" % str(position))

func _physics_process(delta: float) -> void:
	if current_state == State.SLEEPING or current_state == State.DEAD:
		velocity = Vector2.ZERO
		return

	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_is_moving = input_dir.length() > 0.1
	_is_running = Input.is_action_pressed("ui_focus_next")
	_is_sprinting = Input.is_action_pressed("ui_cancel") and GameState.energy > 10.0

	if _is_moving:
		_update_direction(input_dir)

		var target_speed := move_speed
		if _is_sprinting:
			target_speed = sprint_speed
		elif _is_running:
			target_speed = run_speed

		var target_velocity := input_dir * target_speed
		velocity = velocity.move_toward(target_velocity, acceleration * delta)

		_change_state(State.WALKING if not _is_running else State.RUNNING)
		_update_animation(input_dir)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		_change_state(State.IDLE)
		_update_animation(Vector2.ZERO)

	if _is_moving and _is_running:
		GameState.drain_energy(delta * GameState.stamina_drain_rate * 0.3)

	move_and_slide()

func _update_direction(dir: Vector2) -> void:
	var new_dir: Direction = current_direction

	if abs(dir.x) > abs(dir.y):
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
		var old_dir := current_direction
		current_direction = new_dir
		direction_changed.emit(facing_dir)

func _update_animation(dir: Vector2) -> void:
	if animation_player == null or animation_player.has_node("AnimationTree"):
		return

	var anim_name := _get_animation_name(dir)
	if animation_player.has_animation(anim_name):
		if animation_player.current_animation != anim_name:
			animation_player.play(anim_name)

func _get_animation_name(dir: Vector2) -> String:
	var base := "idle"
	if _is_moving:
		base = "walk"
		if _is_sprinting:
			base = "sprint"
		elif _is_running:
			base = "run"

	var dir_suffix := ""
	match current_direction:
		Direction.DOWN: dir_suffix = "_down"
		Direction.UP: dir_suffix = "_up"
		Direction.LEFT: dir_suffix = "_left"
		Direction.RIGHT: dir_suffix = "_right"

	return base + dir_suffix

func _change_state(new_state: State) -> void:
	if new_state == current_state:
		return
	var old_state := current_state
	current_state = new_state
	state_changed.emit(State.keys()[new_state], State.keys()[old_state])

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_interact()

	if event.is_action_pressed("ui_cancel"):
		if current_state == State.INTERACTING:
			_exit_interaction()

func _interact() -> void:
	_change_state(State.INTERACTING)

	if interaction_ray != null:
		interaction_ray.target_position = facing_dir * interaction_range
		interaction_ray.force_raycast_update()

		if interaction_ray.is_colliding():
			var collider := interaction_ray.get_collider()
			if collider.has_method("interact"):
				collider.interact(self)

func _exit_interaction() -> void:
	_change_state(State.IDLE)

func get_facing_cell() -> Vector2i:
	var layer: TileMapLayer = get_tree().get_first_node_in_group("world_tiles")
	if layer == null:
		return Vector2i.ZERO
	return layer.local_to_map(position + facing_dir * interaction_range)

func force_position(new_pos: Vector2) -> void:
	global_position = new_pos
