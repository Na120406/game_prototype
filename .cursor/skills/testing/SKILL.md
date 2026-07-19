# Testing Skill

Use this skill when setting up tests, writing test cases, or analyzing test coverage for the game project.

## When to Use

- Setting up test infrastructure
- Writing unit tests for game logic
- Creating integration tests for systems
- Analyzing test coverage
- Debugging test failures
- Creating test helpers and fixtures

## Test Types for Game Development

### 1. Unit Tests
Test individual functions and classes in isolation.
- Game logic (damage calculation, loot drops)
- Utility functions
- Data transformations

### 2. Integration Tests
Test system interactions and APIs.
- Autoload system communication
- Scene loading and transitions
- Save/Load functionality

### 3. Performance Tests
Test performance characteristics.
- Frame time budgets
- Memory usage
- Load times

## GDScript Testing Patterns

### Basic Test Structure

```gdscript
extends "res://tests/test_base.gd"

func test_damage_calculation():
    var damage := DamageCalculator.new()
    var result := damage.calculate(100, 25, 0.1)
    assert_eq(result, 22.5, "Damage should be calculated correctly")
```

### Test Fixtures

```gdscript
class_name TestFixtures

static func create_player() -> Player:
    var player := Player.new()
    player.health = 100
    player.max_health = 100
    return player

static func create_enemy(health: int = 50) -> Enemy:
    var enemy := Enemy.new()
    enemy.health = health
    return enemy
```

### Mocking

```gdscript
class_name MockEventBus
extends Node

var signals := {}

func emit(signal_name: String, ...args):
    signals[signal_name] = args
```

## Coverage Requirements

**Target: 80% code coverage**

Priority order:
1. Autoloads (global state)
2. Core game systems (combat, inventory, quest)
3. Data processing (calculations, validations)
4. Utility functions
5. UI logic

## Common Test Scenarios for Games

| System | Test Cases |
|--------|------------|
| Combat | Damage calculation, critical hits, miss chance |
| Inventory | Add/remove items, stack limits, weight limits |
| Quest | Quest progression, objective tracking, completion |
| Save/Load | State preservation, corruption handling |
| Economy | Transaction validation, debt limits |
| NPC | Schedule evaluation, dialogue branching |

## Test Organization

```
tests/
├── unit/
│   ├── test_damage.gd
│   ├── test_inventory.gd
│   └── test_quest.gd
├── integration/
│   ├── test_autoload_communication.gd
│   └── test_save_load.gd
├── fixtures/
│   ├── player_fixture.gd
│   └── items_fixture.gd
└── helpers/
    ├── mock_event_bus.gd
    └── test_base.gd
```

## Related Skills

- `/godot` - For Godot-specific test patterns
- `/code-review` - For reviewing test quality
- `/game-design` - For defining testable acceptance criteria
