# GameDemo — Game Design Document

> **Trạng thái:** Đang phát triển (Living Document)
> **Phiên bản:** 3.0
> **Ngày tạo:** 2026-08-24
> **Cập nhật lần cuối:** 2026-08-24
> **Kiểm tra code lần cuối:** 2026-08-24
> **Đối tượng:** Team dev nội bộ, designer mới onboard
> **Engine:** Godot 4.5 — GDScript
> **Thay thế:** game-demo-gdd-v2.md (2026-08-23)

---

## Mục lục

1. [Tổng quan](#1-tổng-quan)
2. [Game Pillars — 5 Trụ cột](#2-game-pillars--5-trụ-cột)
3. [Core Systems — Hệ thống lõi](#3-core-systems--hệ-thống-lõi)
4. [Workflows & State Diagrams](#4-workflows--state-diagrams)
5. [Implemented vs Roadmap](#5-implemented-vs-roadmap)
6. [Edge Cases — Tình huống biên](#6-edge-cases--tình-huống-biên)
7. [Tuning Knobs — Các thông số cân chỉnh](#7-tuning-knobs--các-thông-số-cân-chỉnh)
8. [Open Questions — Câu hỏi mở](#8-open-questions--câu-hỏi-mở)
9. [Acceptance Criteria — Tiêu chí nghiệm thu](#9-acceptance-criteria--tiêu-chí-nghiệm-thu)
10. [Appendix — Chỉ mục file](#10-appendix--chỉ-mục-file)

---

## 1. Tổng quan

### 1.1 Tóm tắt một dòng (One-liner)

> Game nông trại top-down 2D, lấy cảm hứng từ mô hình farm/life-sim, với một lớp
> narrative mystery dạng tinh tế (không jump-scare) chạy nền qua hệ thống event chains.

### 1.2 Concept

Người chơi nhập vai một người mới chuyển đến một vùng quê hẻo lánh. Ngày đầu tiên,
một người hàng xóm tên Marcus đến gõ cửa — giới thiệu thế giới, dạy cách trồng trọt,
và lưu ý một điều kỳ lạ: đừng thức khuya quá nửa đêm.

Từ đó, người chơi có thể tập trung vào farm loop hoàn toàn, hoặc — nếu để ý đến
dialogue, lịch trình NPC, và những thay đổi nhỏ trong thế giới — tự khám phá ra
lớp mystery ẩn bên dưới.

### 1.3 Player Fantasy

- **Cảm giác buổi sáng đầu tiên:** Nhìn thấy Marcus đứng ngoài cửa, ánh nắng nhẹ.
- **Cảm giác ngày làm việc:** Cày đất → gieo hạt → tưới nước → thu hoạch. Rõ ràng,
  có feedback.
- **Cảm giác bất ngờ:** Mở cửa hàng thấy đóng. Hỏi Marcus thì được nói "ông Voss đi
  núi chưa về." Không ai biết chuyện gì sẽ xảy ra.
- **Cảm giác tự do có giới hạn:** 20 energy mỗi ngày. Muốn làm hết mọi thứ phải
  chọn lọc.

### 1.4 Thông số kỹ thuật (Specs)

| Thông số | Giá trị |
|-----------|---------|
| Engine | Godot 4.5 (Forward Plus) |
| Ngôn ngữ | GDScript |
| Autoloads | 30 singletons (`project.godot`) |
| Script files | 62 files |
| Scenes | 32 `.tscn` |
| Item resources | 22 `.tres` (`resources/items/definitions/`) |
| Main scene | `res://scenes/maps/inside_house_map.tscn` |
| Display | 320×180 internal, 1280×720 window, integer scale |

### 1.5 Phạm vi (Scope)

**Có trong v3:**
- Core farming loop hoàn chỉnh
- Social simulation (3 families, 4 NPC schedules)
- Event chain system với 3 chains
- Quest system (static + dynamic delivery)
- Save/Load JSON

**Chưa có trong v3:**
- NPC pathfinding thực sự (stubbed)
- 5 NPC scene files (missing)
- Audio (AudioManager broken)
- Romance/dialogue branches
- Multiple endings

**Không có trong phạm vi v3:**
- Multiplayer
- Save slot UI
- Controller support
- Mobile/touch input

---

## 2. Game Pillars — 5 Trụ cột

Năm trụ cột này được lấy từ [farm-horror-gdd-2026-08-22.md](./archive/farm-horror-gdd-2026-08-22.md)
và diễn đạt lại cho framing farm/life-sim.

### Pillar 1: Normalcy trước, unease sau

Farming loop phải **vững và thỏa mãn** trước khi bất kỳ mystery element nào len vào.
Người chơi không nên cảm thấy bị ép phải "khám phá bí ẩn" — họ phải tự tò mò vì
muốn, không vì bị bắt buộc.

**Test:** Một người chơi hoàn toàn bỏ qua mystery và chỉ farm suốt 10 ngày vẫn có
trải nghiệm hoàn chỉnh, không bị stuck hay thiếu context.

### Pillar 2: Discovery over exposition

Không có cutscene kể chuyện. Lore đến qua:

- Dialogue NPC (Marcus, Shopkeeper family, Hermit)
- Tooltip item (ví dụ `lore_fragment.tres`)
- Thay đổi lịch trình NPC sau event chain
- NPC mới xuất hiện hoặc biến mất

**Test:** Người chơi có thể hiểu 70% narrative mà không cần đọc GDD này.

### Pillar 3: Decision budgeting

Mỗi ngày có **20 energy** + giới hạn thời gian từ `TimeManager`. Mọi hành động đều
có chi phí. Người chơi buộc phải đánh đổi:

```
Ngày của tôi: Farm ↔ NPC ↔ Khám phá ↔ Nghỉ ngơi
```

**Test:** Người chơi cảm thấy mỗi ngày đều có ý nghĩa — không bao giờ có một ngày
"empty" mà không có gì để làm.

### Pillar 4: Living world

Thế giới tồn tại không cần người chơi:

- NPC có lịch trình riêng (qua `NPCSchedules`)
- Gia đình có succession logic (qua `FamilyRegistry`)
- World tick chạy độc lập với scene player đang ở (qua `WorldSimulator`/`CatchUpSystem`)
- NPC rời nhà buổi sáng, về buổi chiều, có thể gặp nạn

**Test:** Người chơi có thể đi ngủ sớm 3 ngày liên tiếp mà khi thức dậy, thế giới
đã thay đổi mà không cần họ làm gì.

### Pillar 5: Clear but unpredictable consequences

Outcome của event chain **rõ ràng** về mặt loại (NPC chết, shop đóng, mùa màng thất bại)
nhưng **trigger không ai đoán trước** vì phụ thuộc vào nhiều yếu tố ngẫu nhiên:

- Weather
- Time of day
- NPC personality (cautious/reckless/normal/old)
- Escort presence
- Season

**Test:** Một người chơi không thể đoán trước 100% outcome của bất kỳ event chain nào,
nhưng khi outcome xảy ra, họ hiểu tại sao.

---

## 3. Core Systems — Hệ thống lõi

Mỗi system bên dưới được kiểm tra trực tiếp từ source code ngày 2026-08-24.

### 3.1 Time & Energy

**Mục đích:** Giới hạn hành động mỗi ngày, tạo ra decision budgeting và pressure.

#### 3.1.1 Các thành phần

| Component | Script | Trạng thái |
|-----------|--------|-----------|
| TimeManager | `scripts/autoload/time_manager.gd` | ✅ Implemented |
| EnergyManager | `scripts/autoload/energy_manager.gd` | ✅ Implemented |
| GameState | `scripts/autoload/game_state.gd` | ✅ Implemented |
| FloatingWarning | `scripts/autoload/floating_warning.gd` | ✅ Implemented |

#### 3.1.2 Quy tắc (Rules)

```
max_energy = 20.0
LOW_ENERGY_THRESHOLD = 5.0
knockout_penalty = 25% gold loss
```

**Trạng thái energy:**

| Energy | Speed modifier | Trạng thái |
|--------|----------------|-------------|
| > 5.0 | 1.0× (bình thường) | Normal |
| ≤ 5.0 | 0.75× | Low energy warning |
| 0.0 | 0.5× + penalty | Knocked out → ngủ bắt buộc |

**Luồng ngày:**
1. Player thức dậy (inside_house_map) với energy max.
2. Energy giảm qua các hành động (farm actions, movement).
3. Time tăng theo real-time hoặc movement.
4. 22:00 hoặc energy = 0 → auto-sleep prompt → ngày mới.

**AFK Penalty:** Nếu energy = 0 mà chưa ngủ → hệ thống tự đẩy qua đêm,
player mất 25% gold, energy reset về max.

#### 3.1.3 Workflow

```
[Start Day]
    ↓
[Energy > 0?] ─No→ [AFK Penalty] → [Force Sleep] → [Next Day]
    ↓ Yes
[Player Action] (farm/move/interact)
    ↓
[Energy -= action_cost]
    ↓
[Energy ≤ 0?] ─No→ [Continue]
    ↓ Yes
[AFK Penalty] → [Force Sleep] → [Next Day]
```

#### 3.1.4 Ghi chú

- `FloatingWarning` hiển thị "It's late" warning khi time gần midnight.
- Energy bar update mỗi khi có thay đổi.
- Sprint (phím X) có thể tiêu tốn thêm energy (tuỳ implementation chi tiết).

---

### 3.2 Farming System

**Mục đích:** Core gameplay loop. Cho người chơi cảm giác tiến bộ qua thu hoạch,
và tạo ra dependency vào schedule (tưới mỗi ngày = không thể đi khám phá xa).

#### 3.2.1 Các thành phần

| Component | Script | Trạng thái |
|-----------|--------|-----------|
| FarmTickManager | `scripts/autoload/farm_tick_manager.gd` | ✅ Implemented |
| FarmEnums | `scripts/autoload/farm_enums.gd` | ✅ Implemented |
| farm_manager.gd | `scripts/world/farm/farm_manager.gd` | ✅ Implemented |
| farm_plot.gd | `scripts/world/farm/farm_plot.gd` | ✅ Implemented |
| crop_visual_manager.gd | `scripts/world/farm/crop_visual_manager.gd` | ✅ Implemented |

#### 3.2.2 Quy tắc (Rules)

**FarmTickManager là authoritative state** — chạy kể cả khi player không ở farm map.
Đây là điểm critical: farm không dừng khi bạn đi shopping.

**7 Crop States (enum `CropState`):**

```
EMPTY → PLOWED → SEEDED → SPROUTED → GROWING → MATURE
                                                    ↓
                                                WILTED
```

**6 Crop Types (enum `CropType`):**

```
WHEAT, CORN, TOMATO, POTATO, TURNIP, MYSTERY_PLANT
```

**Crop Water Profile (FarmEnums):**

| Crop | water_need | growth_per_water | grow_days |
|------|-----------|------------------|-----------|
| Wheat | 1 | 0.20 | 4 |
| Corn | 2 | 0.20 | 6 |
| Tomato | 2 | 0.25 | 8 |
| Potato | 3 | 0.20 | 5 |
| Turnip | 1 | 0.20 | 3 |
| Mystery Plant | ? | ? | 10 |

- `water_need`: số ngày liên tiếp không tưới trước khi crop chuyển sang WILTED.
- `growth_per_water`: tiến trình tăng mỗi lần tưới (trên thang 0.0–1.0).
- `grow_days`: số ngày tối thiểu để crop hoàn toàn trưởng thành (với đủ nước).

**Mystery Plant:** `grow_days = 10`, nhưng gameplay hook chưa rõ (xem Open Questions §8).

#### 3.2.3 Workflow

```
[Player Interact với Farm Plot]
    ↓
[Kiểm tra CropState hiện tại]
    ↓
EMPTY? ──→ [Plow] → PLOWED (tiêu tốn energy)
    ↓
PLOWED? ──→ [Plant Seed] → SEEDED (tiêu tốn seed + energy)
    ↓
SEEDED/SPROUTED/GROWING? ──→ [Water] → growth += growth_per_water (tiêu tốn energy)
    ↓
MATURE? ──→ [Harvest] → EMPTY + spawn item (tiêu tốn energy)
    ↓
[Water > water_need days liên tiếp?] ──→ WILTED → phá bỏ hoặc bỏ
```

**Day-boundary logic (FarmTickManager):**
- Mỗi ngày mới: kiểm tra tất cả farm cells.
- Nếu cell đang SEEDED+ mà không được tưới → water_days += 1.
- Nếu water_days >= water_need → crop chuyển WILTED.
- Nếu growth >= 1.0 → crop chuyển MATURE.

#### 3.2.4 Ghi chú

- Player action thực hiện qua farm_plot.gd (scene-side), nhưng **authoritative state**
  là FarmTickManager (autoload). farm_manager.gd chỉ render.
- Crop art chưa có → Phase 2 sẽ thêm sprites.

---

### 3.3 Item & Economy

**Mục đích:** Tạo ra vòng kinh tế: farm → bán → mua seeds/tools → farm nhiều hơn.
Shop là nexus của mối quan hệ kinh tế giữa player và thế giới.

#### 3.3.1 Các thành phần

| Component | Script | Trạng thái |
|-----------|--------|-----------|
| ItemData (resource class) | `resources/items/item_data.gd` | ✅ Implemented |
| ItemDB | `resources/items/item_database.gd` | ✅ Implemented |
| ItemManager | `scripts/autoload/item_manager.gd` | ✅ Implemented |
| ItemHandler | `scripts/autoload/item_handler.gd` | ✅ Implemented |
| Shop UI | `scripts/ui/shop_ui.gd` | ✅ Implemented |

#### 3.3.2 Quy tắc (Rules)

**Item Types (enum `ItemData.Type`):**

```
CONSUMABLE | TOOL | SEED | KEY_ITEM | CURRENCY | MISC
```

**Item Categories (enum `ItemData.Category`):**

```
FARM_PRODUCE | SEED | CONSUMABLE_FOOD | TOOL | KEY_ITEM | CURRENCY | MISC
```

**Economy rule:**

```
SELL_PRICE_RATIO = 0.5
→ Bán item = 50% giá mua
```

**Item loading:** Mỗi item là `.tres` resource. Load động từ
`resources/items/definitions/` qua `ItemDB._load_all_items()` khi game start.

**Fallback:** Item không tìm thấy → `ItemDB.safe_get_item()` trả placeholder + print warning.

**Inventory:** Lưu trong `GameState.inventory` (Array[Dictionary]) với cấu trúc:

```json
{"id": "wheat", "amount": 5}
```

#### 3.3.3 Workflow (Shop)

```
[Player interact với Shop]
    ↓
[Shop UI opens]
    ↓
[Player chọn Buy/Sell tab]
    ↓
Buy Tab: [Chọn item] → [Confirm] → [Gold -= price] → [Inventory += item]
Sell Tab: [Chọn item từ inventory] → [Confirm] → [Gold += price * 0.5] → [Inventory -= item]
    ↓
[Shop đóng]
```

#### 3.3.4 22 Item Resources hiện tại

Seeds: `seed_wheat.tres`, `seed_corn.tres`, `seed_tomato.tres`, `seed_potato.tres`,
`seed_turnip.tres`

Farm produce: `wheat.tres`, `corn.tres`, `tomato.tres`, `potato.tres`, `turnip.tres`,
`tomato_harvest.tres`, `corn_harvest.tres`, `potato_harvest.tres`, `turnip_harvest.tres`

Consumable: `health_potion.tres`, `apple.tres`

Tools: `hoe.tres`, `water_can.tres`

Key items: `old_key.tres`, `lore_fragment.tres`, `rope.tres`, `strange_fruit.tres`

#### 3.3.5 Ghi chú

- Shopkeeper đại diện cho `shopkeeper_family` trong `FamilyRegistry`.
- Nếu Old Voss chết (family REDUCED/EXTINCT) → shop có thể đóng qua `ConsequenceResolver`.
- Sell ratio hiện tại là 0.5 — có thể cần rebalance sau playtest (Phase 5).

---

### 3.4 NPC & Family System

**Mục đích:** Tạo ra thế giới sống. NPC không chỉ là quest giver — họ có gia đình,
lịch trình, và có thể chết. Điều này tạo ra stakes thực sự cho player.

#### 3.4.1 Các thành phần

| Component | Script | Trạng thái |
|-----------|--------|-----------|
| FamilyRegistry | `scripts/autoload/family_registry.gd` | ✅ Implemented |
| NPCSchedules | `scripts/autoload/npc_schedules.gd` | ✅ Implemented |
| NPCManager | `scripts/autoload/npc_manager.gd` | ✅ Implemented |
| npc.gd (base) | `scripts/npc/npc.gd` | ✅ Implemented |
| neighbor.gd (Marcus) | `scripts/npc/neighbor.gd` | ✅ Implemented |
| shopkeeper.gd | `scripts/npc/shopkeeper.gd` | ✅ Implemented |

#### 3.4.2 Quy tắc (Rules)

**3 Families đăng ký trong `FamilyRegistry._build_initial_families()`:**

| Family ID | Họ | Members | Status ban đầu |
|-----------|----|---------|---------------|
| `shopkeeper_family` | Voss | Old Voss (father, cautious), Young Voss (son, reckless) | INTACT |
| `farmer_family` | Miller | Martha Miller (mother, cautious), Eliza Miller (daughter, normal) | INTACT |
| `hermit_family` | — | Old Hanz (hermit, old) | INTACT |

**Family Status enum:**

```
INTACT   → Đầy đủ thành viên
REDUCED  → Mất ≥1 thành viên, còn ≥1
SCATTERED → Còn nhiều người nhưng không đầy đủ (chưa trigger trong code)
EXTINCT  → Không còn ai
```

**Succession logic:**
1. Khi head chết → tìm `successor` được chỉ định trong member data.
2. Nếu có successor → promote successor, set flags `npc_X_new_head`, `npc_X_succeeded_from`.
3. Nếu không có successor → `alive_members[0]` được promote (first in array).
4. Family status cập nhật: count alive members → INTACT/REDUCED/SCATTERED/EXTINCT.

**Lịch trình NPC (`NPCSchedules`):**

4 NPCs có lịch trình: `shopkeeper_father`, `farmer_mother`, `hermit`, `shopkeeper_son`.

Mỗi entry gồm: `day_of_week`, `departure_time`, `return_time`, `risk_activity`, `chain_id`.

| NPC | Day of week | Activity | Risk Activity | Chain |
|-----|-------------|----------|---------------|-------|
| Old Voss | 5 (Thứ 7) | Mountain trip | `mountain_trip` | `shopkeeper_mountain` |
| Martha Miller | 2 (Thứ 3) | Market | `river_crossing` | — |
| Old Hanz | 3 (Thứ 4) | Forest walk | `forest_walk` | — |
| Young Voss | 4 (Thứ 5) | Night walk | `night_walk` | — |

**Marcus (NPC đặc biệt — không có trong FamilyRegistry):**

- Không thuộc family nào (intentional — cho narrative flexibility).
- Day 1: đứng trước cửa nhà player → auto-cutscene dialogue "neighbor".
- Sau intro: schedule `_schedule_in_farm` hoặc `_schedule_after_intro_to_town`.
- Quest giver cho dynamic delivery quests.
- Dynamic dialogue theo hotbar item khi có delivery quest active.

#### 3.4.3 Workflow (Family Succession)

```
[NPC dies (event chain outcome: DEAD)]
    ↓
[FamilyRegistry.mark_family_member_dead(npc_id, family_id)]
    ↓
[NPC là current_head?] ─No→ [Chỉ update status]
    ↓ Yes
[Tìm successor được chỉ định?]
    ↓         ↓
   Yes       No
    ↓         ↓
[Promote successor] [Promote alive_members[0]]
    ↓         ↓
[Set npc_X_new_head flag]
    ↓
[Set npc_X_succeeded_from flag]
    ↓
[Update family status → REDUCED hoặc EXTINCT]
    ↓
[GameState lưu flags]
```

#### 3.4.4 Ghi chú

- NPC pathfinding movement hiện là stub (`move_to`, `_on_path_complete` trong `npc.gd`)
  chưa wire với NavigationServer/AStar → Phase 3.
- 5 NPC scenes missing: `shopkeeper_father.tscn`, `shopkeeper_son.tscn`,
  `farmer_mother.tscn`, `farmer_daughter.tscn`, `hermit.tscn` → Phase 1.
- Dialogue Voss: `_grief` suffix khi family status = REDUCED
  (qua `FamilyRegistry.get_dialogue_for_current_head`).

---

### 3.5 Quest System

**Mục đích:** Định hướng player, tạo ra mục tiêu ngắn hạn, và kết nối player với
thế giới qua NPC interaction.

#### 3.5.1 Các thành phần

| Component | Script | Trạng thái |
|-----------|--------|-----------|
| QuestSystem | `scripts/autoload/quest_system.gd` | ✅ Implemented |
| QuestBoardUI | `scripts/world/quest_board_ui.gd` | ✅ Implemented |
| QuestBoard (Area2D) | `scripts/world/quest_board.gd` | ✅ Implemented |

#### 3.5.2 Quy tắc (Rules)

**Quest Types:**

```
Static quests  → Escort, Delivery, Investigation, Social (defined in code)
Dynamic quests → Delivery quests cho Marcus (generated on-demand)
```

**Static quests:** Pre-defined trong code, có固定的 dialogue và rewards.

**Dynamic delivery quests:** Generated qua
`QuestSystem.generate_delivery_quest_for_neighbor()` — yêu cầu player mang item
cụ thể đến Marcus. Item yêu cầu được random từ crop types.

#### 3.5.3 Workflow

```
[Player interact với QuestBoard]
    ↓
[QuestBoardUI loads]
    ↓
[QuestBoardUI reads quests từ quest_giver_npc_id]
    ↓
[Render quest list + Accept button]
    ↓
[Player accept quest]
    ↓
[Quest active trong QuestSystem]
    ↓
[Player complete quest: deliver correct item + hotbar selected]
    ↓
[Reward applied → gold + flags]
```

**Delivery quest flow (Marcus):**

```
[Player talk to Marcus → QuestSystem check]
    ↓
[Active delivery quest? + correct item on hotbar?]
    ↓         ↓
   Yes        No
    ↓         ↓
[neighbor_delivery dialogue] [neighbor_still_need dialogue]
    ↓
[Reward: gold + mark quest complete]
```

**Reject duplicate delivery:** Nếu player cố gắi deliver cùng item 2 lần →
`QuestBoardUI` reject + thông báo.

#### 3.5.4 Ghi chú

- Quest Board là Area2D trigger (không phải NPC).
- Quest state lưu trong GameState flags.
- Investigation/Social/Festival quests từ TODO.md chưa implement trong code hiện tại.

---

### 3.6 Risk Calculator & Event Chain System

**Mục đích:** Tạo ra consequences không thể đoán trước. Đây là engine của Pillar 5:
"Clear but unpredictable consequences."

#### 3.6.1 Các thành phần

| Component | Script | Trạng thái |
|-----------|--------|-----------|
| RiskCalculator | `scripts/autoload/risk_calculator.gd` | ✅ Implemented |
| EventChainEngine | `scripts/autoload/event_chain_engine.gd` | ✅ Implemented |
| EventManager | `scripts/autoload/event_manager.gd` | ✅ Implemented |
| WorldSimulator | `scripts/autoload/world_simulator.gd` | ✅ Implemented |
| CatchUpSystem | `scripts/autoload/catch_up_system.gd` | ✅ Implemented |

#### 3.6.2 Risk Modifiers

`RiskCalculator` tính risk score dựa trên:

- **Weather**: clear/rain/storm
- **Time of day**: đêm cao hơn ngày
- **NPC personality**: cautious (-), reckless (+), normal (=), old (?)
- **Escort presence**: có player hộ tống → giảm risk
- **Season**: theo `WeatherSystem`

#### 3.6.3 Event Chain Definitions

**3 chains đã define trong `EventChainEngine._build_chain_library()`:**

**`shopkeeper_mountain` — Chuyến đi núi của Old Voss**

| Property | Value |
|----------|-------|
| Trigger | `npc_schedule_mountain_day` (schedule-based) |
| Weather sensitive | Yes |
| Base risk | 0.0 |

Outcomes + weights:

| Outcome | Weight | Consequences |
|---------|--------|-------------|
| SAFE | 70% | None |
| DELAYED | 10% | `shop_late_open` |
| INJURED | 15% | `shopkeeper_injured`, `shop_closed_days` (2-4 ngày) |
| DEAD | 5% | `shopkeeper_dead`, `shop_closes`, `funeral_scheduled` (day+3), `son_takes_over` (day+3) |

Branches (conditional modifiers):

| Branch | Condition | Effect |
|--------|-----------|--------|
| `injured_player_escorted` | Player escorted | injured -8%, dead -3%, safe +11% |
| `injured_bad_weather` | Weather = storm | injured +15% |
| `dead_bad_weather` | Weather = heavy_rain | injured +20%, dead +20% |

Chain steps:

```
Step 0 (delay=0): npc_departed  → npc_leaves_home
Step 1 (delay=2): npc_ascending → npc_on_mountain
Step 2 (delay=5): outcome_resolved → resolve_outcome
Step 3 (delay=10): return_process → npc_returns_or_not
```

**`festival_day` — Ngày lễ hội làng**

| Outcome | Weight | Consequences |
|---------|--------|-------------|
| PROCEEDS | 65% | None |
| RAIN_CANCEL | 20% | `festival_cancelled`, `villagers_disappointed` |
| CANCELLED_MYSTERIOUS | 15% | `festival_cancelled_mystery`, `strange_events` |

**`harvest_blight` — Bệnh cây trồng**

| Outcome | Weight | Consequences |
|---------|--------|-------------|
| HEALTHY | 50% | None |
| PARTIAL_BLIGHT | 35% | `crops_reduced`, `food_shortage_warning` |
| TOTAL_BLIGHT | 15% | `crops_destroyed`, `food_shortage`, `villagers_leaving` |

#### 3.6.4 Outcome Enum

```
SAFE | INJURED | DEAD | MISSED | DELAYED
```

#### 3.6.5 Workflow (Chain Execution)

```
[Day boundary — NPCSchedules check]
    ↓
[NPC có scheduled activity hôm nay?]
    ↓         ↓
   Yes        No → [Normal day]
    ↓
[Chain trigger_condition met?]
    ↓         ↓
   Yes        No → [Normal activity]
    ↓
[EventChainEngine.trigger_chain(chain_id, context)]
    ↓
[Chain steps scheduled với delays]
    ↓
[Every game tick → _process_scheduled_events]
    ↓
[Delay reaches 0 → _execute_scheduled_event]
    ↓
[Step = "resolve_outcome" → _resolve_outcome]
    ↓
[Roll → cumulative weights → choose outcome]
    ↓
[Apply modifiers from active branches]
    ↓
[For each consequence → _apply_consequence]
    ↓
[Emit event → EventManager.trigger_event]
    ↓
[Update flags → GameState]
```

#### 3.6.6 Ghi chú

- **Gap critical:** `NPCSchedules` có schedule `shopkeeper_father` với `chain_id: "shopkeeper_mountain"`,
  nhưng không có code gọi `EventChainEngine.trigger_chain()` từ schedule trigger.
  Đây là Phase 4 task: wire schedule → chain trigger.
- `WorldSimulator` và `CatchUpSystem` xử lý world tick khi player offline
  (sleep/wake nhiều ngày).
- `strange_events` consequence trigger `WeatherSystem.trigger_anomaly_weather()` →
  weather bất thường sau mystery event.

---

### 3.7 Consequence Resolver

**Mục đích:** Bridge giữa abstract event outcomes và concrete world changes.
Không phải event chain tự thay đổi scene — `ConsequenceResolver` làm việc đó.

#### 3.7.1 Các thành phần

| Component | Script | Trạng thái |
|-----------|--------|-----------|
| ConsequenceResolver | `scripts/autoload/consequence_resolver.gd` | ✅ Implemented |

#### 3.7.2 Capabilities (Methods)

| Method | Chức năng |
|--------|-----------|
| `schedule_flag_change(flag, value, days_from_now)` | Set flag sau N ngày |
| `schedule_scene_change(scene_path, method, param, days_from_now)` | Gọi method trên scene sau N ngày |
| `schedule_family_succession(family_id, new_member_id, days_from_now, old_member_id)` | Trigger succession sau N ngày |
| `schedule_event(event_name, days_from_now)` | Emit event sau N ngày |
| `apply_consequence_set(consequences, chain_id, context)` | Dispatch nhiều consequences cùng lúc |
| `resolve_dialogue(dialogue_id)` | Return replacement dialogue nếu condition flag set |
| `register_dialogue_replacement(old, new, condition_flag)` | Đăng ký dialogue swap |
| `apply_world_state_summary(summary)` | Restore weather + flags từ summary |

**Consequence log:** `consequence_log: Array[Dictionary]` — ghi lại mọi consequence
đã apply (type, data, day, time).

#### 3.7.3 Đã wire (Hard-coded consequences)

| Consequence ID | Action |
|----------------|--------|
| `shop_closes` | `apply_scene_change("res://scenes/world/shop.tscn", "set_shop_state", "closed")` + flags |
| `shop_closed_days` | Set `shop_open = false`, schedule reopen sau 2-4 ngày |
| `shop_late_open` | Set `shop_late = true` |
| `funeral_scheduled` | Set `funeral_scheduled_day`, schedule event sau 3 ngày |
| `son_takes_over` | `schedule_family_succession` → Young Voss inherits |
| `food_shortage` | Set `food_shortage = true` + flag |
| `villagers_leaving` | Set `villagers_leaving = true` |
| `strange_events` | Set `strange_events_active = true` + `WeatherSystem.trigger_anomaly_weather()` |

#### 3.7.4 Ghi chú

- Missing `res://scenes/world/shop.tscn` → Phase 1.
- `apply_scene_change` gọi method trên scene instance đang loaded.
- Dialogue replacement system cho phép swap dialogue dựa trên condition flags
  (ví dụ: sau khi Voss chết, dialogue tự đổi từ normal → grief).

---

### 3.8 Player System

**Mục đích:** Avatar của người chơi. FSM rõ ràng, interaction system linh hoạt.

#### 3.8.1 Các thành phần

| Component | Script | Trạng thái |
|-----------|--------|-----------|
| Player scene | `scenes/Player.tscn` | ✅ Implemented |
| player.gd | `scripts/player/player.gd` | ✅ Implemented |

#### 3.8.2 Quy tắc (Rules)

**Player FSM States (enum trong player.gd):**

```
IDLE → WALKING/SPRINTING → IDLE
         ↓
     INTERACTING → (sau dialogue/action)
         ↓
     SLEEPING → IDLE (ngày mới)
         ↓
     DEAD (knockout) → SLEEPING
```

| State | Trigger | Exit condition |
|-------|---------|---------------|
| IDLE | Default | Movement input |
| WALKING | WASD movement | Stop input |
| SPRINTING | WASD + X key | Stop input / energy out |
| INTERACTING | E key on interactable | Action complete |
| SLEEPING | Bed interaction / force sleep | New day |
| DEAD | Energy = 0 | Auto-sleep after penalty |

**Interaction system:**

- **Raycast** cho world objects (farm plots, items)
- **Proximity** cho NPCs, beds, interactable objects
- Interaction prompt hiển thị qua `InteractionPromptManager`

**Warnings:**

- "It's late" warning qua `FloatingWarning` (trigger khi time gần midnight)
- AFK penalty từ `EnergyManager`

#### 3.8.3 Workflow (Movement & Sprint)

```
[Input: WASD]
    ↓
[Check current state]
    ↓
[IDLE/WALKING?] ──→ [Apply movement vector]
    ↓
[Sprint key held?] ──→ [Speed *= sprint_multiplier] → [Extra energy drain]
    ↓
[Check collision]
    ↓
[Update position]
```

#### 3.8.4 Ghi chú

- Sprinting có thể có extra energy drain (tuỳ implementation chi tiết trong EnergyManager).
- DEAD state = knockout, không phải death permanent.
- Player có thể sprint ngay cả khi low energy (speed vẫn 0.75× floor).

---

### 3.9 Persistence System

**Mục đích:** Game state tồn tại qua sessions. Player có thể đóng game và quay lại
đúng vị trí.

#### 3.9.1 Các thành phần

| Component | Script | Trạng thái |
|-----------|--------|-----------|
| SaveManager | `scripts/utils/save_manager.gd` | ✅ Implemented |
| GameState | `scripts/autoload/game_state.gd` | ✅ Implemented |
| FamilyRegistry.serialize_families | (in FamilyRegistry) | ✅ Implemented |

#### 3.9.2 Quy tắc (Rules)

**Format:** JSON

**Saved state:**

| Data | Nguồn |
|------|-------|
| Player state (gold, health, energy, day, time, inventory, toolbar) | `GameState` |
| World flags | `GameState` |
| NPC relationships | `GameState` |
| Farm cells | `FarmTickManager` |
| Family data | `FamilyRegistry.serialize_families()` |

**Save/Load flow:**
1. Player action → update GameState.
2. Save trigger (auto-save on day boundary / manual) → SaveManager.serialize().
3. Load → SaveManager.load() → restore to GameState + subsystems.

#### 3.9.3 Ghi chú

- Hiện chỉ có 1 save slot.
- Save slot UI chưa có → out of v3 scope.
- `SaveManager` log error khi corrupted, không crash.

---

### 3.10 Audio System

**Mục đích:** Tạo atmosphere. Hiện là placeholder — AudioManager broken.

#### 3.10.1 Các thành phần

| Component | Script | Trạng thái |
|-----------|--------|-----------|
| AudioManager | `scripts/autoload/audio_manager.gd` | ❌ Broken (TODO) |

#### 3.10.2 Ghi chú

- AudioManager đã đăng ký autoload nhưng handle missing files không graceful.
- Assets folder structure đã tạo trong Phase 1.
- Audio direction chưa defined (xem Open Questions §8).

---

## 4. Workflows & State Diagrams

Phần này trình bày workflows dạng text-based diagram cho các luồng quan trọng nhất.

### 4.1 Luồng ngày hoàn chỉnh (Complete Day Loop)

```
┌─────────────────────────────────────────────┐
│              NGÀY MỚI BẮT ĐẦU                │
│   Energy = max_energy                       │
│   FarmTickManager.day_boundary()             │
│   (cập nhật crop states, water tracking)    │
└────────────────────┬────────────────────────┘
                     ↓
┌─────────────────────────────────────────────┐
│          MORNING (6:00 - 12:00)             │
│                                             │
│  Farm: Plow → Seed → Water                  │
│  NPC Schedules active                        │
│  Marcus có thể xuất hiện (Day 1 intro)     │
│  Quest Board accessible                     │
└────────────────────┬────────────────────────┘
                     ↓
┌─────────────────────────────────────────────┐
│          AFTERNOON (12:00 - 18:00)          │
│                                             │
│  Tiếp tục farm / interact NPC               │
│  Shop open (nếu Old Voss còn sống)         │
│  Risk activities bắt đầu (Old Voss đi núi) │
└────────────────────┬────────────────────────┘
                     ↓
┌─────────────────────────────────────────────┐
│              EVENING (18:00 - 22:00)         │
│                                             │
│  "It's late" warning (FloatingWarning)       │
│  Energy cạn kiệt dần                       │
│  NPC schedules: về nhà                      │
│  Final harvest / shop visit                 │
└────────────────────┬────────────────────────┘
                     ↓
        ┌───────────┴───────────┐
        ↓                       ↓
   Energy > 0              Energy = 0
        ↓                       ↓
┌──────────────────┐  ┌────────────────────────┐
│ Player chọn ngủ  │  │ AUTO-SLEEP + PENALTY  │
│ (Bed interaction)│  │ 25% gold loss         │
└────────┬─────────┘  │ Energy reset          │
         ↓            └───────────┬────────────┘
┌──────────────────┐              ↓
│ NGÀY MỚI BẮT ĐẦU│  ┌──────────────────┐
│ (loop lại)       │  │ NGÀY MỚI BẮT ĐẦU│
└──────────────────┘  └──────────────────┘
```

### 4.2 Luồng Event Chain (Event Chain Flow)

```
┌─────────────────────────────────────────────┐
│         SCHEDULE TRIGGER (NPCSchedules)      │
│  Day boundary: kiểm tra day_of_week match    │
│  departure_time > current_time               │
│  → "Hôm nay NPC có scheduled activity"       │
└────────────────────┬────────────────────────┘
                     ↓
         ┌───────────┴───────────┐
         ↓                       ↓
   Trigger condition met    Trigger condition NOT met
   (e.g., Saturday)              ↓
         ↓              Normal NPC activity
   ┌─────┴─────┐
   ↓           ↓
EventChain.  Không làm
trigger_chain  gì cả
(chain_id,
 context)
   ↓
┌─────────────────────────────────────────────┐
│         CHAIN ACTIVE (EventChainEngine)      │
│                                             │
│  Steps scheduled với delays (game ticks)    │
│  _process() mỗi frame: countdown delays     │
│  Delay=0 → _execute_scheduled_event()        │
└────────────────────┬────────────────────────┘
                     ↓
┌─────────────────────────────────────────────┐
│         OUTCOME RESOLUTION (Step 2)           │
│                                             │
│  1. Lấy base weights từ chain definition    │
│  2. Apply branch modifiers (weather, escort) │
│  3. Normalize weights (tổng = 1.0)          │
│  4. Roll (randf()) → cumulative → outcome   │
└────────────────────┬────────────────────────┘
                     ↓
┌─────────────────────────────────────────────┐
│         APPLY CONSEQUENCES                    │
│                                             │
│  For each consequence_id:                   │
│    ConsequenceResolver._apply_consequence() │
│                                             │
│  → Set flags (GameState)                   │
│  → Call scene methods (ConsequenceResolver) │
│  → Trigger family succession                │
│  → Log to consequence_log                  │
└────────────────────┬────────────────────────┘
                     ↓
┌─────────────────────────────────────────────┐
│         WORLD STATE UPDATED                  │
│                                             │
│  Player thấy:                              │
│  - Shop đóng / mở                          │
│  - NPC mới xuất hiện / biến mất            │
│  - Dialogue thay đổi                       │
│  - Weather bất thường (strange_events)    │
└─────────────────────────────────────────────┘
```

### 4.3 Luồng Farming hoàn chỉnh (Complete Farming Loop)

```
┌─────────────────────────────────────────────┐
│         CHỌN SEED TỪ INVENTORY              │
│   Hotbar slot → select seed item            │
└────────────────────┬────────────────────────┘
                     ↓
┌─────────────────────────────────────────────┐
│         INTERACT VỚI FARM PLOT               │
│   Raycast → detect farm_plot.gd            │
│   Player presses E (interact)               │
└────────────────────┬────────────────────────┘
                     ↓
        ┌───────────┼───────────┐
        ↓           ↓           ↓
   EMPTY       PLOWED       (other)
        ↓           ↓
   [Plow]    [Plant Seed]
   → energy   → energy - seed
   → state    → state = SEEDED
   = PLOWED    → FarmTickManager
                 update cell
        ↓
┌─────────────────────────────────────────────┐
│         HẰNG NGÀY: WATERING                  │
│                                             │
│  Chọn water_can từ hotbar                   │
│  Interact với từng plot đã seed            │
│  → energy -= water_cost                     │
│  → growth += growth_per_water               │
│  → FarmTickManager.cell.water_days = 0     │
│                                             │
│  (Bỏ qua → water_days += 1 mỗi ngày)       │
│  (water_days >= water_need → WILTED)        │
└────────────────────┬────────────────────────┘
                     ↓
┌─────────────────────────────────────────────┐
│         DAY BOUNDARY (FarmTickManager)        │
│                                             │
│  Với mỗi cell:                             │
│  - Nếu SEEDED+ và water_days > 0:          │
│    water_days += 1                          │
│    Nếu water_days >= water_need:            │
│      state = WILTED                         │
│  - Nếu growth >= 1.0:                      │
│    state = MATURE                           │
└────────────────────┬────────────────────────┘
                     ↓
┌─────────────────────────────────────────────┐
│         HARVEST (khi MATURE)                 │
│                                             │
│  Interact với plot MATURE                   │
│  → spawn item (farm produce .tres)          │
│  → state = EMPTY                           │
│  → energy -= harvest_cost                  │
│  → Player inventory += item                 │
└─────────────────────────────────────────────┘
```

### 4.4 Luồng Dialogue & Delivery Quest (Marcus)

```
┌─────────────────────────────────────────────┐
│         PLAYER INTERACT VỚI MARCUS           │
│   Proximity trigger (Area2D)                │
│   Player presses E                          │
└────────────────────┬────────────────────────┘
                     ↓
┌─────────────────────────────────────────────┐
│         DIALOGUE TRIGGER (neighbor.gd)      │
│                                             │
│  Day 1, chưa gặp: → "neighbor" dialogue    │
│  Day ≥2, có delivery quest + đúng item:    │
│    → "neighbor_delivery"                   │
│  Day ≥2, có delivery quest + sai item:     │
│    → "neighbor_still_need"                 │
│  Day ≥2, không có quest:                    │
│    → "neighbor_day2_plus" / "neighbor_idle"│
└────────────────────┬────────────────────────┘
                     ↓
        ┌───────────┴───────────┐
        ↓                       ↓
  Delivery dialogue      Non-delivery dialogue
        ↓                       ↓
┌──────────────────┐  ┌──────────────────┐
│ Kiểm tra hotbar: │  │ Normal dialogue │
│ selected_item    │  │ playback        │
│ = quest item?    │  └────────┬─────────┘
└────────┬─────────┘           ↓
         ↓              ┌──────────────┐
   ┌─────┴─────┐        │ Dialogue     │
   ↓           ↓        │ finished     │
  Yes          No        └──────┬───────┘
   ↓           ↓               ↓
┌──────────────────┐  ┌────────────────┐
│ Quest complete   │  │ Dialogue ends  │
│ gold += reward   │  │ (no effect)   │
│ quest = complete │  └────────────────┘
│ Marcus reaction  │
└────────┬─────────┘
         ↓
┌─────────────────────────────────────────────┐
│         POST-DIALOGUE (neighbor.gd)          │
│                                             │
│  Day 1, gặp trước 11:00:                   │
│    → Set flag marcus_at_town_post_intro    │
│    → Schedule _schedule_after_intro_to_town│
│  Day 1, gặp sau 11:00:                     │
│    → Schedule _schedule_in_farm            │
│  Day ≥2:                                    │
│    → Generate new delivery quest?           │
│  → sync_all() → NPCManager sync            │
└─────────────────────────────────────────────┘
```

---

## 5. Implemented vs Roadmap

### 5.1 Đã implement (chạy được trong code)

- Time/Energy loop (max_energy=20, knockout 25% gold loss)
- Farm core (6 crops, 7 states, day-boundary logic, water tracking)
- Item system + shop (22 item .tres, SELL_PRICE_RATIO=0.5)
- 3 families với succession logic
- 4 NPC schedules (chưa trigger event chains — gap)
- Marcus NPC với Day-1 intro + dynamic delivery quests
- Quest System (static + dynamic)
- Consequence Resolver (flag/scene/family schedule + dialogue replacement)
- Save/Load JSON
- Dialogue UI, Shop UI, QuestBoard UI, Inventory, Hotbar, HUD

### 5.2 Đang làm (có code nhưng chưa hoàn chỉnh)

- **NPC pathfinding movement** — `npc.gd` có stub `move_to`, `_on_path_complete`,
  chưa wire NavigationServer/AStar
- **Missing NPC scenes** — 5 files chưa tạo: `shopkeeper_father.tscn`,
  `shopkeeper_son.tscn`, `farmer_mother.tscn`, `farmer_daughter.tscn`, `hermit.tscn`
- **Missing shop scene** — `res://scenes/world/shop.tscn` chưa có
- **AudioManager** — broken, cần fix handle missing files
- **Invalid UIDs** — nhiều `.tscn` references dùng UID không tồn tại
- **Schedule → Chain wiring** — `NPCSchedules` có schedule nhưng không trigger chain

### 5.3 Đã thiết kế, chưa implement (future)

- Romance/dialogue branches
- Dynamic weather tie-in với crop yield (storm → wilt nhanh hơn)
- Multiple endings
- Investigation/Social/Festival quests
- Mystery plant gameplay hook
- Soundtrack + SFX library

### 5.4 Không có trong v3 scope

- Multiplayer
- Save slot UI (1 slot hiện tại)
- Controller support
- Mobile/touch input

### 5.5 Roadmap 6 Phase

| Phase | Focus | Milestone |
|-------|-------|-----------|
| **1** | Cleanup tech debt | Fix UIDs, tạo missing scenes, restore AudioManager |
| **2** | Polish farming + energy loop | Crop art, energy UI feedback, late warning timing |
| **3** | NPC pathfinding + world tick | Wire npc.gd movement, hook world tick visible |
| **4** | Mystery content | Tune 3 event chains, dialogue unlocks, wire schedule→chain |
| **5** | Economy balancing + shop expansion | Sell price rebalance, thêm item, shop polish |
| **6** | Play-test + open alpha | Bug bash, balance pass, public build |

---

## 6. Edge Cases — Tình huống biên

| Scenario | Expected Behavior | Rationale |
|----------|-----------------|-----------|
| Energy = 0 mà chưa ngủ | AFK penalty (25% gold loss) → force sleep → ngày mới | Tránh soft-lock |
| Tất cả families EXTINCT | Game vẫn chạy nhưng shop không mở, một số quest không khả dụng | Narrative freedom |
| Save corrupted | `SaveManager` log error → không crash → load default | Defensive programming |
| NPC scheduled nhưng không có scene | Chain vẫn chạy, consequence applied; visual missing sau đó | Phase 1 fix sẽ thêm scenes |
| Quest accepted nhưng NPC holder chết | Quest auto-fail | `QuestSystem` đã handle |
| Delivery quest duplicate item | `QuestBoardUI` reject + thông báo | Tránh exploit |
| Mystery plant harvest | Thu hoạch cho `strange_fruit.tres` | Resource đã có, hook chưa rõ |
| Farm cell = WILTED | Player có thể phá bỏ hoặc bỏ | Không auto-remove |
| All crops MATURE + player không harvest | Crops stay MATURE | Không có decay sau MATURE |
| Player đi ngủ giữa ngày | Energy reset, day += 1, bỏ lỡ activities trong ngày | Hợp lệ nhưng suboptimal |

---

## 7. Tuning Knobs — Các thông số cân chỉnh

### 7.1 Energy System

| Parameter | Current | Safe Range | Increase → | Decrease → |
|-----------|---------|------------|------------|------------|
| `max_energy` | 20.0 | 15–30 | Làm được nhiều hơn mỗi ngày | Phải chọn lọc hơn |
| `LOW_ENERGY_THRESHOLD` | 5.0 | 3–8 | Ít bị slow | Slow sớm hơn |
| Knockout gold penalty | 25% | 10–50% | Penalty nặng hơn | Penalty nhẹ hơn |
| Sprint energy drain | (trong EnergyManager) | — | — | — |
| Farm action energy cost | (per action) | — | — | — |

### 7.2 Farming System

| Parameter | Current | Safe Range | Increase → | Decrease → |
|-----------|---------|------------|------------|------------|
| Water per water action (`growth_per_water`) | 0.20–0.25 | 0.10–0.40 | Crop lớn nhanh hơn | Crop chậm hơn |
| `water_need` (per crop) | 1–3 days | 1–5 | Crop dễ héo hơn | Crop bền hơn |
| Mystery plant `grow_days` | 10 | 7–21 | Mystery nhanh hơn | Mystery dài hơn |

### 7.3 Economy

| Parameter | Current | Safe Range | Increase → | Decrease → |
|-----------|---------|------------|------------|------------|
| `SELL_PRICE_RATIO` | 0.5 (50%) | 0.3–0.8 | Player giàu nhanh hơn | Player phải tiết kiệm hơn |

### 7.4 Event Chains

| Parameter | Current | Safe Range | Increase → | Decrease → |
|-----------|---------|------------|------------|------------|
| Dead weight (`shopkeeper_mountain`) | 5% | 1–15% | Dangerous hơn | Safer |
| Injured weight | 15% | 5–30% | Stakes cao hơn | Stakes thấp hơn |
| Safe weight | 70% | 50–85% | Predictable hơn | Unpredictable hơn |
| Weather modifier (injured) | +15% | 0–30% | Weather quan trọng hơn | Weather ít ảnh hưởng |
| Escort bonus (safe) | +11% | 0–20% | Player escort hữu ích hơn | Escort ít ảnh hưởng |

### 7.5 Quest System

| Parameter | Current | Safe Range |
|-----------|---------|------------|
| Delivery quest item reward | (per item) | — |
| Quest acceptance cooldown | (per NPC) | — |
| Max active quests | (per type) | — |

---

## 8. Open Questions — Câu hỏi mở

| # | Question | Owner | Deadline | Notes |
|---|----------|-------|----------|-------|
| 1 | Event Chain `shopkeeper_mountain` trigger ngày nào lần đầu? | TBD | Phase 4 | Hiện schedule có nhưng không trigger chain. Cần wire NPCSchedules → EventChainEngine. |
| 2 | Mystery plant (`strange_fruit`) gameplay hook là gì? | TBD | Phase 4 | Consumable? Quest item? Cursed? Cần design decision. |
| 3 | Romance vs friendship — tách track hay gộp? | TBD | Post-Phase 4 | Có thể implement sau khi quest system ổn định. |
| 4 | Audio direction — SFX library + soundtrack? | TBD | Phase 1 | AudioManager broken cần ưu tiên fix. Ambient cho farm? Horror stingers? |
| 5 | Hard-coded input action names trong `project.godot` (mouse_left/right có Vietnamese descriptions)? | TBD | Phase 1 | Cần rename để clean. |
| 6 | Hermit motivation + arc? | TBD | Phase 4 | Rất ít content hiện tại. Cần narrative design. |
| 7 | Localized text — i18n hay VN-only? | TBD | Post-Phase 6 | Dialogue hiện hard-coded Vietnamese trong JSON. |

---

## 9. Acceptance Criteria — Tiêu chí nghiệm thu

Các tiêu chí dưới đây xác nhận hệ thống hoạt động đúng thiết kế.

- [ ] Player có thể hoàn thành 1 farming cycle: Plow → Seed → Water → Harvest → Sell → Buy seeds → Repeat.
- [ ] Marcus xuất hiện trước cửa nhà player buổi sáng Day 1.
- [ ] Day-1 dialogue trigger khi player rời nhà (auto-cutscene hoặc interact).
- [ ] Quest Board hiển thị ít nhất 1 dynamic delivery quest cho Marcus sau Day 1.
- [ ] Delivery quest complete khi player có đúng item trên hotbar selected và interact Marcus.
- [ ] Energy = 0 → AFK penalty áp dụng (25% gold loss, reset energy, next day).
- [ ] Farm cells tiếp tục state changes khi player không ở farm map (FarmTickManager authoritative).
- [ ] Save/Load round-trip bảo toàn: energy, gold, day, time, inventory, toolbar, farm cells, family status.
- [ ] Old Voss schedule Saturday mountain trip (day_of_week=5, departure 7:00).
- [ ] Event chain `shopkeeper_mountain` trigger và apply consequences khi Old Voss đi núi.
- [ ] Shop đóng khi Old Voss INJURED (temporary) hoặc DEAD (permanent → Young Voss inherits).
- [ ] Dialogue Voss tự đổi sang `_grief` suffix khi family status = REDUCED.
- [ ] Mystery plant có thể trồng và thu hoạch thành `strange_fruit.tres`.
- [ ] "It's late" warning hiển thị khi time gần midnight.
- [ ] 5 missing NPC scenes được tạo và load không crash: shopkeeper_father, shopkeeper_son, farmer_mother, farmer_daughter, hermit.

---

## 10. Appendix — Chỉ mục file

### 10.1 Autoloads (30 singletons)

| # | Name | Script | Responsibility |
|---|------|--------|---------------|
| 1 | FarmEnums | `scripts/autoload/farm_enums.gd` | Crop state/type enums + water profiles |
| 2 | GameState | `scripts/autoload/game_state.gd` | Global state root |
| 3 | AudioManager | `scripts/autoload/audio_manager.gd` | Audio playback ⚠️ broken |
| 4 | CameraManager | `scripts/autoload/camera_manager.gd` | Camera control |
| 5 | DialogueManager | `scripts/autoload/dialogue_manager.gd` | Dialogue state + JSON loading |
| 6 | EventManager | `scripts/autoload/event_manager.gd` | Per-frame event dispatch |
| 7 | SceneManager | `scripts/autoload/scene_manager.gd` | Scene transitions |
| 8 | TimeManager | `scripts/autoload/time_manager.gd` | Day/night cycle |
| 9 | WeatherSystem | `scripts/autoload/weather_system.gd` | Weather + season |
| 10 | FamilyRegistry | `scripts/autoload/family_registry.gd` | 3 families, succession |
| 11 | NPCSchedules | `scripts/autoload/npc_schedules.gd` | NPC daily schedules |
| 12 | RiskCalculator | `scripts/autoload/risk_calculator.gd` | Risk modifier calculations |
| 13 | ConsequenceResolver | `scripts/autoload/consequence_resolver.gd` | Schedule flags/scenes/succession |
| 14 | EventChainEngine | `scripts/autoload/event_chain_engine.gd` | Event chain execution |
| 15 | WorldSimulator | `scripts/autoload/world_simulator.gd` | World tick management |
| 16 | CatchUpSystem | `scripts/autoload/catch_up_system.gd` | Offline time catch-up |
| 17 | QuestSystem | `scripts/autoload/quest_system.gd` | Quest lifecycle + generation |
| 18 | NPCManager | `scripts/autoload/npc_manager.gd` | NPC lifecycle |
| 19 | ItemManager | `scripts/autoload/item_manager.gd` | Item add/remove/transfer |
| 20 | ItemDB | `resources/items/item_database.gd` | Item resource loading |
| 21 | InteractionPromptManager | `scripts/autoload/interaction_prompt_manager.gd` | "Press E..." prompts |
| 22 | ItemHandler | `scripts/autoload/item_handler.gd` | Item use routing |
| 23 | ToolHandler | `scripts/autoload/tool_handler.gd` | Tool action routing |
| 24 | EnergyManager | `scripts/autoload/energy_manager.gd` | Energy consumption |
| 25 | EnergyBar | `scripts/ui/energy_bar.gd` | Energy UI ⚠️ UI đăng ký autoload |
| 26 | UIFocusManager | `scripts/autoload/ui_focus_manager.gd` | UI focus stack |
| 27 | FarmTickManager | `scripts/autoload/farm_tick_manager.gd` | Authoritative farm state |
| 28 | FloatingWarning | `scripts/autoload/floating_warning.gd` | Center-screen warnings |
| 29 | HotkeyInputManager | `scripts/ui/hotkey_input_manager.gd` | Hotkey handling ⚠️ UI đăng ký autoload |
| 30 | InputRouter | `scripts/autoload/input_router.gd` | Input dispatch |

> ⚠️ Note: `EnergyBar` và `HotkeyInputManager` là UI scripts được đăng ký như
> autoload (vì cần persistence qua scene changes). Xem xét refactor trong Phase 1.

### 10.2 Scripts (key files)

| System | Script |
|--------|--------|
| Player | `scripts/player/player.gd` |
| NPC base | `scripts/npc/npc.gd` |
| Marcus | `scripts/npc/neighbor.gd` |
| Shopkeeper | `scripts/npc/shopkeeper.gd` |
| Farm (scene) | `scripts/world/farm/farm_manager.gd` |
| Farm plot | `scripts/world/farm/farm_plot.gd` |
| Quest Board UI | `scripts/world/quest_board_ui.gd` |
| Shop UI | `scripts/ui/shop_ui.gd` |
| Inventory UI | `scripts/ui/inventory_ui.gd` |
| Hotbar | `scripts/ui/hotbar.gd` |
| Save/Load | `scripts/utils/save_manager.gd` |

### 10.3 Scenes

| Type | Files |
|------|-------|
| Maps | `inside_house_map.tscn`, `town_map.tscn`, `farm_map.tscn`, `marcus_farm_map.tscn`, `marcus_house_map.tscn`, `inside_shop_map.tscn`, `Farm_.tscn`, `farm_map_v2.tscn` |
| NPCs | `neighbor.tscn`, `shopkeeper.tscn` |
| Player | `Player.tscn` |
| UI | `dialogue_ui.tscn`, `shop_ui.tscn`, `inventory_ui.tscn`, `hotbar.tscn`, `energy_bar.tscn`, `clock_display.tscn`, `quest_board_ui.tscn`, `tooltip_panel.tscn` |
| World | `farm_plot.tscn`, `bed.tscn`, `quest_board.tscn`, `apple.tscn`, `crop_visual_manager.tscn` |

### 10.4 Item Resources (22 files)

```
resources/items/definitions/
├── seed_wheat.tres, seed_corn.tres, seed_tomato.tres,
│   seed_potato.tres, seed_turnip.tres
├── wheat.tres, corn.tres, tomato.tres, potato.tres,
│   turnip.tres, tomato_harvest.tres, corn_harvest.tres,
│   potato_harvest.tres, turnip_harvest.tres
├── health_potion.tres, apple.tres
├── hoe.tres, water_can.tres
├── old_key.tres, lore_fragment.tres, rope.tres, strange_fruit.tres
```

### 10.5 Cross-References

| Doc này tham chiếu | Đến | Element cụ thể | Nature |
|--------------------|------|----------------|--------|
| Energy values | `energy_manager.gd` | `max_energy`, `LOW_ENERGY_THRESHOLD` | Data dependency |
| Crop states | `farm_enums.gd` | `CropState`, `CropType` | Rule dependency |
| Family succession | `family_registry.gd` | `_on_member_death`, `_promote_successor` | Rule dependency |
| Event chain outcomes | `event_chain_engine.gd` | Outcome enum | State trigger |
| Consequence dispatch | `consequence_resolver.gd` | `apply_consequence_set` | State trigger |
| NPC dialogue | `resources/dialogue/*.json` | Per-NPC files | Data dependency |
| Item data | `resources/items/definitions/*.tres` | Per-item resources | Data dependency |
| Marcus sheet | [docs/characters/marcus.md](../characters/marcus.md) | Character sheet | Ownership handoff |
| Shopkeeper sheet | [docs/characters/shopkeeper-family.md](../characters/shopkeeper-family.md) | Character sheet | Ownership handoff |
| Hermit sheet | [docs/characters/hermit.md](../characters/hermit.md) | Character sheet | Ownership handoff |
| Old GDD (pillars) | [design/gdd/archive/farm-horror-gdd-2026-08-22.md](./archive/farm-horror-gdd-2026-08-22.md) | 5 pillars | Reference |
