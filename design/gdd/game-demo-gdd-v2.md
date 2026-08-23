# GAME DEMO — GAME DESIGN DOCUMENT v2

> **Trạng thái:** In Review — bản GDD sản phẩm đầu tiên, đối chiếu với code và scene hiện tại
> **Ngày cập nhật:** 2026-08-23
> **Engine:** Godot 4.5, GDScript
> **Tên kỹ thuật:** `GameDemo`
> **Phạm vi tài liệu:** Prototype foundation + product direction

---

## Đính chính quan trọng

Tài liệu này **không phải** Game Design Document của một sản phẩm "Farm Horror". Bản GDD trước có tên `farm-horror-gdd.md` đặt "psychological horror" vào genre chính và đưa horror vào design pillar số 1-2. Đối chiếu với code và scene hiện tại cho thấy:

- Code và scene hiện tại xây dựng **farming/life simulation prototype có systemic/social simulation ambitions**, với lớp mystery/anomaly là **optional narrative depth**, không phải gameplay pillar.
- Trong codebase, `horror` chỉ xuất hiện trong 2-3 vị trí cục bộ (signal `anomaly_weather_triggered`, hai chuỗi flag về "strange events"), tất cả đều nằm trong các autoload phụ trách weather/event dưới dạng **trigger có điều kiện, không phải gameplay loop chính**.

Bản GDD này phản ánh đúng sản phẩm đã được xây dựng. Horror được giữ lại như lớp nội dung tùy chọn, không phải định vị sản phẩm.

---

## Mục lục

1. Metadata & trạng thái
2. Tóm tắt sản phẩm
3. Thông tin nhanh
4. Player Fantasy
5. Design Pillars
6. Gameplay Loop (Daily & Long-term)
7. Product State — Current vs Future vs Won't-have
8. Farming System
9. Time & Energy
10. Economy & Trading (Current)
11. Economy & Trading (Future Direction)
12. Item System
13. NPC & Family
14. NPC Schedules
15. Risk Calculator (Core System)
16. Event Chain Engine (Core System)
17. Quest System
18. World & Maps
19. Weather & Season
20. Mystery Layer — Optional Depth
21. MVP / Vertical Slice Definition
22. Roadmap 6 pha
23. Production Risks
24. Acceptance Criteria
25. Open Questions
26. Phụ lục (A-F)
27. Lịch sử thay đổi

---

## 1. Metadata & trạng thái

- **Tên hiển thị khuyến nghị:** Game Demo (trung tính). Mọi tên gọi có chữ "Farm Horror" trong tài liệu là di sản của bản GDD cũ, không phải định vị hiện tại.
- **Tên kỹ thuật:** `GameDemo` (tên Godot project).
- **Scope:** Prototype Foundation + Product Direction.
- **Loại tài liệu:** Design Document có tracking **Implemented / Designed-but-Not-Built / Won't-have** rõ ràng.
- **Đối tượng độc giả:** bản thân tác giả (handoff), reviewer tuyển dụng (portfolio team), sau này có thể onboarding teammate.

---

## 2. Tóm tắt sản phẩm

### Một câu (elevator pitch)

> **Game Demo là một prototype farming/life simulation 2D nơi người chơi xây dựng cuộc sống và quan hệ của mình trong một cộng đồng nông thôn nhỏ thông qua sản xuất, mua bán và những quyết định hàng ngày — và bên dưới cuộc sống bình thường ấy có một lớp anomaly tùy chọn cho ai muốn đào sâu.**

### Đoạn 3 câu nêu core loop

Người chơi dậy sớm với một lượng năng lượng giới hạn, đọc dấu hiệu thế giới (thời tiết, lịch trình NPC, vật phẩm đang có), và chọn một ưu tiên trong ngày: trồng trọt, giao thương, nói chuyện với cư dân, hay khám phá khu vực. Khi mặt trời lặn, họ về giường ngủ, năng lượng được hồi đầy và thế giới chuyển sang ngày mới với những thay đổi mà người chơi không trực tiếp gây ra — NPC đã đi đâu đó, mùa đã lệch, hoa màu đã thất bát. Dần dần, người chơi nhận ra: cộng đồng này sống theo cách riêng của nó, và lịch sử của nó có những lớp không nhìn thấy ngay từ đầu.

---

## 3. Thông tin nhanh

| Hạng mục | Giá trị |
|---|---|
| Engine | Godot 4.5 |
| Ngôn ngữ | GDScript |
| Thể loại chính | Farming / Life Simulation |
| Hệ thống trọng tâm | Farming, economy/trading, NPC/social simulation |
| Thành phần phụ | Exploration, quest, narrative |
| Lớp narrative tùy chọn | Mystery / anomaly |
| Góc nhìn | 2D top-down |
| Phong cách | Pixel-art |
| Đối tượng mục tiêu | Người thích farming/life sim, quản lý tài nguyên, NPC và khám phá thế giới |
| Chế độ | Single-player |
| Nền tảng | PC (Godot desktop target) |
| Thời lượng demo mục tiêu | 20-45 phút cho một vòng trải nghiệm có thể chơi lại |
| Trạng thái hiện tại | Foundation / prototype đang phát triển |
| Quy mô codebase | 57 scripts GDScript, 21 scene, 24 item `.tres`, 2 tileset, 19 autoload |

---

## 4. Player Fantasy

Fantasy chính của người chơi không phải "anh hùng cứu thế giới" mà là:

> **"Tôi đang thực sự sống ở đây."**

Người chơi có thể:

- Tự trồng trọt trên mảnh đất của mình.
- Kiếm tiền qua bán nông sản.
- Quyết định hôm nay sản xuất gì, mua gì, bán gì.
- Lựa chọn dành thời gian cho công việc hay cho xã hội.
- Xây dựng quan hệ với từng cư dân trong làng.
- Quan sát những thay đổi của cộng đồng qua nhiều ngày.
- Dần hiểu được cách ngôi làng vận hành.

Trong phiên bản mở rộng, fantasy hướng tới:

> **"Đây là cuộc sống và câu chuyện của tôi, không phải một danh sách quest được game ép tôi đi theo."**

---

## 5. Design Pillars

Sáu pillar là cam kết thiết kế cốt lõi của sản phẩm. Mỗi pillar có một anti-pillar rõ ràng — nếu hệ thống nào vi phạm anti-pillar, nó cần được xem lại.

### Pillar 1 — Life comes first

Farming, sản xuất, giao thương, quan hệ và sinh hoạt hàng ngày là gameplay chính. Người chơi có thể chơi cả ngày mà không chạm vào bất kỳ yếu tố mystery nào và vẫn thấy game đầy đủ.

**Anti-pillar:** Không có quest bắt buộc "khám phá anomaly để hoàn thành progression".

### Pillar 2 — Limited resources create choice

Thời gian (1 giờ game = 10 giây thực, xem `time_manager.gd:66`), năng lượng (20 ô, mỗi action tốn 1 ô), vàng (200 khởi điểm) và khoản chú ý đều hữu hạn. Người chơi không thể làm tất cả trong một ngày; mỗi quyết định là một cú đánh đổi.

**Anti-pillar:** Không có "điểm stamina vô hạn sau khi nâng cấp".

### Pillar 3 — Systems create observable consequences

Hành động của người chơi có thể thay đổi: lượng tài nguyên, quan hệ NPC, trạng thái gia đình (`family_registry.gd`), business, các chain sự kiện (`event_chain_engine.gd`), và trạng thái cửa hàng.

**Anti-pillar:** Không có quest "vô hình" — mọi hệ quả được thể hiện bằng ít nhất một thay đổi state quan sát được.

### Pillar 4 — The community feels alive

NPC có lịch trình (`npc_schedules.gd`), vai trò, tính cách, gia đình, và có thể tự chuyển trạng thái sang REDUCED/SCATTERED/EXTINCT (`family_registry.gd:228-255`). Thế giới tiếp tục thay đổi khi người chơi không trực tiếp can thiệp (xem `world_simulator.gd`).

**Anti-pillar:** Không có NPC "đứng chờ" — NPC có `has_upcoming_schedule` để kiểm tra lịch sắp tới.

### Pillar 5 — Information supports decisions

