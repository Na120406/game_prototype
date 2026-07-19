# GDScript Testing Guide

## Overview

Testing in Godot/GDScript projects requires specific approaches due to the engine's architecture.

## Testing Strategies

### Unit Testing

For pure logic functions, create test scenes:

```gdscript
# tests/test_math_utils.gd
extends GutTest

func test_calculate_damage():
    var expected = 42
    var actual = MathUtils.calculate_damage(100, 0.6, 20)
    assert_eq(expected, actual, "Damage calculation should match expected value")
```

### Integration Testing

Test node interactions using Gut or custom test runners:

```gdscript
func test_player_takes_damage():
    var player = _create_test_player()
    var initial_health = player.health
    player.take_damage(10)
    assert_eq(player.health, initial_health - 10)
```

### Mocking

Use dependency injection for testability:

```gdscript
class_name HealthComponent
extends Node

func _init(health_system: HealthSystem = null) -> void:
    _health_system = health_system
```

## Test Coverage Goals

- **Target**: 70%+ coverage for game logic
- **Priority areas**: Damage calculations, inventory systems, AI behavior, save/load

## CI/CD Integration

Add tests to your CI pipeline:

```yaml
# .github/workflows/test.yml
- name: Run GDScript Tests
  run: |
    godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/
```
