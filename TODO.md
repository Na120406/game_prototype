# TODO.md — Farm Horror Demo

> Last updated: 2026-07-17

## Trạng thái Symbols
- [ ] Chưa làm
- [P] Đang làm
- [D] Đã hoàn thành

---

## PHASE 1: Critical Fixes (Ngay lập tức)

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

### 1.2 Missing Files
- [ ] **Create `res://scenes/world/shop.tscn`** — Reference trong ConsequenceResolver
- [ ] **Create NPC scenes:**
  - [ ] `res://scenes/npc/shopkeeper_father.tscn`
  - [ ] `res://scenes/npc/shopkeeper_son.tscn`
  - [ ] `res://scenes/npc/farmer_mother.tscn`
  - [ ] `res://scenes/npc/farmer_daughter.tscn`
  - [ ] `res://scenes/npc/hermit.tscn`

### 1.3 Audio System
- [D] **Create `assets/` folder structure:**
  ```
  assets/
  ├── audio/
  │   ├── sfx/
  │   ├── music/
  │   └── ambient/
  ├── sprites/
  │   ├── characters/
  │   ├── tilesets/
  │   └── items/
  └── fonts/
  ```
- [ ] **Add placeholder audio files** — 10 basic SFX files
- [ ] **Fix AudioManager** để handle missing files gracefully

---

## PHASE 2: Core Gameplay (1-2 tuần)

### 2.1 Farming System
- [ ] **Expand crop types** — Thêm 5-10 crops mới
- [ ] **Fertilizer system** — Tăng yield
- [ ] **Pest/Disease system** — Thêm random blight events
- [ ] **Greenhouse building** — Mở khóa qua quest

### 2.2 NPC System
- [ ] **Implement 5 NPC characters:**
  - [ ] Old Voss (Shopkeeper Father) — Giao dịch, quest giver
  - [ ] Young Voss (Shopkeeper Son) — Thay thế khi cha mất
  - [ ] Martha Miller (Farmer Mother) — Quest giver, hints
  - [ ] Eliza Miller (Farmer Daughter) — Social interactions
  - [ ] Old Hanz (Hermit) — Mystery, horror elements

- [ ] **Dialogue system expansion:**
  - [ ] 5 dialogue trees cho mỗi NPC
  - [ ] Dynamic dialogue based on game state
  - [ ] Multiple conversation branches

### 2.3 Quest System
- [ ] **Implement escort quest** (`escort_voss_mountain`)
  - [ ] NPC follows player
  - [ ] Risk calculation integration
  - [ ] Multiple outcomes (safe/injured/dead)
  - [ ] Player choices affect outcome

- [ ] **Implement delivery quest** (`deliver_medicine`)
- [ ] **Implement investigation quest** (`investigate_noise`)
- [ ] **Implement festival quest** (`attend_festival`)

### 2.4 Event Chains
- [ ] **Complete `shopkeeper_mountain` chain** với player escort system
- [ ] **Complete `festival_day` chain**
- [ ] **Complete `harvest_blight` chain**
- [ ] **Add 5-10 new chains:**
  - [ ] Merchant caravan arrival
  - [ ] Strange lights in forest
  - [ ] Missing villager
  - [ ] Old mine discovery
  - [ ] Underground bunker

---

## PHASE 3: Horror Elements (2-3 tuần)

### 3.1 Atmosphere
- [ ] **Time-based lighting:**
  - [ ] Dawn (6:00-8:00) — Warm, golden
  - [ ] Day (8:00-18:00) — Normal
  - [ ] Dusk (18:00-20:00) — Orange, red
  - [ ] Night (20:00-6:00) — Blue, dark

- [ ] **Anomaly effects:**
  - [ ] Screen distortion randomly
  - [ ] Flickering lights
  - [ ] Distant sounds (whispers, footsteps)
  - [ ] Items moved overnight

### 3.2 Horror Events
- [ ] **"Strange events" chain:**
  - [ ] Crops wilt overnight
  - [ ] Animal sounds at night
  - [ ] Shadows in peripheral vision
  - [ ] Notes/text appearing

- [ ] **Environmental storytelling:**
  - [ ] Hidden lore fragments (10 total)
  - [ ] Visual clues about village history
  - [ ] Foreshadowing events

### 3.3 Audio
- [ ] **Ambient soundscapes:**
  - [ ] Forest ambient (day/night variants)
  - [ ] Rain/thunder
  - [ ] Village sounds
  - [ ] Uncanny versions of normal sounds