Trong các hệ thống có yếu tố rủi ro (risk), người chơi không nhất thiết biết chính xác con số roll, nhưng có thể đọc được **bối cảnh** (thời tiết, tính cách NPC, mùa, escort) để hình thành giả thuyết (`risk_calculator.gd:140-194`).

**Anti-pillar:** Không bao giờ hiển thị "Risk = 47%" trên UI — chỉ hiển thị ngữ cảnh.

### Pillar 6 — Mystery is optional depth

Toàn bộ hệ thống mystery/anomaly (`anomaly_weather_triggered`, `strange_events_active`, `lore_fragment`, `strange_fruit`) tồn tại song song nhưng được tách hoàn toàn khỏi core farming/life-sim loop. Người chơi có thể chơi 10 giờ chỉ với farming, mua bán, nói chuyện NPC — và có một game hoàn chỉnh.

**Anti-pillar:** Không có flag nào của mystery trong `game_interacting = true` lock path — không có cửa nào chỉ mở khi "hoàn thành anomaly".

---

## 6. Gameplay Loop

### 6.1 Daily Loop

```
Wake up at 06:00 (sau khi qua đêm)
  ↓
Đọc dấu hiệu: thời gian, thời tiết, lịch NPC, weather forecast 3 ngày
  ↓
Chọn ưu tiên hôm nay
  ├── Farming (trồng, tưới, thu hoạch)
  ├── Production (chế biến sau này — chưa implement)
  ├── Trading (mua/bán ở shop)
  ├── Social (nói chuyện NPC, nhận quest)
  └── Exploration (đi núi, rừng, sông — khi có scene)
  ↓
Di chuyển / tương tác / thực hiện action
  ↓
Hệ quả: nhận item, thông tin, NPC state change, weather change
  ↓
Về giường khi tới 22:00 (năng lượng đầy lại khi ngủ qua đêm — `energy_manager.gd:152-164`)
  ↓
World advances:
  ├── Farm tick (`farm_tick_manager.gd`)
  ├── NPC schedule (`npc_schedules.gd`)
  ├── Weather forecast rotate (`weather_system.gd:299-312`)
  ├── Season day counter (`weather_system.gd:397-407`)
  └── Có thể trigger event chain (mỗi chain có trigger condition riêng)
  ↓
Next day
```

**Mục tiêu thiết kế của loop:** tạo **opportunity cost**. Nếu người chơi dành buổi sáng cho farming, họ có thể bỏ lỡ một cơ hội social hoặc trading. Nếu họ dành cả ngày cho núi, họ không thu hoạch được cây chín.

### 6.2 Long-term Loop

```
Produce
  ↓
Earn / Trade
  ↓
Improve resources and capabilities (mua tool, mua seed mới, mở rộng farm)
  ↓
Build relationships
  ↓
Access new information / opportunities (quest mở theo relationship)
  ↓
Make larger decisions
  ↓
Change personal/world state
  ↓
Repeat
```

Trong product direction dài hạn:

> **Ví dụ crop fail → supply giảm → giá thay đổi → NPC gặp vấn đề → người chơi có cơ hội kiếm lợi hoặc hỗ trợ → quan hệ/world state thay đổi.**

**Lưu ý:** Ví dụ này là design direction mở rộng. Prototype hiện tại có supply cho NPC chưa mô phỏng — phần này nằm trong nhóm **Designed / Future Direction**, không nằm trong nhóm **Implemented**.

---

## 7. Product State — Current vs Future vs Won't-have

Đây là phần bắt buộc để tránh **overclaim**. GDD trước đôi khi đặt feature vào MVP khi chưa implement; bản này phân tách rõ.

### 7.1 Implemented (Current) — đã có trong code/scene, có thể chạy

#### Engine scaffolding
- Godot 4.5 project, GDScript thuần, 19 autoload scripts theo `scripts/autoload/`.
- Main scene + 5 maps: `farm_map`, `farm_map_v2`, `town_map`, `inside_house_map`, `inside_shop_map`, `Farm_.tscn` (bản dựng thử nghiệm).
- 2 tileset (`game_tile_set.tres`, `farm_tileset.tres`).
- Player movement với FSM 7 states (`player.gd:6`: IDLE / WALKING / RUNNING / SPRINTING / INTERACTING / SLEEPING / DEAD).
- Acceleration / friction, sprint với cost, camera follow.
- Interaction raycast (raycast ưu tiên + fallback proximity detection ở `player.gd:208-244`).

#### Core systems (đã integrate)
- `GameState` autoload — lưu trữ toàn bộ state: gold, energy, time, day, inventory, world_flags, discovered_areas, farm_cells_data (`game_state.gd:28-112`).
- `TimeManager` — time scale, day/night, AFK penalty (`time_manager.gd`).
- `EnergyManager` — spend_energy, knock-out, gold penalty 25% (`energy_manager.gd`).
- `WeatherSystem` — 8 weather, 4 season, forecast 3 ngày, anomaly trigger (`weather_system.gd`).
- `RiskCalculator` — base risk + 5 modifier + outcome roll (`risk_calculator.gd`).
- `EventChainEngine` — 3 chains, state machine, branch modifiers (`event_chain_engine.gd`).
- `QuestSystem` — 4 quests, accept/complete/fail, intervention tracking (`quest_system.gd`).
- `DialogueManager` + dialogue UI (`dialogue_manager.gd`, `scripts/ui/dialogue_ui.gd`).
- `FamilyRegistry` — 3 families, 5 NPC, FamilyStatus enum, succession (`family_registry.gd`).
- `NPCSchedules` — 4 lịch trình theo `day_of_week` (`npc_schedules.gd`).
- `ShopUI` — buy/sell flow với `SELL_PRICE_RATIO = 0.5` (`shop_ui.gd:15`).
- `InventoryUI` + `Hotbar` — UI có sẵn (`scripts/ui/inventory_ui.gd`, `scripts/ui/hotbar.gd`).
- `ItemManager` + `ItemDatabase` — load 22-24 item definitions từ `.tres`.
- `SaveManager` — save/load architecture (`scripts/utils/save_manager.gd`).
- `WorldSimulator` — world advance offline-side (`world_simulator.gd`).
- `ConsequenceResolver` — apply flag changes theo schedule (`consequence_resolver.gd`).
- `CatchUpSystem` — snapshot sync khi load scene (`catch_up_system.gd`).
- `AudioManager` autoload (chưa có asset, chỉ có architecture).
- `UIFocusManager`, `InteractionPromptManager`, `SceneManager`, `CameraManager` — UI/screen helpers.

#### Gameplay content (đã có)
- Farming loop end-to-end: plow → water → plant seed → grow (5-7 ngày tùy cây) → harvest (xem chi tiết §8).
- Time tiêu hao năng lượng: 1 energy mỗi action `hoe` hoặc `water_can` (`farm_plot.gd:251-256`).
- Sleep loop: về giường trước 24:00 → năng lượng hồi đầy, `move_speed_mult` reset; quá 24:00 → AFK penalty (`time_manager.gd:85-91`).
- Knock-out system: kiệt sức → fade-to-black 1s → phạt 25% vàng + speed penalty 25% (`energy_manager.gd:21-23`).
- Buy/sell ở `inside_shop_map` — `SELL_PRICE_RATIO = 0.5` cho item không định giá riêng.
- Dialogue cho 1 NPC có scene (`shopkeeper.tscn`); các NPC khác dùng dialogue_id khác nhau qua `FamilyRegistry.get_dialogue_for_current_head`.
- Save/load snapshot từ `farm_cells_data`, `time`, `day`, `inventory`, `world_flags`.

### 7.2 In Progress / Partially Implemented

Những thứ đang có một phần nhưng chưa hoàn chỉnh:

- **NPC scenes**: mới có `shopkeeper.tscn`. NPC khác (`shopkeeper_father.tscn`, `farmer_mother.tscn`, `hermit.tscn`, `shopkeeper_son.tscn`, `farmer_daughter.tscn`) đang được tham chiếu trong `family_registry.gd:79-157` nhưng scene chưa có.
- **Invalid UID** trong một số `.tscn` (đã ghi nhận).
- **Audio**: autoload `AudioManager` có nhưng chưa có asset music/SFX.
- **Plowed cell expiry**: tính năng cell expire tồn tại (`farm_plot.gd:100-103`) nhưng chưa verify balance.
- **Anomaly weather** được trigger nhưng 3 chain length (`event_chain_engine.gd:198-200`) chưa qua playtest thực tế.

