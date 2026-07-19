# GDScript Patterns Guide

## Common GDScript Patterns for Godot 4.x

### Observer Pattern (Signals)

```gdscript
# Subject
signal health_changed(new_value: int, old_value: int)

func take_damage(amount: int) -> void:
    var old_health = _health
    _health = max(0, _health - amount)
    health_changed.emit(_health, old_health)

# Observer
func _ready() -> void:
    player.health_changed.connect(_on_health_changed)

func _on_health_changed(new_value: int, old_value: int) -> void:
    health_bar.value = new_value
```

### Factory Pattern

```gdscript
class_name EnemyFactory

static func create_enemy(type: String, position: Vector2) -> Enemy:
    match type:
        "goblin":
            return Goblin.new()
        "dragon":
            return Dragon.new()
        _:
            push_error("Unknown enemy type: " + type)
            return null

    enemy.position = position
    return enemy
```

### Object Pooling

```gdscript
class_name BulletPool
extends Node

@export var max_size: int = 100

var _pool: Array[Bullet] = []
var _active: Array[Bullet] = []

func get_bullet() -> Bullet:
    var bullet: Bullet
    if _pool.size() > 0:
        bullet = _pool.pop_back()
    else:
        bullet = Bullet.instantiate()
    
    _active.append(bullet)
    add_child(bullet)
    return bullet

func return_bullet(bullet: Bullet) -> void:
    _active.erase(bullet)
    _pool.append(bullet)
    bullet.queue_free()
```

### State Machine

```gdscript
class_name StateMachine
extends Node

@export var initial_state: State

var current_state: State

func _ready() -> void:
    for child in get_children():
        if child is State:
            child.state_machine = self
    transition_to(initial_state)

func transition_to(state: State) -> void:
    if current_state:
        current_state.exit()
    current_state = state
    current_state.enter()

func _process(delta: float) -> void:
    if current_state:
        current_state.update(delta)

# State base class
class State extends Node:
    var state_machine: StateMachine
    
    func enter() -> void: pass
    func exit() -> void: pass
    func update(delta: float) -> void: pass
```

### Command Pattern

```gdscript
class_name Command
extends RefCounted

func execute() -> void:
    pass

func undo() -> void:
    pass

class MoveCommand extends Command:
    var _unit: Node2D
    var _direction: Vector2
    var _previous_position: Vector2
    
    func _init(unit: Node2D, direction: Vector2) -> void:
        _unit = unit
        _direction = direction
    
    func execute() -> void:
        _previous_position = _unit.position
        _unit.position += _direction * 32
    
    func undo() -> void:
        _unit.position = _previous_position
```

### Service Locator (Autoload Pattern)

```gdscript
# In Autoload 'Services'
var audio_manager: AudioManager
var save_manager: SaveManager
var network_manager: NetworkManager

func _ready() -> void:
    audio_manager = AudioManager.new()
    save_manager = SaveManager.new()
    add_child(audio_manager)
    add_child(save_manager)

# Usage in other scripts
Services.audio_manager.play_sfx("jump")
```

### Composition Pattern

```gdscript
class_name HealthComponent
extends Node

signal died
signal health_changed(current: int, max: int)

@export var max_health: int = 100

var current_health: int

func _ready() -> void:
    current_health = max_health

func take_damage(amount: int) -> void:
    current_health = max(0, current_health - amount)
    health_changed.emit(current_health, max_health)
    if current_health <= 0:
        died.emit()

func heal(amount: int) -> void:
    current_health = min(max_health, current_health + amount)
    health_changed.emit(current_health, max_health)
```
