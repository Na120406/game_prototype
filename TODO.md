# TODO.md — Farm Horror Demo

> Last updated: 2026-08-24
> Reference: [design/gdd/game-demo-gdd-v3.md](./design/gdd/game-demo-gdd-v3.md)

## Trạng thái Symbols
- [ ] Chưa làm
- [P] Đang làm
- [D] Đã hoàn thành

---

## DOCUMENTATION TASKS (2026-08-24 sync)

- [D] **GDD v3 rewritten** — [design/gdd/game-demo-gdd-v3.md](./design/gdd/game-demo-gdd-v3.md) (2026-08-24)
- [D] **Old GDDs archived** — [design/gdd/archive/farm-horror-gdd-2026-08-22.md](./design/gdd/archive/farm-horror-gdd-2026-08-22.md)
- [D] **Old GDD v2 removed** — superseded by v3
- [D] **README rewritten** — merge conflict resolved, autoloads updated to 30, links to GDD v3
- [D] **Character sheets created:**
  - [D] [docs/characters/marcus.md](./docs/characters/marcus.md)
  - [D] [docs/characters/shopkeeper-family.md](./docs/characters/shopkeeper-family.md)
  - [D] [docs/characters/hermit.md](./docs/characters/hermit.md)

---

## PHASE 1: Critical Fixes (Ngay lập tức) — From GDD v3 roadmap

### 1.1 UID Issues ⚠️
- [ ] **Fix invalid UIDs** — Các UIDs không đúng format cần regenerate trong Godot Editor:
  - `uid://inv_ui_01` (inventory_ui.tscn) → Regenerate
  - `uid://hotbar_scene` (hotbar.tscn) → Regenerate
  - `uid://tooltip_panel_scene` (tooltip_panel.tscn) → Regenerate
  - `uid://dlg_ui_fixed` (dialogue_ui.tscn) → Regenerate
  - `uid://cbed01` (bed.tscn) → Regenerate
  - `uid://smg6d4a464ac` (shop_ui.tscn) → Regenerate
  - `uid://apple_item_scene` (apple.tscn) → Regenerate
  - `uid://shopkeeper_scene` (inside_shop_map.tscn reference) → Regenerate
  - `uid://bwakjyivdpisv` (inside_shop_map.tscn) → Regenerate
  - `uid://bwakjhouse01` (inside_house_map.tscn) → Regenerate
  - `uid://de5kc56thmwpd` (town_map.tscn) → Regenerate

**Hướng dẫn fix UID:**
1. Mở Godot Editor
2. Right-click vào file trong FileSystem panel
3. Chọn "Regenerate UID" hoặc "Change UID"
4. Save scene

### 1.2 Missing NPC Scenes
- [ ] **Create NPC scenes** referenced in `FamilyRegistry`:
  - [ ] `res://scenes/npc/shopkeeper_father.tscn`
  - [ ] `res://scenes/npc/shopkeeper_son.tscn`
  - [ ] `res://scenes/npc/farmer_mother.tscn`
  - [ ] `res://scenes/npc/farmer_daughter.tscn`
  - [ ] `res://scenes/npc/hermit.tscn`

### 1.3 Missing Shop Scene
- [ ] **Create `res://scenes/world/shop.tscn`** — Reference trong `ConsequenceResolver.apply_consequence_set("shop_closed")`

### 1.4 Audio System
- [D] **Create `assets/` folder structure** (done previously)
- [ ] **Add placeholder audio files** — 10 basic SFX files
- [ ] **Fix AudioManager** để handle missing files gracefully

### 1.5 Project Configuration Hygiene
- [ ] **Hard-coded input action names** — `project.godot` has `mouse_left` / `mouse_right` action names with Vietnamese descriptions embedded. Rename or split for clarity.
- [ ] **Review autoload naming** — `EnergyBar` and `HotkeyInputManager` are UI scripts registered as autoloads. Consider refactoring to scene-side managers (per GDD v3 §10 note).

---

## PHASE 2: Polish Farming + Energy Loop — From GDD v3 roadmap

### 2.1 Farming
- [ ] **Crop art** — Replace placeholder crop visuals with proper sprites
- [ ] **Energy feedback** — Visual/audio feedback when energy depletes, low-energy warning UX
- [ ] **"It's late" timing tuning** — Balance the AFK warning vs player agency

### 2.2 NPC Movement
- [ ] **Implement NPC pathfinding** — Wire `npc.gd` stubs (`move_to`, `_on_path_complete`) with `NavigationServer` or `AStar`
- [ ] **Visible world tick** — When player is at home, show what NPCs are doing (signals or scene-local preview)