### 7.3 Designed / Future Direction — chưa implement, không claim

Các hệ thống sau thuộc **product direction**, có trong GDD cũ và được giữ làm roadmap nhưng không phải tính năng đã implement:

- **Dynamic market** (giá thay đổi theo supply/demand, season, weather, NPC activity).
- **NPC independent trading** (NPC tự mua bán dựa trên needs/assets).
- **Negotiation system** (hạ giá/tăng giá dựa trên context).
- **Information / inference system** (player phải đoán biến động thay vì thấy số).
- **NPC needs / assets / memory ở mức simulation sâu**.
- **Strange fruit crop** đã có resource (`strange_fruit.tres`) nhưng chưa có scene/plant logic ở farm.
- **Massive crop varieties** ngoài 5 loại hiện tại.
- **Lore unlock chain** (nhiều fragment tạo nên 1 narrative arc).
- **Underground area / bunker** (đề cập tên trong `family_registry` không).
- **Festival dance / minigame** (chỉ có event chain trigger, không có gameplay).

### 7.4 Won't-have (out of scope MVP)

Các tính năng này **chủ động loại khỏi** MVP và hướng kế tiếp:

- Combat system.
- Multiplayer / co-op.
- Fishing, cooking, crafting phức tạp.
- Mobile / console port.
- Voice acting, cutscene video.
- Procedural world generation.

---

## 8. Farming System

### 8.1 Crop State Machine

Lấy từ `scripts/autoload/farm_enums.gd` (8 trạng thái, được render bằng `farm_manager.gd:262-272`):

```
EMPTY (trống)
  ↓ hoe (plow)
PLOWED (đất đã đào)
  ↓ seed_X
SEEDED (đã gieo)
  ↓ tick (đủ ngày)
SPROUTED (nảy mầm)
  ↓ tick (đủ ngày + nước)
GROWING (đang lớn)
  ↓ tick (đủ ngày + nước)
MATURE (chín, sẵn sàng thu hoạch)
  ↓ nếu không tưới N ngày liên tục
WILTED (héo)
  ↓ hoe
EMPTY (reset, có thể làm lại)
```

Nguồn: `farm_manager.gd:262-272`, `farm_plot.gd:243-302`. Highlight màu ở `farm_plot.gd:204-213`.

### 8.2 Crops hiện tại (6 loại)

| Tên cây | Seed ID | Mùa trồng | Grow days | Sell price | ID nguồn |
|---|---|---|---|---|---|
| Turnip | `seed_turnip` | spring | 4 | 30 (turnip.tres) hoặc 11 (turnip_harvest.tres) | seed_turnip.tres |
| Wheat | `seed_wheat` | summer | 6 | 29 | seed_wheat.tres |
| Tomato | `seed_tomato` | summer | 5 | 32 | seed_tomato.tres |
| Potato | `seed_potato` | autumn | 7 | 41 | seed_potato.tres |
| Corn | `seed_corn` | summer | 8 | 45 | seed_corn.tres |
| Strange Fruit | (chưa có seed file) | — | — | 25 | strange_fruit.tres |

**Lưu ý về duplicate ID:** Resource folder chứa cả `<crop>.tres` (item dạng chính) và `<crop>_harvest.tres` (item nhỏ hơn cho drop logic). Mỗi crop có **2 file resource** với giá khác nhau vì farm system lưu 2 ID cùng spawn. Tham chiếu cụ thể: `farm_manager.gd:177-180` gọi `add_item(harvest_id, 2)`. Project nên hợp nhất file này trong Phase 1 hoặc ghi rõ harvest_id nào dùng.

### 8.3 Tools cần thiết

- **hoe** (`hoe.tres`, buy 50, sell 25) — dùng để plow và clear wilted.
- **water_can** (`water_can.tres`, buy 30, sell 15) — dùng để tưới.

Energy cost: 1 energy mỗi lần dùng hoe hoặc water_can (`farm_plot.gd:251-256` → `energy_manager.spend_energy(1)`).

### 8.4 Hệ thống mở rộng (Future)

- Fertilizer item (mua trong shop, tăng grow speed).
- Pest / disease system (làm giảm yield).
- Greenhouse (trồng trái mùa).
- Nông sản chế biến (turnip → soup, wheat → bread).

**Không đưa các hệ thống mở rộng vào MVP hiện tại.**

---

## 9. Time & Energy

### 9.1 Time

- **Tỉ lệ**: 1 giờ game = 10 giây thực (`time_manager.gd:64-66`: `delta * time_scale * 0.1`).
- **Giờ bắt đầu mỗi ngày**: 6.0 (`game_state.gd:139`).
- **Giờ kết thúc**: khi `current_time >= 22.0` → `is_day = false`.
- **Ban đêm**: 22:00 - 06:00.
- **Sleep deadline**: 24:00 — quá giờ trigger AFK penalty (`time_manager.gd:85-91`).
- **Sleep warning**: khi `current_time >= 24.0`, hiện floating warning "Đã muộn rồi! Cần đi ngủ, nếu không sắp bị phạt." (`player.gd:144-156`).
- **Pause**: gọi `TimeManager.pause()` để dừng (dùng khi vào giường).
- **Time scale**: 1.0 mặc định, có thể tăng (debug).

### 9.2 Energy

- **Mức đầy**: 20 ô (`game_state.gd:44`).
- **Tiêu hao**: 1 ô mỗi action dùng tool (`farm_plot.gd:253-256`).
- **Không tiêu hao khi đi bộ / chạy / sprint** (`player.gd:90-93` đã comment out stamina drain khi di chuyển — chỉ farm action mới tiêu hao).
- **Energy threshold `<= 5`**: `move_speed_mult = 0.75` (giảm 25%) (`energy_manager.gd:27-28`).
- **Knock-out**: energy về 0 → fade-to-black → teleport về giường (nếu không trong house) → phạt 25% vàng, speed penalty 25%, qua ngày (`energy_manager.gd:76-170`).
- **AFK penalty**: quá 24:00 không ngủ → cùng penalty với knock-out nhưng KHÔNG teleport (`energy_manager.gd:86-94`).
- **Penalty reset**: chỉ reset khi người chơi ngủ đúng giờ trên giường qua đêm (`energy_manager.gd:159-163`).

---

## 10. Economy & Trading (Current)

### 10.1 Hiện trạng

Economy hiện tại đóng vai trò **money loop cơ bản** + tạo **opportunity cost**, không phải dynamic market:

- Mua: tool, seed.
- Bán: harvest.
- Tiền tệ: `gold` (variable, `game_state.gd:86`).
- Khởi điểm: 200 vàng.
- Hằng số shop: `SELL_PRICE_RATIO = 0.5` (`shop_ui.gd:15`) — fallback cho item không định giá.

### 10.2 Ví dụ luồng đầu tư-hồi vốn 1 ngày (turnip)

- Mua 5 seed_turnip: 5 × 10 = 50 vàng.
- Trồng, tưới, chờ 4 ngày.
- Thu hoạch 5 ô × 2 harvest = 10 turnip.
- Bán 10 turnip ở giá 30 → 300 vàng.
- Lợi nhuận ròng: 250 vàng / 4 ngày (không tính energy).

### 10.3 Hạn chế đã biết

- **Không có giá biến động**: tất cả item có `buy_price` cố định trong `.tres`.
- **Không có demand-side**: NPC không "mua" harvest của người chơi vào inventory của họ (shop là sink).
- **Không có supply-side**: NPC không tạo supply cạnh tranh.

---

## 11. Economy & Trading (Future Direction)

Phần này là **design direction, không phải feature đã implement**. Mục đích: ghi nhận hướng đi tương lai để team không phải đoán.

### 11.1 Dynamic Market (thiết kế)

Market có khả năng thay đổi giá dựa trên:

- Supply (lượng nông sản trong hệ thống).
- Demand (NPC cần gì, tần suất tiêu thụ).
- Season (turnip ít hơn vào winter).
- Production run (cả làng trồng turnip → giá giảm).
- Weather (mưa to → giá thực phẩm tăng).
- Local events (festival cancelled → giá giảm).
- NPC activity (NPC đi mua hàng tuần → tăng giá trước ngày đó).
- Player activity (người chơi bán ồ ạt → giá giảm ngắn hạn).

