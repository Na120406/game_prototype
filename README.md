# GameDemo — Godot 4 Farm/Life-Sim Prototype

A 2D top-down farm/life-sim prototype built with **Godot 4.5** and **GDScript**.
Includes social simulation (NPCs with families, schedules, and succession) and an
optional layer of subtle narrative mystery that runs beneath the surface.

The farming loop is the core. Mystery is the depth, not the goal — players can
ignore it entirely and still have a complete experience.

> **Status:** Phase 1 — Foundation cleanup (see [TODO.md](./TODO.md))
> **GDD:** [design/gdd/game-demo-gdd-v3.md](./design/gdd/game-demo-gdd-v3.md)
> **Engine:** Godot 4.5 (Forward Plus)
> **Language:** GDScript
> **Main scene:** `res://scenes/maps/inside_house_map.tscn`

---

## Quick Start

1. Clone this repo.
2. Open the project in Godot 4.5 Editor (`project.godot`).
3. Press **F5** to run.

All 30 autoloads, input actions, and main scene are pre-configured in
`project.godot`. No manual setup required.

---

## Project Structure

```
game-demo/
├── .cursor/                    # Cursor AI configuration
│   ├── agents/                 # Specialized agent definitions
│   ├── rules/                  # Coding standards (path-scoped)
│   └── skills/                 # Skill definitions
│
├── design/
│   └── gdd/
│       ├── game-demo-gdd-v3.md # Current GDD (authoritative)
│       └── archive/            # Superseded GDDs
│           └── farm-horror-gdd-2026-08-22.md
│
├── docs/
│   ├── templates/              # Document templates (gdd, character-sheet)
│   └── characters/             # NPC character sheets
│
├── scenes/                     # Godot scenes (.tscn)
│   ├── maps/                   # town, farm, houses
│   ├── npc/                    # NPC scenes (Marcus, Shopkeeper...)
│   ├── ui/                     # HUD, dialogue, shop, inventory
│   ├── world/                  # Farm plots, beds, world objects
│   └── Player.tscn
│
├── scripts/
│   ├── autoload/               # 30 global singletons (see below)
│   ├── player/                 # Player controller + FSM
│   ├── npc/                    # NPC base + individual NPCs
│   ├── world/                  # Farm, transition, atmosphere
│   ├── ui/                     # UI scripts
│   ├── resources/              # ItemData, database loaders
│   ├── tools/                  # Build/dev tools
│   └── utils/                  # Save/load, helpers
│
├── resources/
│   ├── items/                  # ItemData class + database
│   │   └── definitions/        # 22 item .tres files
│   ├── dialogue/               # NPC dialogue JSON
│   └── tilesets/               # Tileset resources
│
├── project.godot               # Godot project config
├── TODO.md                     # Task tracker
└── README.md                   # This file
```

---

## Autoloads (30 Singletons)

All autoloads are pre-registered in `project.godot`. Listed by responsibility group.

### Core State

| Name | Script | Purpose |
|------|--------|---------|
| `GameState` | `scripts/autoload/game_state.gd` | Player state, world flags, day/time |
| `TimeManager` | `scripts/autoload/time_manager.gd` | Day/night cycle, time progression |
| `EnergyManager` | `scripts/autoload/energy_manager.gd` | Energy consumption, low/knockout states |
| `SaveManager` | `scripts/utils/save_manager.gd` | JSON save/load |

### Scene & Camera

| Name | Script | Purpose |
|------|--------|---------|
| `SceneManager` | `scripts/autoload/scene_manager.gd` | Scene transitions with fade |
| `CameraManager` | `scripts/autoload/camera_manager.gd` | Camera shake, zoom, limits |
| `InputRouter` | `scripts/autoload/input_router.gd` | Input dispatch to focused UI |
| `UIFocusManager` | `scripts/autoload/ui_focus_manager.gd` | UI focus stack |
| `FloatingWarning` | `scripts/autoload/floating_warning.gd` | Center-screen warnings (e.g. "It's late") |

### Items & Tools

| Name | Script | Purpose |
|------|--------|---------|
| `ItemDB` | `resources/items/item_database.gd` | Load + query item resources |
| `ItemManager` | `scripts/autoload/item_manager.gd` | Item add/remove/transfer |
| `ItemHandler` | `scripts/autoload/item_handler.gd` | Item use routing |
| `ToolHandler` | `scripts/autoload/tool_handler.gd` | Tool action routing |
| `ToolHandler` | | |

### NPCs & World

| Name | Script | Purpose |
|------|--------|---------|
| `FamilyRegistry` | `scripts/autoload/family_registry.gd` | 3 families, succession, status |
| `NPCSchedules` | `scripts/autoload/npc_schedules.gd` | NPC daily schedules |
| `NPCManager` | `scripts/autoload/npc_manager.gd` | NPC lifecycle, registration |
| `RiskCalculator` | `scripts/autoload/risk_calculator.gd` | Risk modifiers for activities |
| `WeatherSystem` | `scripts/autoload/weather_system.gd` | Weather + season state |
| `WorldSimulator` | `scripts/autoload/world_simulator.gd` | Top-level world tick |
| `CatchUpSystem` | `scripts/autoload/catch_up_system.gd` | Catch-up logic when player away |
| `FarmTickManager` | `scripts/autoload/farm_tick_manager.gd` | Authoritative farm state |
| `FarmEnums` | `scripts/autoload/farm_enums.gd` | Crop state/type enums + profiles |

### Quests & Events

