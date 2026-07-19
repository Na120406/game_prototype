# Code Review Skill

Use this skill to perform architectural and quality code reviews on GDScript files or game systems.

## When to Use

- Before committing significant changes
- When refactoring complex systems
- When performance issues are suspected
- For design document implementation review
- When code feels "off" or hard to maintain

## Review Checklist

### 1. Standards Compliance
- [ ] Public methods have doc comments
- [ ] No method exceeds 40 lines (excluding data declarations)
- [ ] Static typing used throughout
- [ ] No hardcoded values (use config/data files)

### 2. Architecture
- [ ] Correct dependency direction (engine <- gameplay)
- [ ] No circular dependencies
- [ ] Proper layer separation (UI does not own game state)
- [ ] Events/signals used for cross-system communication
- [ ] Consistent with established patterns

### 3. Godot-Specific
- [ ] `@onready` used for node references
- [ ] Signals for decoupled communication
- [ ] `PackedScene` for instantiation
- [ ] Proper resource cleanup (`queue_free()`)
- [ ] No signal connections in `_process()`

### 4. Performance
- [ ] Frame-rate independence (delta time usage)
- [ ] No allocations in hot paths
- [ ] Object pooling for frequently instantiated scenes
- [ ] `set_process(false)` when idle

### 5. Error Handling
- [ ] Null/empty state handling
- [ ] Proper error propagation
- [ ] User-friendly error messages

## Code Quality Issues to Flag

**Blocking Issues:**
- Hardcoded gameplay values
- Missing signal cleanup
- Memory leaks (nodes not freed)
- Circular dependencies
- UI owning game state

**Warnings:**
- Missing doc comments
- Methods > 40 lines
- Inconsistent naming
- No null checks
- Complex nested conditionals

## Output Format

```
## Code Review: [File/System Name]

### Summary
[Brief description of what was reviewed]

### Issues Found
| Severity | Location | Issue | Suggestion |
|----------|----------|-------|------------|
| 🔴 HIGH | line 42 | Hardcoded value | Load from config |
| 🟡 MED  | line 15 | Missing doc | Add comment |

### Positive Observations
[What is done well]

### Recommendations
[Nice-to-have improvements]

### Verdict: [APPROVED / CHANGES REQUIRED]
```

## Related Skills

- `/godot` - For Godot-specific best practices
- `/game-design` - For design implementation review
- `/testing` - For testability analysis