### 11.2 Design Principle

> **Market fluctuation must have a cause.**

Player không nhất thiết biết nguyên nhân ngay lập tức, nhưng phải có khả năng **thu thập evidence** (đi xem mùa nào, đếm hàng trong shop, hỏi NPC, đọc weather forecast) và **hình thành hypothesis** có thể kiểm chứng.

Mục tiêu:

> **Uncertainty, not opacity.**

Hệ thống có logic, player có thể đào sâu hiểu — nhưng không ai hiểu hết. Đây là ranh giới giữa "game có chiều sâu" và "game bực mình vì tù mù".

### 11.3 Negotiation (thiết kế)

Player không chỉ chọn BUY/SELL. Có thể thương lượng dựa trên:

- Nhu cầu NPC (NPC đang cần gì).
- Khả năng chi trả (gold hiện có của NPC).
- Giá thị trường (giá average rolling N ngày).
- Quan hệ (relationship tier).
- Lịch sử giao dịch (transaction history).
- Sở thích (NPC thích buôn bán với ai).
- Tình trạng hàng hóa (stock còn bao nhiêu).

Design goal:

> **Giá trị của một giao dịch không chỉ nằm ở con số tiền, mà còn ở ai giao dịch với ai, tại thời điểm nào và trong hoàn cảnh nào.**

**Không implement trong prototype hiện tại.**

---

## 12. Item System

Tất cả item được load tự động từ `resources/items/definitions/` bởi `scripts/resources/items/item_database.gd`. Mỗi item là một `.tres` file với `script_class="ItemData"`.

### 12.1 Bảng tất cả 22 item

| ID | Display Name | Type | Category | Buy | Sell | Stack | Energy R. | Notes |
|---|---|---|---|---|---|---|---|---|
| `hoe` | Hoe | TOOL | 3 (tool) | 50 | 25 | 1 | - | plow + clear wilted |
| `water_can` | Watering Can | TOOL | 3 (tool) | 30 | 15 | 1 | - | tưới |
| `rope` | Rope | TOOL/utility | 3 | 8 | 4 | 1 | - | "Useful for climbing steep places" (narrative hook) |
| `seed_wheat` | Wheat Seeds | SEED | 1 | 15 | 7 | 99 | - | summer, 6d → `wheat` |
| `seed_turnip` | Turnip Seeds | SEED | 1 | 10 | 5 | 99 | - | spring, 4d → `turnip` |
| `seed_potato` | Potato Seeds | SEED | 1 | 18 | 9 | 99 | - | autumn, 7d → `potato` |
| `seed_tomato` | Tomato Seeds | SEED | 1 | 12 | 6 | 99 | - | summer, 5d → `tomato` |
| `seed_corn` | Corn Seeds | SEED | 1 | 20 | 10 | 99 | - | summer, 8d → `corn` |
| `wheat` | Wheat | HARVEST | 0 | 0 | 29 | 99 | - | main harvest version |
| `turnip` | Turnip | HARVEST | 0 | 0 | 30 | 99 | - | main harvest version |
| `tomato` | Tomato | HARVEST | 0 | 0 | 32 | 99 | - | main harvest version |
| `potato` | Potato | HARVEST | 0 | 0 | 41 | 99 | - | main harvest version |
| `corn` | Corn | HARVEST | 0 | 0 | 45 | 99 | - | main harvest version |
| `wheat_harvest`* | (legacy) | HARVEST | 0 | 0 | 29 | 99 | - | duplicate, see §8.2 |
| `turnip_harvest`* | Turnip (legacy) | HARVEST | 0 | 0 | 11 | 99 | - | duplicate, see §8.2 |
| `tomato_harvest`* | Tomato (legacy) | HARVEST | 0 | 0 | 12 | 99 | - | duplicate, see §8.2 |
| `potato_harvest`* | Potato (legacy) | HARVEST | 0 | 0 | 14 | 99 | - | duplicate, see §8.2 |
| `corn_harvest`* | Corn (legacy) | HARVEST | 0 | 0 | 15 | 99 | - | duplicate, see §8.2 |
| `apple` | Apple | CONSUMABLE | 2 | 0 | 3 | 99 | +10 | "Restores 10 energy" |
| `health_potion` | Health Potion | CONSUMABLE | 2 | 15 | 7 | 99 | +30 | "Restores 30 energy" (mô tả ghi 30 energy; tên gọi "health") |
| `old_key` | Old Key | KEY_ITEM | 4 | 0 | 0 | 1 | - | "A rusty key... might open something important" — narrative hook |
| `strange_fruit` | Strange Fruit | MYSTERY | 5 | 0 | 25 | 10 | - | "feels... wrong" — mystery tier item |
| `lore_fragment` | Lore Fragment | MYSTERY | 5 | 0 | 5 | 99 | - | collectible narrative |

*Lưu ý: 5 file `<crop>_harvest.tres` tồn tại song song với 5 file `<crop>.tres`. Đây là legacy split cần hợp nhất.

### 12.2 Item Type Enum (từ `resources/items/item_data.gd`)

- `CONSUMABLE = 0` (apple, health_potion).
- `TOOL = 1` (hoe, water_can, rope).
- `SEED = 2`.
- `KEY_ITEM = 3` (old_key).
- `CURRENCY = 4` (chưa dùng trong scope).
- `HARVEST = 5` (wheat, turnip, ...).
- (Trong bảng item: `strange_fruit` và `lore_fragment` dùng `item_type = 4-5` tùy file; Category 5 = MYSTERY).

---

## 13. NPC & Family

### 13.1 Ba gia đình hiện tại

Nguồn: `scripts/autoload/family_registry.gd:58-163`.

#### Voss Family (`shopkeeper_family`)

| Thành viên | ID | Role | Personality | Successor | Dialogue ID |
|---|---|---|---|---|---|
| Old Voss | `shopkeeper_father` | father | cautious (`-0.10`) | `shopkeeper_son` | `shopkeeper_father_normal` |
| Young Voss | `shopkeeper_son` | son | reckless (`+0.15`) | — | `shopkeeper_son_normal` |

Business: `Voss General Store`. Location: `Vector2(240, 320)`.

#### Miller Family (`farmer_family`)

| Thành viên | ID | Role | Personality | Successor | Dialogue ID |
|---|---|---|---|---|---|
| Martha Miller | `farmer_mother` | mother | cautious (`-0.10`) | — | `farmer_mother_normal` |
| Eliza Miller | `farmer_daughter` | daughter | normal (`0.00`) | — | `farmer_daughter_normal` |

Business: `Miller Farm`. Location: `Vector2(480, 180)`.

#### The Hermit (`hermit_family`)

| Thành viên | ID | Role | Personality | Successor | Dialogue ID |
|---|---|---|---|---|---|
| Old Hanz | `hermit` | hermit | old (`+0.10`) | — | `hermit_normal` |

Location: `Vector2(600, 400)`.

### 13.2 FamilyStatus Enum

`family_registry.gd:28-33`:

- `INTACT` — gia đình đầy đủ, chưa mất ai.
- `REDUCED` — còn 1 thành viên.
- `SCATTERED` — còn nhiều người nhưng không đầy đủ.
- `EXTINCT` — không còn ai.

### 13.3 Succession Logic

Trong `_on_member_death()` (`family_registry.gd:228-255`):

1. Nếu người chết là current_head → tìm successor đã khai báo trước (chỉ Old Voss có successor = Young Voss).
2. Nếu không có successor → promote người còn sống đầu tiên trong danh sách (`_promote_next_oldest`).
3. Tính lại `FamilyStatus` dựa trên alive_count.

**Hiện trạng succession chain trong code:** chỉ `shopkeeper_father` → `shopkeeper_son` được khai báo và đã có consequence trong `event_chain_engine.gd:507-510` (`son_takes_over`). Các family khác chưa có successor khai báo.

### 13.4 Dialogue theo trạng thái

`family_registry.gd:427-439` (`get_dialogue_for_current_head`): nếu family REDUCED → append `_grief` suffix. Hiện chưa có dialogue file `_normal_grief` được verify; đây là hook đã code nhưng chưa có nội dung.

