# GDScript Coding Style Guide

## Project Overview

This project uses Godot 4.x with GDScript for game development.

## GDScript Conventions

### Naming Conventions

- **Classes**: `PascalCase` (e.g., `PlayerController`, `InventoryManager`)
- **Functions**: `snake_case` (e.g., `move_player`, `take_damage`)
- **Variables**: `snake_case` (e.g., `health_points`, `current_level`)
- **Constants**: `SCREAMING_SNAKE_CASE` (e.g., `MAX_SPEED`, `DEFAULT_HEALTH`)
- **Signals**: `snake_case` (e.g., `health_changed`, `player_died`)
- **Enums**: `PascalCase` for enum name, `SCREAMING_SNAKE_CASE` for values

### File Organization

```
scripts/
├── autoloads/
│   └── GameManager.gd
├── characters/
│   ├── Player.gd
│   └── Enemy.gd
├── ui/
│   ├── HUD.gd
│   └── PauseMenu.gd
└── helpers/
    └── AudioManager.gd
```

### Code Structure

```gdscript
class_name MyClass
extends Node

## Class description for documentation.

signal something_happened(value: int)

@export var exported_variable: int = 10
@export_group("My Group")
@export var another_var: float = 5.0

var _private_variable: int = 0
var _cached_result: Dictionary = {}

const CONSTANT_VALUE: int = 100


func _ready() -> void:
    pass


func my_function(param: String) -> void:
    print(param)


func _process(delta: float) -> void:
    pass
```

### Best Practices

1. **Type Hints**: Always use type hints for better editor support and error checking
2. **Docstrings**: Add `##` comments for classes and public functions
3. **Export Variables**: Use `@export` for editor-configurable values
4. **Private Variables**: Prefix with `_` for internal state
5. **Constants**: Use `const` for values that never change
6. **Signal Usage**: Emit signals for communication between nodes instead of direct calls when appropriate

### Common Patterns

#### Singleton Pattern (Autoload)
```gdscript
# In an autoload script
var current_score: int = 0

func add_score(points: int) -> void:
    current_score += points
    signal_score_changed.emit(current_score)
```

#### State Machine
```gdscript
enum State { IDLE, RUNNING, JUMPING, FALLING }

var current_state: State = State.IDLE

func transition_to(new_state: State) -> void:
    _exit_state(current_state)
    current_state = new_state
    _enter_state(current_state)
```

### Error Handling

- Use `assert()` for development-time checks
- Return error codes or use `Result` pattern for expected failures
- Log errors with context: `push_error("Failed to load: " + path)`

### Performance Tips

- Cache node references with `@onready` instead of using `get_node()` every frame
- Use `preload()` for resources that are always needed
- Consider object pooling for frequently created/destroyed objects