- [ ] **Music:**
  - [ ] Main theme (calm, slightly unsettling)
  - [ ] Shop music
  - [ ] Night music (droning, tension)
  - [ ] Horror stingers

---

## PHASE 4: Content Expansion (1-2 tháng)

### 4.1 Maps
- [ ] **Complete existing maps:**
  - [ ] farm_map.tscn — Add more detail, decorations
  - [ ] town_map.tscn — Add buildings, NPCs
  - [ ] inside_house_map.tscn — Polish interior
  - [ ] inside_shop_map.tscn — Add inventory display

- [ ] **New maps:**
  - [ ] mountain_path.tscn — For escort quest
  - [ ] forest_edge.tscn — For investigation quest
  - [ ] village_square.tscn — For festival
  - [ ] hermit_cabin.tscn — Hidden area
  - [ ] underground_bunker.tscn — Late-game area

### 4.2 Items
- [ ] **Current 23 items** ✓
- [ ] **Expand to 50+ items:**
  - [ ] Crafting materials (10)
  - [ ] Tools upgrades (5)
  - [ ] Quest items (10)
  - [ ] Food items (10)
  - [ ] Key items (5)
  - [ ] Lore items (5)

### 4.3 UI/UX
- [ ] **Main Menu:**
  - [ ] New Game
  - [ ] Continue
  - [ ] Settings
  - [ ] Credits

- [ ] **Pause Menu:**
  - [ ] Save/Load
  - [ ] Settings
  - [ ] Quit to Menu

- [ ] **HUD improvements:**
  - [ ] Day/Time display
  - [ ] Weather indicator
  - [ ] Quest tracker
  - [ ] Energy bar (more visible)

---

## PHASE 5: Polish & Release (2-4 tuần)

### 5.1 Visual Polish
- [ ] **Pixel art sprites:**
  - [ ] All characters (8+)
  - [ ] All items (50+)
  - [ ] Tilesets (3+)
  - [ ] UI elements

- [ ] **Animations:**
  - [ ] Character walk cycles
  - [ ] Item pickup effects
  - [ ] Weather effects (rain, snow)
  - [ ] UI transitions

### 5.2 Audio Polish
- [ ] **Complete audio bank:**
  - [ ] 50+ SFX
  - [ ] 10+ music tracks
  - [ ] 10+ ambient tracks

### 5.3 Testing
- [ ] **Playtesting:**
  - [ ] Core loop test (10 hours)
  - [ ] Quest chain test
  - [ ] Save/Load test
  - [ ] Edge cases

- [ ] **Bug fixing:**
  - [ ] All P0 bugs fixed
  - [ ] All P1 bugs fixed
  - [ ] All P2 bugs fixed

### 5.4 Documentation
- [ ] **Update README.md** — Sync với implementation
- [ ] **Create CHANGELOG.md**
- [ ] **Create DESIGN.md** — Architecture decisions
- [ ] **API documentation** cho autoloads

---

## Backlog (Không ưu tiên)

### Visual Assets
- [ ] Character portraits cho dialogue
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

## Progress Summary

```
Phase 1: Critical Fixes      [░░░░░░░░░░]   0%  (0/7 tasks)
Phase 2: Core Gameplay       [░░░░░░░░░░]   0%  (0/20 tasks)
Phase 3: Horror Elements     [░░░░░░░░░░]   0%  (0/15 tasks)
Phase 4: Content Expansion   [░░░░░░░░░░]   0%  (0/18 tasks)
Phase 5: Polish & Release    [░░░░░░░░░░]   0%  (0/12 tasks)
───────────────────────────────────────────────
Total                         [░░░░░░░░░░]   0%  (0/72 tasks)
```

---

## Known Issues

| Issue | Severity | Status | Notes |
|-------|----------|--------|-------|
| Invalid UIDs | Critical | Open | Need regeneration in Godot Editor |
| Missing shop.tscn | Critical | Open | Reference in ConsequenceResolver |
| Missing NPC scenes | High | Open | 5 NPC scenes needed |
| AudioManager broken | High | Open | Missing assets folder |
| README outdated | Medium | Open | 7 autoloads vs 19 actual |
| No tests | Medium | Open | Need 80%+ coverage |
| TileMap without tileset | Low | Open | TownMap renders nothing |

---

## Next Actions (Immediate)

1. [D] Regenerate all invalid UIDs in Godot Editor (See `UID_FIX_INSTRUCTIONS.md`)
2. [D] Create placeholder assets folder structure
3. [ ] Add at least 1 SFX and 1 music file
4. [ ] Test basic gameplay loop
5. [ ] Update README.md