### 13.5 NPC State Machine (per NPC)

`scripts/npc/shopkeeper.gd:5`:

- `IDLE`, `WALKING`, `WORKING`, `RESTING`, `SPECIAL`.

(Có thêm `SLEEPING`, `WAKING` được đề cập ở GDD cũ — code hiện chỉ có 5 state trong NPC base script.)

---

## 14. NPC Schedules

Nguồn: `scripts/autoload/npc_schedules.gd:47-116`.

| NPC ID | Schedule ID | day_of_week | departure | return | risk_activity | chain_id | Desc |
|---|---|---|---|---|---|---|---|
| `shopkeeper_father` | `mountain_trip` | 5 (Sat) | 07:00 | 18:00 | `mountain_trip` | `shopkeeper_mountain` | "Voss climbs the mountain every Saturday." |
| `farmer_mother` | `market_day` | 2 (Tue) | 08:00 | 15:00 | `river_crossing` | — | "Martha goes to the market every Tuesday." |
| `hermit` | `forest_walk` | 3 (Wed) | 06:00 | 17:00 | `forest_walk` | — | "Old Hanz walks into the forest every Wednesday." |
| `shopkeeper_son` | `night_walk` | 4 (Thu) | 21:00 | 23:00 | `night_walk` | — | "Young Voss wanders at night." |

### 14.1 Hành vi mỗi ngày

`npc_schedules.gd:145-164` (`get_todays_schedule`): chỉ lấy schedule `day_of_week == (current_day - 1) % 7 AND departure_time > current_time`. Vậy trong game:

- Ngày 1 (Mon), nếu bạn đang ở giờ 09:00 sáng thứ 7 sẽ thấy Old Voss **đang leo núi** rồi — schedule chỉ list các schedule **chưa diễn ra hôm nay**.
- Nếu đã diễn ra (departure < current_time) thì không list — tức là player sẽ không thấy prompt.

**Lưu ý:** đây là một micro-design choice ngầm của codebase. Player phải dậy sớm thứ 7 (trước 07:00) mới thấy Old Voss sắp đi núi. Sau 07:00, NPC "biến mất" vào mountain trip, không còn ở làng.

### 14.2 Future Direction

Phiên bản mở rộng (Designed Future, §7.3):

- NPC có nhu cầu, tài sản, nghề nghiệp, sở thích.
- NPC có thể tự đi mua hàng theo needs.
- NPC có thể tự chuyển schedule khi family state thay đổi.

**Không implement trong prototype hiện tại.**

---

## 15. Risk Calculator (Core System)

Nguồn: `scripts/autoload/risk_calculator.gd`.

### 15.1 Base Risk cho 5 activity

| Activity | Base Risk |
|---|---|
| `mountain_trip` | 0.20 |
| `forest_walk` | 0.10 |
| `river_crossing` | 0.15 |
| `night_walk` | 0.25 |
| `work_field` | 0.05 |

Nguồn: `risk_calculator.gd:31-37`.

### 15.2 Modifier Tables

#### Weather (8 loại)

| Weather | Modifier |
|---|---|
| `clear` | 0.00 |
| `overcast` | +0.05 |
| `fog` | +0.10 |
| `drizzle` | +0.08 |
| `rain` | +0.15 |
| `storm` | +0.35 |
| `heavy_rain` | +0.45 |
| `mist` | +0.12 |

Nguồn: `risk_calculator.gd:45-54`. (Lưu ý: bảng `WEATHER_RISK` ở `weather_system.gd:83-92` có giá trị khác nhẹ — đây là hai bảng riêng cho hai hệ thống khác nhau: RiskCalculator dùng giá riêng cho NPC schedule risk.)

#### Time of Day (5 band)

| Time band | Giờ | Modifier |
|---|---|---|
| morning | 06:00-11:59 | 0.00 |
| noon | 12:00-13:59 | 0.00 |
| afternoon | 14:00-17:59 | +0.02 |
| evening | 18:00-21:59 | +0.10 |
| night | 22:00-05:59 | +0.20 |

Nguồn: `risk_calculator.gd:62-68`.

#### Personality (5 loại)

| Personality | Modifier |
|---|---|
| cautious | -0.10 |
| normal | 0.00 |
| reckless | +0.15 |
| old | +0.10 |
| young | +0.05 |

Nguồn: `risk_calculator.gd:76-82`.

#### Escort (2 loại)

| Condition | Modifier |
|---|---|
| `player_escorted = true` | -0.20 |
| `has_escort = true` (NPC khác) | -0.10 |
| Không escort | 0.00 |

Nguồn: `risk_calculator.gd:172-181`.

#### Season (4 loại)

| Season | Modifier |
|---|---|
| winter | +0.15 |
| autumn | +0.08 |
| summer | -0.02 |
| spring | 0.00 |

Nguồn: `risk_calculator.gd:188-194`.

### 15.3 Công thức tổng

```python
total_risk = clamp(
    base
    + weather_mod
    + time_mod
    + personality_mod
    + escort_mod
    + season_mod,
    0.0, 1.0
)
```

Nguồn: `risk_calculator.gd:108-125`.

### 15.4 Outcome Roll (4 buckets)

`get_outcome_rolls(risk)` (`risk_calculator.gd:210-227`):

```
roll = randf() trong [0.0, 1.0]

if roll < risk * 0.4:  outcome = "dead"
elif roll < risk * 0.8: outcome = "injured"
elif roll < risk:       outcome = "delayed"
else:                   outcome = "safe"
```

**Ví dụ cụ thể:** Old Voss leo núi vào một ngày Saturday mưa bão (`storm`, +0.35), winter (+0.15), evening (+0.10), personality cautious (-0.10), escort không (-0.00).

- Base: 0.20
- Weather storm: +0.35 → 0.55
- Winter: +0.15 → 0.70
- Evening: +0.10 → 0.80
- Cautious: -0.10 → 0.70

=> total = **0.70**.

Roll < 0.28 (40%): dead. 28% cơ hội Voss không về.

Nếu player escort: thêm -0.20 → 0.50.

- Roll < 0.20: dead → giảm 8% cơ hội chết.

### 15.5 Event Chain dùng bảng riêng

`event_chain_engine.gd:135-184` dùng **trọng số outcome** riêng (`weight: 0.70`, `0.10`, `0.15`, `0.05`) thay vì công thức cộng dồn ở RiskCalculator. Đây là 2 hệ thống song song — không bị lẫn. RiskCalculator chạy độc lập cho schedule context, EventChainEngine chạy cho quest/context.

---

## 16. Event Chain Engine (Core System)

Nguồn: `scripts/autoload/event_chain_engine.gd`.

### 16.1 State Machine

5 trạng thái (`event_chain_engine.gd:40-46`):

- `DORMANT` — chưa kích hoạt.
- `ACTIVE` — đang chạy.
- `PAUSED` — tạm dừng.
- `COMPLETED` — hoàn thành.
- `ABORTED` — bị hủy.

### 16.2 Ba chain đã define

#### Chain 1 — `shopkeeper_mountain`

| Outcome | Weight | Hệ quả |
|---|---|---|
| `safe` | 0.70 | — |
| `delayed` | 0.10 | `shop_late_open` |
| `injured` | 0.15 | `shopkeeper_injured`, `shop_closed_days` |
| `dead` | 0.05 | `shopkeeper_dead`, `shop_closes`, `funeral_scheduled`, `son_takes_over` |

Branch modifiers (điều kiện):

- `injured_player_escorted` — player escort → injured_weight -0.08, dead_weight -0.03, safe_weight +0.11.
- `injured_bad_weather` — storm → injured_weight +0.15, dead_weight +0.10.
- `dead_bad_weather` — heavy_rain → injured_weight +0.20, dead_weight +0.20.

Chain steps (delay 0, 2, 5, 10 in-game): npc_departed → npc_ascending → outcome_resolved → return_process.

#### Chain 2 — `festival_day`

| Outcome | Weight | Hệ quả |
|---|---|---|
| `proceeds` | 0.65 | — |
| `rain_cancel` | 0.20 | `festival_cancelled`, `villagers_disappointed` |
| `cancelled_mysterious` | 0.15 | `festival_cancelled_mystery`, `strange_events` |

