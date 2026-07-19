# Godot Specialist Skill

Use this skill when you need expert guidance on Godot 4 engine-specific patterns, APIs, optimization, or architecture decisions.

## When to Use

- Adding new autoloads or singletons
- Designing scene/node architecture for a new system
- Choosing between GDScript, C#, or GDExtension
- Setting up input mapping or UI with Godot's Control nodes
- Configuring export presets for any platform
- Optimizing rendering, physics, or memory in Godot
- Questions about Godot best practices

## What This Skill Provides

### Godot 4 Best Practices

**Scene and Node Architecture:**
- Prefer composition over inheritance — attach behavior via child nodes
- Each scene should be self-contained and reusable
- Use `@onready` for node references, never hardcoded paths
- Use `PackedScene` for instantiation
- Keep the scene tree shallow

**GDScript Standards:**
- Use static typing everywhere: `var health: int = 100`
- Use `class_name` to register custom types
- Use `@export` for inspector-exposed properties
- Signals for decoupled communication
- Use `await` for async operations (not `yield` from Godot 3)
- Follow Godot naming: `snake_case` for functions/variables, `PascalCase` for classes

**Resource Management:**
- Use `Resource` subclasses for data-driven content
- Save shared data as `.tres` files
- Use resource UIDs for stable references

**Performance:**
- Minimize `_process()` and `_physics_process()`
- Use `Tween` for animations
- Object pooling for frequently instantiated scenes
- Use `VisibleOnScreenNotifier2D/3D`

**Autoloads:**
- Use sparingly — only for truly global systems
- Never use autoloads as a dumping ground

## Common Patterns

```gdscript
# Signal declaration with type-safe parameters
signal health_changed(new_health: int, max_health: int)

# Typed array usage
var enemies: Array[Enemy] = []

# @onready for node references
@onready var player: CharacterBody2D = $Player

# Static typing
func take_damage(amount: int) -> void:
    pass

# Data-driven value (correct)
var damage: float = config.get_value("combat", "base_damage", 10.0)

# NOT this (hardcoded - incorrect)
var damage: float = 25.0  # VIOLATION
```

## Example Questions to Ask

- "Should this be a static utility class or a scene node?"
- "Where should [data] live? (autoload? Resource? Config file?)"
- "What's the best approach for [specific Godot pattern]?"
- "How do I optimize [performance concern] in Godot 4?"

## Related Skills

- `/game-design` - For game mechanics and systems design
- `/code-review` - For reviewing implementation quality
- `/testing` - For test setup and patterns