### 2.3 Mystery Content
- [ ] **Schedule first event chain trigger** — `shopkeeper_mountain` chain exists but isn't called from `NPCSchedules` (gap between schedule and chain)
- [ ] **Tune 3 event chains** — `shopkeeper_mountain`, `festival_day`, `harvest_blight` — balance weights, add more branches
- [ ] **Dialogue unlocks** — Add `_grief` suffix dialogue for shopkeeper after REDUCED family status
- [ ] **Mystery plant hook** — Define what `MYSTERY_PLANT` does beyond `strange_fruit` resource

---

## PHASE 3: Economy + Quest — From GDD v3 roadmap

### 3.1 Economy Balancing
- [ ] **Sell price rebalance** — `SELL_PRICE_RATIO = 0.5` currently — playtest and adjust
- [ ] **Add shop items** — Expand from 22 items to richer catalog
- [ ] **Shop UI polish** — Tooltip timing, transaction feedback

### 3.2 Quest Expansion
- [ ] **Implement escort quest** — Wire `escort_voss_mountain` to existing `shopkeeper_mountain` chain branches
- [ ] **Delivery quest polish** — Already implemented for Marcus; expand other NPCs
- [ ] **Investigation quest** — `investigate_noise` from TODO v1
- [ ] **Festival quest** — `attend_festival` from TODO v1

---

## PHASE 4: Open Questions (resolve before later phases)

- [ ] **Mystery plant gameplay hook** — what does harvesting `strange_fruit` do?
- [ ] **Romance vs friendship split** — separate tracks or combined?
- [ ] **Audio direction** — SFX library + soundtrack source
- [ ] **Localization strategy** — Vietnamese hard-coded in dialogue JSON. i18n or VN-only?
- [ ] **Hermit motivation + arc** — Currently under-defined (see [docs/characters/hermit.md](./docs/characters/hermit.md))

---

## PHASE 5: Polish & Release

### 5.1 Visual Polish
- [ ] **Pixel art sprites** — All characters (8+), items (50+), tilesets (3+), UI elements
- [ ] **Animations** — Character walk cycles, item pickup, weather effects, UI transitions

### 5.2 Audio Polish
- [ ] **Complete audio bank** — 50+ SFX, 10+ music tracks, 10+ ambient tracks

### 5.3 Testing
- [ ] **Playtesting** — Core loop (10 hours), quest chains, save/load, edge cases
- [ ] **Bug fixing** — P0, P1, P2 priority passes

### 5.4 Documentation
- [D] **README.md synced with implementation** (rewritten 2026-08-24)
- [ ] **CHANGELOG.md**
- [ ] **DESIGN.md** — Architecture decisions
- [ ] **API documentation** for all 30 autoloads

---

## Backlog (Không ưu tiên)

### Visual Assets
- [ ] Character portraits for dialogue
- [ ] Cutscene art
- [ ] Title screen art
- [ ] Loading screen art

### Gameplay Features
- [ ] Fishing minigame
- [ ] Cooking system
- [ ] Trading with other villages
- [ ] Multiplayer (future)

### Platform
- [ ] Mobile port
- [ ] Console port
- [ ] Localization (Vietnamese, English)

---

## Known Issues

| Issue | Severity | Status | Notes |
|-------|----------|--------|-------|
| Invalid UIDs | Critical | Open | Need regeneration in Godot Editor |
| Missing shop.tscn | Critical | Open | Reference in ConsequenceResolver |
| Missing NPC scenes (5) | High | Open | Referenced in FamilyRegistry |
| AudioManager broken | High | Open | Missing assets folder |
| NPC pathfinding stubbed | Medium | Open | `npc.gd` has TODO methods |
| No automated tests | Medium | Open | Need test coverage |
| TileMap without tileset | Low | Open | TownMap renders nothing |
| Hard-coded input config | Low | Open | `project.godot` mouse_left/right |

---

## Next Actions (Immediate)

1. [ ] Regenerate all invalid UIDs in Godot Editor
2. [ ] Create the 5 missing NPC scenes
3. [ ] Create `res://scenes/world/shop.tscn`
4. [ ] Test basic gameplay loop end-to-end
5. [ ] Wire `shopkeeper_mountain` chain trigger from NPC schedule

---

## Progress Summary

```
Documentation sync          [██████████] 100% (5/5 doc tasks)
Phase 1: Critical Fixes     [░░░░░░░░░░]   0%  (0/15 tasks)
Phase 2: Polish Farm/Energy [░░░░░░░░░░]   0%  (0/9 tasks)
Phase 3: Economy + Quest    [░░░░░░░░░░]   0%  (0/7 tasks)
Phase 4: Open Questions     [░░░░░░░░░░]   0%  (0/5 tasks)
Phase 5: Polish & Release   [░░░░░░░░░░]   0%  (0/10 tasks)
───────────────────────────────────────────────
Total                        [██░░░░░░░░]  15%  (5/51 tasks)
```