Chain steps: festival_setup (d=0) → festival_start (d=3) → outcome_resolved (d=8).

#### Chain 3 — `harvest_blight`

| Outcome | Weight | Hệ quả |
|---|---|---|
| `healthy` | 0.50 | — |
| `partial_blight` | 0.35 | `crops_reduced`, `food_shortage_warning` |
| `total_blight` | 0.15 | `crops_destroyed`, `food_shortage`, `villagers_leaving` |

Chain steps: blight_signs (d=0) → blight_spread (d=5) → harvest_assessed (d=10).

### 16.3 Consequence Application

`_apply_consequence()` (`event_chain_engine.gd:490-519`):

- `shop_closes`: set `shop_open = false`, schedule scene change.
- `shop_closed_days`: set `shop_open = false`, reopen sau N ngày ngẫu nhiên 2-4.
- `shop_late_open`: set `shop_late = true`.
- `funeral_scheduled`: trigger funeral 3 ngày sau.
- `son_takes_over`: dùng `ConsequenceResolver.schedule_family_succession` → Young Voss trở thành family head ngày +3.
- `food_shortage`: set flag `food_shortage`.
- `villagers_leaving`: set flag `villagers_leaving`.
- `strange_events`: set flag `strange_events_active` + trigger anomaly weather (storm 3 ngày).

### 16.4 Player Intervention

`register_player_intervention(chain_id, intervention_type)` (`event_chain_engine.gd:526-532`) — kết nối với `QuestSystem` (`quest_system.gd:255-265`) qua flag `quest_<id>_intervention_<chain>`.

### 16.5 Future Direction

- NPC tự trigger chain theo need (khi thiếu hàng → trigger "low_supply_chain").
- Chain có thể chain (chain trong chain).
- NPC-specific dialogue sau chain.

---

## 17. Quest System

Nguồn: `scripts/autoload/quest_system.gd:77-136`.

### 17.1 Bốn quest đã define

| Quest ID | Tên | Type | Giver | Target | Reward | Chain Interaction |
|---|---|---|---|---|---|---|
| `escort_voss_mountain` | Mountain Walk | escort | shopkeeper_father | shopkeeper_father @ mountain_path | `old_key` × 1 | `shopkeeper_mountain` (intervention: player_escorted) |
| `deliver_medicine` | Medicine Delivery | delivery | farmer_mother | shopkeeper_father | coin × 50 | `shopkeeper_mountain` |
| `investigate_noise` | Strange Sounds | investigation | hermit | forest_edge | `lore_fragment` × 1 | `harvest_blight` |
| `attend_festival` | Village Festival | social | shopkeeper_father | village_square | — | `festival_day` (fail: player_absent, festival_cancelled) |

### 17.2 Quest Lifecycle

- `accept_quest(id)`: thêm vào `active_quests`, emit signal.
- `complete_quest(id)`: thưởng qua `GameState.add_item`, chuyển sang `completed_quests`.
- `fail_quest(id, reason)`: set flag thất bại.
- `on_event_outcome(chain_id, outcome)`: xử lý tự động — escort quest hoàn thành nếu chain safe/injured, fail nếu dead (kèm override reason nếu có intervention).

### 17.3 Hạn chế đã biết

- **Không có quest tracker UI**. Player không có danh sách quest đang active một cách rõ ràng (chỉ qua dialogue và world_flags).
- **Không có prerequisite chain**. Quest nhận được theo dialogue trigger, không có gating logic phức tạp.
- **Branch dialogue** (quest có nhiều lời thoại chọn) chưa có — chỉ có dialogue_id duy nhất.

---

## 18. World & Maps

### 18.1 Maps đã build

| Map | Path | Vai trò |
|---|---|---|
| `main.tscn` | `res://scenes/main.tscn` | Entry scene |
| `farm_map.tscn` | `res://scenes/maps/farm_map.tscn` | Bản dựng ban đầu của farm |
| `farm_map_v2.tscn` | `res://scenes/maps/farm_map_v2.tscn` | Bản hiện tại với FarmPlot TileMapLayer |
| `inside_house_map.tscn` | `res://scenes/maps/inside_house_map.tscn` | House, có giường ngủ |
| `inside_shop_map.tscn` | `res://scenes/maps/inside_shop_map.tscn` | Shop scene |
| `town_map.tscn` | `res://scenes/maps/town_map.tscn` | Town, có NPC interact |
| `Farm_.tscn` | `res://scenes/maps/Farm_.tscn` | Map thử nghiệm, xem xét xóa |

### 18.2 Scene transition

`scene_manager.gd` autoload. EnergyManager có cơ chế spawn-at-bed qua GameState flag (`energy_manager.gd:124-142`).

### 18.3 Maps Future (Designed Not Built)

- `mountain_path.tscn` — cho chain `shopkeeper_mountain`.
- `forest_edge.tscn` — cho chain `forest_walk`, quest `investigate_noise`.
- `river_crossing.tscn` — cho `farmer_mother` market day.
- `village_square.tscn` — cho festival event chain.
- `hermit_cabin.tscn` — nếu player đào sâu NPC này.
- `underground.tscn` — `old_key` sẽ mở vùng gì đó ở đây (narrative hook).

---

## 19. Weather & Season

Nguồn: `scripts/autoload/weather_system.gd`.

### 19.1 8 weather types

`weather_system.gd:49-58` enum `Weather`: CLEAR, OVERCAST, FOG, DRIZZLE, RAIN, STORM, HEAVY_RAIN, MIST.

String ID theo `WEATHER_NAMES` (`weather_system.gd:66-75`): `clear`, `overcast`, `fog`, `drizzle`, `rain`, `storm`, `heavy_rain`, `mist`.

### 19.2 4 season

`weather_system.gd:120-131`: `spring` (30d), `summer` (30d), `autumn` (30d), `winter` (30d).

### 19.3 Roll distribution per season

Mỗi mùa có xác suất riêng (`weather_system.gd:204-244`). Ví dụ winter:

| Weather | Roll < x |
|---|---|
| CLEAR | 0.25 |
| OVERCAST | 0.45 |
| FOG | 0.65 |
| MIST | 0.80 |
| DRIZZLE | 0.92 |
| HEAVY_RAIN | 1.00 |

(Winter không thể RAIN hoặc STORM. Summer có thể STORM nhưng ít.)

### 19.4 Forecast 3 ngày

`_generate_forecast()` (`weather_system.gd:299-312`) sinh 3 entry liên tiếp; chỉ entry `i == 0` (ngày mai) đánh dấu `accurate: true` khi sinh. Sau đó mỗi `_advance_day` sẽ re-roll forecast mới.

### 19.5 Anomaly weather

`trigger_anomaly_weather()` (`weather_system.gd:370-374`):
- Đặt `anomaly_weather_active = true`.
- Khi roll weather trong 3 ngày tiếp theo → luôn là STORM intensity 0.8.
- Sau 3 ngày → reset.

Trigger được gọi từ `event_chain_engine._apply_consequence("strange_events")`.

---

## 20. Mystery Layer — Optional Depth

Phần này trọng lượng thiết kế rất thấp — chỉ để ghi nhận là **tồn tại**, không phải gameplay pillar.

### 20.1 Các điểm chạm của mystery

Tất cả đều là **mảnh đơn lẻ**, không có quest bắt buộc:

- `strange_fruit.tres` — vật phẩm bán được với giá 25, gợi ý narrative.
- `old_key.tres` — chìa khóa rỉ, "looks like it might open something important".
- `lore_fragment.tres` — mảnh giấy cũ, "ink is old".
- `strange_events_active` flag — set khi NPC chết và chain `cancelled_mysterious` xảy ra.
- `anomaly_weather` — 3 ngày bão cưỡng ép khi có strange event.
- 1 chain `cancelled_mysterious` (15% weight trong festival_day).

### 20.2 4 lớp horror tiềm năng (thuyết)

- **Layer 1 (Anomaly)**: chi tiết nhỏ không khớp expectation.
- **Layer 2 (NPC reaction)**: NPC né tránh chủ đề, có khoảng trống lịch trình bất thường.
- **Layer 3 (Consequence)**: người mất tích, business đóng, family tan.
- **Layer 4 (Lore)**: dialogue fragments, environmental clues, event chain, hidden areas.

