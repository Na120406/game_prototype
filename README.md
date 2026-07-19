<<<<<<< HEAD
# GameDemo1
farm horror
=======
# Farm Horror Demo — Godot 4 Indie Game

A narrative exploration game with ambient psychological horror elements. Built with Godot 4 and GDScript.

## Project Status

**Phase 1: Foundation** — In Progress

## Development Framework

This project uses **Claude-Code-Game-Studios** principles for organized development:

### Available Skills

| Skill | Purpose | When to Use |
|-------|---------|-------------|
| `/godot` | Godot 4 best practices | Engine-specific questions |
| `/game-design` | Game mechanics & systems | Design decisions |
| `/code-review` | Quality code review | Before commits |
| `/testing` | Test setup & patterns | Unit/integration tests |

### Available Agents

| Agent | Role | For |
|-------|------|-----|
| `godot-specialist` | Godot engine expert | Architecture, APIs, optimization |
| `game-designer` | Systems & mechanics | Design review |
| `godot-gdscript-specialist` | GDScript patterns | Code quality |
| `narrative-director` | Story & lore | Narrative consistency |

### Coding Standards

See `.cursor/rules/` for path-scoped standards:
- `godot/gameplay-code.md` — Gameplay logic rules
- `godot/ui-code.md` — UI code rules
- `godot/engine-code.md` — Engine/core rules
- `narrative.md` — Story/lore rules

### Document Templates

See `docs/templates/` for:
- `gdd-template.md` — Game Design Document
- `character-sheet-template.md` — NPC design
- `test-plan-template.md` — Test planning

## Folder Structure

```
game-demo/
├── .cursor/                    # Cursor AI configuration
│   ├── agents/                 # Specialized agent definitions
│   │   ├── godot-specialist.md
│   │   ├── game-designer.md
│   │   └── ...
│   ├── rules/                  # Coding standards (path-scoped)
│   │   └── godot/
│   │       ├── gameplay-code.md
│   │       ├── ui-code.md
│   │       └── engine-code.md
│   └── skills/                 # Skill definitions
│       ├── godot/
│       ├── game-design/
│       ├── code-review/
│       └── testing/
│
├── design/                     # Game design documents
│   ├── gdd/                    # Game Design Documents
│   └── narrative/              # Story, lore, characters
│
├── docs/
│   └── templates/              # Document templates
│       ├── gdd-template.md
│       └── ...
│
├── production/                  # Production tracking
│   └── session-state/          # Session notes
│
├── res://                      # Godot resources
│   ├── scenes/                # Godot scene files (.tscn)
│   ├── scripts/               # GDScript files
│   ├── assets/                # Game assets
│   └── resources/             # Custom Godot resources
│
├── project.godot               # Godot project configuration
└── TODO.md                     # Project task tracker
```

## Autoloads (Global Singletons)

These are automatically loaded when the game starts and persist across all scenes:

| Name | Script | Purpose |
|------|--------|---------|
| `GameState` | `game_state.gd` | Global game data: day, time, energy, inventory, world flags |
| `AudioManager` | `audio_manager.gd` | Audio playback: SFX, music, ambient sounds |
| `TimeManager` | `time_manager.gd` | Day/night cycle, time progression |
| `EventManager` | `event_manager.gd` | World events, anomaly triggers |
| `CameraManager` | `camera_manager.gd` | Camera shake, zoom, limits |
| `SceneManager` | `scene_manager.gd` | Scene transitions with fade |
| `DialogueManager` | `dialogue_manager.gd` | Dialogue state & data |

## Setup Instructions

### 1. Register Autoloads

After opening in Godot Editor:

1. **Project** → **Project Settings** → **Autoload**
2. Add each script from `scripts/autoload/` as an autoload:
   - `game_state.gd` → Node Name: `GameState`
   - `audio_manager.gd` → Node Name: `AudioManager`
   - `time_manager.gd` → Node Name: `TimeManager`
   - `event_manager.gd` → Node Name: `EventManager`
   - `camera_manager.gd` → Node Name: `CameraManager`
   - `scene_manager.gd` → Node Name: `SceneManager`
   - `dialogue_manager.gd` → Node Name: `DialogueManager`

### 2. Input Actions

The following input actions are pre-configured in `project.godot`:

- `move_up`, `move_down`, `move_left`, `move_right` — WASD movement
- `interact` — Space or E
- `ui_accept` — Enter/Space (default UI)
- `ui_cancel` — Escape (default UI)

### 3. Run

Press **F5** to run the project.

## Key Concepts

### Game State Pattern
All persistent data (day, time, inventory, world flags) lives in `GameState`. Scripts access it via `GameState.variable_name`. This ensures data persists across scene changes.

### Autoload as Singleton
Autoloads are singleton patterns — one instance always present. Every script can access them without needing references.

### Signal-Driven Communication
Nodes communicate via signals (`.emit()` / `.connect()`). Example:
```gdscript
TimeManager.time_changed.connect(_on_time_changed)
```

### Scene Composition
Each game object is a **Scene** (`.tscn`) containing a **Node Tree**. Scenes can be instantiated and nested:
```gdscript
var npc_scene := load("res://scenes/npc/farmer.tscn")
var npc := npc_scene.instantiate()
world.add_child(npc)
```

## Learning Path

1. **Phase 1** — Foundation: Project structure, GDScript basics, GameState, Autoloads
2. **Phase 2** — Movement & Camera: Player physics, smooth camera, tilemap collision
3. **Phase 3** — Exploration: World building, environmental storytelling, area design
4. **Phase 4** — Farm Simulation: Day/night cycle, farming mechanics, energy system
5. **Phase 5** — NPC & Interaction: NPC schedules, dialogue system, interaction framework
6. **Phase 6** — Atmosphere & Horror: Lighting, ambient audio, anomaly events
7. **Phase 7** — Narrative: Lore fragments, world state, discovery mechanics
8. **Phase 8** — Polish: Save/load, UI, export

## Aseprite → Godot Pipeline

1. Draw pixel art in Aseprite (16x16 or 32x32 base)
2. Keep `.aseprite` files in `assets/sprites/source/`
3. Export as `.png` with proper naming
4. Import into Godot
5. For tilesets: export as single image, set grid size in Godot TileSet editor

## Philosophy

- **Playable > Beautiful**
- **Finished > Perfect**
- **Simple > Scalable**

The world continues to exist without the player. Horror is discovered, not delivered.
>>>>>>> e9375ac (cursor architecture experiment)