| Name | Script | Purpose |
|------|--------|---------|
| `QuestSystem` | `scripts/autoload/quest_system.gd` | Quest lifecycle + dynamic generation |
| `EventManager` | `scripts/autoload/event_manager.gd` | Per-frame event dispatch |
| `EventChainEngine` | `scripts/autoload/event_chain_engine.gd` | Multi-step branched events |
| `ConsequenceResolver` | `scripts/autoload/consequence_resolver.gd` | Schedule flags/scenes/succession |

### Audio & Dialogue

| Name | Script | Purpose |
|------|--------|---------|
| `DialogueManager` | `scripts/autoload/dialogue_manager.gd` | Dialogue state + JSON loading |
| `AudioManager` | `scripts/autoload/audio_manager.gd` | SFX/music/ambient *(currently broken — see TODO.md)* |

### UI Autoloads

| Name | Script | Purpose |
|------|--------|---------|
| `InteractionPromptManager` | `scripts/autoload/interaction_prompt_manager.gd` | "Press E to..." prompts |
| `EnergyBar` | `scripts/ui/energy_bar.gd` | Persistent energy bar UI |
| `HotkeyInputManager` | `scripts/ui/hotkey_input_manager.gd` | Hotkey handling |

---

## Input Actions

Pre-configured in `project.godot`:

| Action | Default Key | Notes |
|--------|-------------|-------|
| `move_up` | W | |
| `move_down` | S | |
| `move_left` | A | |
| `move_right` | D | |
| `interact` | E | Space also works in some contexts |
| `sprint` | X | Hold to sprint |
| `toggle_inventory` | Tab | Open/close inventory |
| `toolbar_slot_1`..`5` | 1..5 | Hotbar slots |

---

## Folder Highlights

### `scripts/autoload/` — 30 singletons

The autoloads are the backbone. Most are independent subsystems that communicate
via signals or through `GameState`. The most complex interdependencies:

- **`RiskCalculator`** feeds into **`EventChainEngine`** (risk determines outcome).
- **`EventChainEngine`** triggers **`ConsequenceResolver`** (chains emit consequences).
- **`ConsequenceResolver`** mutates **`GameState`** flags, **`FamilyRegistry`**, and
  scene overrides.
- **`FarmTickManager`** runs day-boundary logic independently of player location.

### `scripts/npc/` — NPC base + individuals

- `npc.gd` — Base class with FSM state, interaction logic. Pathfinding is stubbed.
- `neighbor.gd` — **Marcus**, the Day-1 mentor NPC with unique intro flow.
- `shopkeeper.gd` — Shopkeeper NPC (Voss family).

### `resources/items/definitions/` — 22 item resources

Each `.tres` is an `ItemData` resource. Loaded dynamically by `ItemDB` at startup.
Categories: seeds, farm produce, tools, consumables, key items.

---

## Key Concepts

### Game State Pattern

All persistent data (day, time, energy, inventory, world flags, NPC relationships)
lives in `GameState`. Scripts access it via `GameState.variable_name`. Data
persists across scene transitions.

### Autoload as Singleton

Autoloads are singleton patterns — one instance always present. Every script can
access them without needing references.

### Signal-Driven Communication

Nodes communicate via Godot signals (`.emit()` / `.connect()`). Example:

```gdscript
TimeManager.time_changed.connect(_on_time_changed)
```

### Scene Composition

Each game object is a **Scene** (`.tscn`) containing a **Node Tree**. Scenes can
be instantiated and nested:

```gdscript
var npc_scene := load("res://scenes/npc/neighbor.tscn")
var npc := npc_scene.instantiate()
world.add_child(npc)
```

### Consequence Resolver

The `ConsequenceResolver` is the bridge between abstract event outcomes and
concrete world changes. It can:

- Schedule flag changes (e.g. "shop open in 5 days").
- Schedule scene method calls.
- Schedule family succession.
- Replace dialogue based on condition flags.
- Log every consequence for debugging/replay.

---

## Coding Standards

See `.cursor/rules/` for path-scoped standards:

- `godot/gameplay-code.md` — Gameplay logic rules
- `godot/ui-code.md` — UI code rules
- `godot/engine-code.md` — Engine/core rules
- `narrative.md` — Story/lore rules

---

## Document Templates

See `docs/templates/` for:

- `gdd-template.md` — Game Design Document template
- `character-sheet-template.md` — NPC design template

## Character Sheets

See `docs/characters/` for current NPC designs:

- `marcus.md` — The neighbor NPC
- `shopkeeper-family.md` — The Voss family
- `hermit.md` — Old Hanz

---

## Asset Pipeline (Aseprite)

1. Draw pixel art in Aseprite (16x16 or 32x32 base).
2. Keep `.aseprite` source files in `assets/sprites/source/`.
3. Export as `.png` with proper naming.
4. Import into Godot.
5. For tilesets: export as single image, set grid size in Godot TileSet editor.

---

## Philosophy

- **Playable > Beautiful**
- **Finished > Perfect**
- **Simple > Scalable**

The world continues to exist without the player. Mystery is discovered, not
delivered.

---

## See Also

- [design/gdd/game-demo-gdd-v3.md](./design/gdd/game-demo-gdd-v3.md) — Authoritative GDD
- [design/gdd/archive/farm-horror-gdd-2026-08-22.md](./design/gdd/archive/farm-horror-gdd-2026-08-22.md) — Superseded GDD (pillars source)
- [TODO.md](./TODO.md) — Task tracker