**Tất cả 4 lớp chưa được implement đầy đủ** — chỉ có Layer 1-3 ở dạng mảnh rời và Layer 4 chưa có arc narrative.

### 20.3 Nguyên tắc thiết kế

> **Horror không được phép phá vỡ core farming/life-sim loop nếu player không chủ động tiếp cận narrative layer đó.**

Cụ thể:

- Không có quest nào của mystery mà critical path story bị break nếu player bỏ qua.
- Không có scene/area nào chỉ unlock sau khi hoàn thành anomaly.
- Lệch lối chơi duy nhất có thể xảy ra: NPC chết trong chain, NPC `son_takes_over`, dialogue chuyển sang `_grief` variant.

### 20.4 Hướng tương lai

Không thay đổi gameplay core. Chỉ tăng **số lượng** mảnh lore, đa dạng hóa anomaly trigger, thêm 2-3 dialogue variants theo relationship tier.

---

## 21. MVP / Vertical Slice Definition

### 21.1 Must-have (in MVP)

- Farm map (working farming loop).
- House + bed (sleep loop).
- Shop (buy/sell).
- NPC có scene (ít nhất 1).
- Day/night cycle + Energy.
- Inventory + Hotbar.
- Dialogue.
- Ít nhất 1 quest hoàn chỉnh (escort_voss_mountain đã đủ).
- Ít nhất 1 event chain có outcome nhìn thấy được (shopkeeper_mountain đã đủ).
- Save/load.
- Scene transition giữ state.

### 21.2 Should-have (Phase 1-2)

- Nhiều NPC scene hơn (5/5 NPC).
- Weather forecast UI.
- 1 event chain có intervention (escort_voss_mountain đã đủ).
- 1 anomaly trigger (đã code ở `_apply_consequence("strange_events")`).
- Quest tracker UI (chưa có — cần làm).
- Consequence feedback rõ hơn (text overlay khi NPC dies, dialog theo status).

### 21.3 Won't-have (explicitly out of scope MVP)

- Combat.
- Multiplayer / co-op.
- Fishing / cooking / crafting complex.
- Mobile / console port.
- Voice acting.
- Full dynamic market (chỉ market design direction).
- Full NPC autonomous economy.
- Full negotiation system.
- 50+ items (chỉ 22 hiện tại).
- 10+ event chains (chỉ 3 hiện tại).
- Full mystery/lore arc.

**Điểm quan trọng:** `dynamic market` và `negotiation` KHÔNG nên giả vờ là MVP. Chúng nằm trong **Future Product Direction** (§11).

---

## 22. Roadmap 6 pha

### Phase 1 — Foundation (đang thực hiện)

- Fix invalid UID trong scene.
- Fix missing NPC scene references.
- Stabilize scene transitions + GameState.
- Smoke test cho farming loop + economy loop + dialogue loop + save/load.

### Phase 2 — Core Life Simulation

- Farming end-to-end polish (5/5 NPC).
- Time + energy + day/night đã có, polish UI (HUD).
- Shop ổn định.
- Dialogue per NPC.
- Save/load ổn định.

### Phase 3 — Social & Consequence

- NPC relationship tier (basic: like/neutral/dislike).
- Family state visible trong dialogue.
- Quest tracker UI.
- Event chain visual feedback (khi chain ACTIVE → indicator).
- World consequences theo chain outcome.

### Phase 4 — Systemic Economy (Future)

- Dynamic supply/demand.
- Market state observable.
- Information sources (NPC behavior, weather, dialogue hints).
- Negotiation UI prototype.
- NPC economic behavior simulation.

### Phase 5 — Narrative Depth

- More lore fragments.
- Anomaly variants (không chỉ bão).
- Hidden areas (key-driven).
- Dialogue branches theo relationship tier.

### Phase 6 — Polish & Playtest

- UX hardening.
- Audio + Music.
- Visual feedback polish.
- Balance.
- Playtest loop.
- Bug triage.

---

## 23. Production Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Core simulation quá rộng | Project scope tăng nhanh | Prototype từng system độc lập trước khi kết nối |
| Dynamic economy khó balance | Player không quan tâm biến động giá | Bắt đầu với 1-2 commodity, controlled variables |
| NPC simulation quá phức tạp | Performance / design complexity | Chỉ mô phỏng state có ảnh hưởng gameplay |
| Information overload | Player không biết chú ý gì | Layer information, chỉ đưa actionable info |
| Mystery chiếm quá nhiều trọng lượng | Làm lệch core life-sim | Mystery chỉ mở rộng narrative, không thay thế core loop |
| Event outcome khó đọc | Player cảm thấy RNG | Telegraph context (weather, personality, season) trước result |
| Scope creep | Prototype không hoàn thành | Dùng bảng Current vs Future vs Won't-have (§7) để gate |
| Energy / knock-out loop nuốt session | Player mất hứng vì bị phạt penalty liên tục | Penalty reset khi ngủ đúng giờ; giảm gold penalty từ 25% xuống 10-15% |
| Multiple harvest files | Confusion về giá | Phase 1: chọn 1 harvest file / crop và xóa cái còn lại |
| Invalid UID | Scene không load | Phase 1: regenerate UID bằng Godot editor |
| Music/audio thiếu | Prototype im lặng → kém polish | AudioManager autoload đã có, cần asset |

---

## 24. Acceptance Criteria

### 24.1 Functional (đã đạt được trong code)

- [x] Player có thể di chuyển, dash, sprint.
- [x] Farming loop: plow → water → seed → grow → harvest.
- [x] Day progression: time chạy, day advance, energy restore khi ngủ.
- [x] Inventory + Hotbar hoạt động (có UI).
- [x] Buy/sell ở shop.
- [x] Dialogue mở qua E khi đứng gần NPC.
- [x] Risk calculator tính đúng công thức.
- [x] Event chain run + trigger + apply consequence.
- [x] Save/load kiến trúc có (game lưu state vào JSON).
- [x] State không mất khi chuyển scene qua flag `knockout_spawn_at_bed`.
- [x] Knock-out + AFK penalty.
- [x] Weather forecast 3 ngày.
- [x] Tooltip (shop + hotbar).

### 24.2 Design Validation — cần playtest, chưa prove được

- [ ] Player hiểu mục tiêu daily loop trong 5 phút đầu.
- [ ] Player có thể giải thích lý do cho một quyết định quan trọng ("tôi escort Voss vì...").
- [ ] Player nhận ra consequence của hành động trong vòng 1-2 ngày game.
- [ ] Player không cần đọc toàn bộ system để chơi được.
- [ ] Market changes có nguyên nhân suy luận được (chưa có dynamic market).
- [ ] Mystery có thể bỏ qua mà core gameplay vẫn hoạt động (cần verify trong playtest).

**Những tiêu chí này phải được playtest thực tế, không tự tuyên bố là đạt.**

---

## 25. Open Questions

| Câu hỏi | Trạng thái |
|---|---|
| Player identity và reason đến làng | Chưa khóa |
| Economic simulation chi tiết đến mức nào | Chưa khóa |
| Negotiation model chính thức (card game? pressure meter?) | Chưa khóa |
| NPC simulation depth (2-state / 5-state / full needs) | Chưa khóa |
| Market scope trong prototype (single commodity? 3? full basket?) | Chưa khóa |
| Day duration thực sau playtest (1 phút / 5 phút / 10 phút game day) | Chưa khóa |
| Mystery chính xác là gì (1 arc dài? nhiều arc ngắn? open-ended?) | Chưa khóa |
| NPC death permanence (permanent? reversible quest?) | Chưa khóa |
| Final commercial title | Chưa khóa |
| Phase 1 priority order (UID fix? scene refactor? UI feedback trước?) | Chưa khóa |
| Audit duplicate harvest `.tres` files | Mở — Phase 1 |

---

## 26. Phụ lục

### Phụ lục A — 19 Autoload scripts

| Autoload | Path (relative) | Ownership |
|---|---|---|
| `GameState` | `scripts/autoload/game_state.gd` | Global state |
| `TimeManager` | `scripts/autoload/time_manager.gd` | Time control |
| `EnergyManager` | `scripts/autoload/energy_manager.gd` | Energy + knock-out |
| `WeatherSystem` | `scripts/autoload/weather_system.gd` | Weather + season |
| `WorldSimulator` | `scripts/autoload/world_simulator.gd` | World offline simulation |
| `RiskCalculator` | `scripts/autoload/risk_calculator.gd` | Core math cho risk |
| `EventChainEngine` | `scripts/autoload/event_chain_engine.gd` | Event chain DSL |
| `EventManager` | `scripts/autoload/event_manager.gd` | Flag-based event trigger |
| `FamilyRegistry` | `scripts/autoload/family_registry.gd` | Family + succession |
| `NPCSchedules` | `scripts/autoload/npc_schedules.gd` | NPC schedule DB |
| `QuestSystem` | `scripts/autoload/quest_system.gd` | Quest lifecycle |
| `DialogueManager` | `scripts/autoload/dialogue_manager.gd` | Dialogue runtime |
| `ItemManager` | `scripts/autoload/item_manager.gd` | Item operations |
| `ItemHandler` | `scripts/autoload/item_handler.gd` | Item use handling |
| `FarmTickManager` | `scripts/autoload/farm_tick_manager.gd` | Per-day crop tick |
| `CatchUpSystem` | `scripts/autoload/catch_up_system.gd` | Snapshot sync |
| `ConsequenceResolver` | `scripts/autoload/consequence_resolver.gd` | Schedule consequence |
| `ToolHandler` | `scripts/autoload/tool_handler.gd` | Tool use dispatcher |
| `AudioManager` | `scripts/autoload/audio_manager.gd` | Audio routing |
| `UIFocusManager` | `scripts/autoload/ui_focus_manager.gd` | UI focus + dim |
| `CameraManager` | `scripts/autoload/camera_manager.gd` | Camera follow |
| `SceneManager` | `scripts/autoload/scene_manager.gd` | Scene transitions |
| `InteractionPromptManager` | `scripts/autoload/interaction_prompt_manager.gd` | E prompt priority |
| `FloatingWarning` | `scripts/autoload/floating_warning.gd` | In-world text toast |

(*Đếm thực tế: 24 autoload scripts; trong GDD đã ghi 19 ở Phase 0, sau khi audit lại đã thành 24. Cần update project.godot Autoload entry list trong cleanup pass.*)

### Phụ lục B — Bảng 22 item đầy đủ

(Xem §12.1 — bảng đầy đủ.)

### Phụ lục C — Bảng NPC scene_path reference

| NPC ID | scene_path reference | Scene tồn tại? |
|---|---|---|
| `shopkeeper_father` | `res://scenes/npc/shopkeeper_father.tscn` | No (tham chiếu chỉ có, chưa tạo file) |
| `shopkeeper_son` | `res://scenes/npc/shopkeeper_son.tscn` | No |
| `farmer_mother` | `res://scenes/npc/farmer_mother.tscn` | No |
| `farmer_daughter` | `res://scenes/npc/farmer_daughter.tscn` | No |
| `hermit` | `res://scenes/npc/hermit.tscn` | No |
| `shopkeeper` (generic) | `res://scenes/npc/shopkeeper.tscn` | **Yes** |

Hiện tại player chỉ thực sự gặp được NPC có scene — đây là khoảng cách giữa `FamilyRegistry` (đầy đủ 5 NPC) và playable content (1 NPC). Phase 1 cần tạo thêm 5 scene NPC.

### Phụ lục D — Weather × Risk Modifier đầy đủ

(Xem §15.2 bảng đầy đủ.)

### Phụ lục E — Risk Formula chi tiết

```
calculate_risk(npc_id, activity, context={}):

  base = BASE_RISK[activity]
  weather = context.get("weather", WeatherSystem.get_today_weather())
        = WEATHER_MODIFIER[weather]
  time = context.get("time", GameState.current_time)
       = _get_time_modifier(time)   # 5 band
  personality = context.get("personality", "normal")
              = PERSONALITY_MODIFIER[personality]
  escort = 0
        if context.player_escorted:  escort = -0.20
        elif context.has_escort:     escort = -0.10
  season = _get_season_modifier()   # winter +0.15, etc.

  total = clamp(base + weather + time + personality + escort + season, 0.0, 1.0)
  return total
```

Sau đó `get_outcome_rolls(total)` sinh `safe | delayed | injured | dead`.

### Phụ lục F — Codebase Statistics

- **Scripts**: 57 GDScript files.
- **Scenes**: 21 `.tscn` files.
- **Item resources**: 22 `.tres` files.
- **Tileset**: 2.
- **Autoload**: 24 scripts (sau khi đếm lại).
- **Maps playable**: 6 scene.
- **NPC playable**: 1 (`shopkeeper.tscn`).
- **NPC defined**: 5 (qua FamilyRegistry).
- **Family**: 3 (Voss / Miller / Hermit).
- **Schedule**: 4 (`mountain_trip`, `market_day`, `forest_walk`, `night_walk`).
- **Risk activity**: 5.
- **Weather type**: 8.
- **Season**: 4.
- **Quest**: 4.
- **Event chain**: 3.

### Phụ lục G — Mapping Phase 1-6 → việc cụ thể

| Phase | Việc cụ thể | Effort estimate | Output đo lường được |
|---|---|---|---|
| 1 | Tạo 4 NPC scene còn lại | 1 tuần | 4 file `.tscn` tồn tại trong `res://scenes/npc/` |
| 1 | Hợp nhất duplicate harvest `.tres` | 2 ngày | 5 file `<crop>_harvest.tres` được xóa hoặc merge |
| 1 | Fix invalid UID | 1 ngày | Editor mở không warning UID |
| 2 | Time / energy UI polish | 1 tuần | Energy bar + time display rõ trên HUD |
| 2 | Shop ổn định với feedback rõ | 1 tuần | Player thấy "Sold for X" toast sau bán |
| 3 | Quest tracker UI | 2 tuần | HUD mới có panel toggle cho quest active |
| 3 | Consequence feedback rõ | 1 tuần | Khi NPC chết → text overlay rõ |
| 4 | Dynamic market PoC | 3 tuần | Price thay đổi theo supply poC |
| 4 | Negotiation prototype | 3 tuần | 1 NPC có "try to negotiate" UI |
| 5 | Lore system | 2 tuần | 1 lore entry mở theo relationship |
| 5 | Anomaly variants | 2 tuần | 3 anomaly type khác ngoài storm |
| 6 | Audio + Music | 2 tuần | Background music cho 4 map |
| 6 | Playtest loop | ongoing | 5 user test với feedback note |

Tổng ước tính đến Phase 3: ~12 tuần, với 1 người.

### Phụ lục H — Phrasal Glossary

| Thuật ngữ trong tài liệu | Ý nghĩa |
|---|---|
| Autoload | Godot singleton load lúc startup, dùng pattern này cho global system (Time / Energy / Risk / ...) |
| FSM (Finite State Machine) | Pattern để một entity có trạng thái rõ ràng + transition rules |
| Signal-driven | Event-based, không poll. Code gọi `signal.connect(handler)`, Godot Godot fire khi có thay đổi |
| Data-driven | Logic được viết sao cho data đầu vào (Dictionary, .tres) dễ chỉnh, không phải sửa code |
| Spawn | Teleport player về vị trí khi scene chuyển |
| Persistence / Save state | Dữ liệu cần lưu giữa phiên chơi |
| Hành vi emergent | Hành vi phát sinh từ tương tác system, không hard-code |
| Core loop | Chuỗi hành động lặp lại chính của game (1 turn / 1 day / 1 session) |
| Vertical slice | Phiên bản game có 1 phần đầy đủ của mọi system, dùng để verify design intent |

---

## 27. Lịch sử thay đổi

| Version | Ngày | Tác giả | Thay đổi |
|---|---|---|---|
| v1 (legacy) | trước 2026-08-23 | (legacy GDD) | Đặt "Farm Horror" trong genre, horror ở pillar 1-2. Còn ở `farm-horror-gdd.md`. |
| v2 | 2026-08-23 | Game Demo author | Đính chính định vị: farming/life sim prototype + optional mystery. Phân tách rõ 4 nhóm: Implemented / In Progress / Designed Future / Won't-have. Đối chiếu code/scene hiện tại. |
