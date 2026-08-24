# Farm Horror Demo — Game Design Document (Bản Master)

> **SUPERSEDED by [GDD v3](../game-demo-gdd-v3.md) — 2026-08-24**
> Tài liệu này giữ lại làm tham khảo cho narrative design pillars (5 trụ cột) và vision horror ban đầu.
> Vui lòng tham khảo GDD v3 cho trạng thái hiện tại của game.
>
> **Trạng thái ban đầu:** In Review — bản master mở rộng đầy đủ, đối chiếu với code và scene hiện tại  
> **Ngày cập nhật ban đầu:** 2026-08-22  
> **Phiên bản tài liệu:** 2.0 (master rewrite)  
> **Engine:** Godot 4.5, GDScript  
> **Tên kỹ thuật dự án:** `GameDemo`  
> **Phạm vi tài liệu:** Toàn bộ demo nền tảng, tầm nhìn sản phẩm mở rộng, tài liệu tham chiếu cho contributor mới và pitch nội bộ

Tài liệu này là nguồn tham chiếu chính cho dự án. Khi code thay đổi, các mục "Trạng thái sản phẩm hiện tại", thông số, quest, event chain và acceptance criteria phải được cập nhật cho khớp.

---

## Mục lục

1. [Tóm tắt sản phẩm](#1-tóm-tắt-sản-phẩm)
2. [Định vị và thông tin nhanh](#2-định-vị-và-thông-tin-nhanh)
3. [Tầm nhìn, fantasy và design pillars](#3-tầm-nhìn-fantasy-và-design-pillars)
4. [Đối tượng người chơi và bối cảnh thị trường](#4-đối-tượng-người-chơi-và-bối-cảnh-thị-trường)
5. [Trạng thái sản phẩm hiện tại](#5-trạng-thái-sản-phẩm-hiện-tại)
6. [Hệ thống gameplay chi tiết](#6-hệ-thống-gameplay-chi-tiết)
7. [Thế giới và cấu trúc không gian](#7-thế-giới-và-cấu-trúc-không-gian)
8. [Hướng kể chuyện](#8-hướng-kể-chuyện)
9. [UI/UX và phản hồi](#9-uiux-và-phản-hồi)
10. [Art và audio direction](#10-art-và-audio-direction)
11. [Kiến trúc kỹ thuật](#11-kiến-trúc-kỹ-thuật)
12. [Phạm vi MVP / Vertical Slice](#12-phạm-vi-mvp--vertical-slice)
13. [Roadmap đề xuất](#13-roadmap-đề-xuất)
14. [Rủi ro sản xuất và quyết định cần theo dõi](#14-rủi-ro-sản-xuất-và-quyết-định-cần-theo-dõi)
15. [Acceptance criteria cho bản demo](#15-acceptance-criteria-cho-bản-demo)
16. [Open questions](#16-open-questions)
17. [Tài liệu và mã nguồn tham chiếu](#17-tài-liệu-và-mã-nguồn-tham-chiếu)
18. [Phụ lục](#18-phụ-lục)
19. [Lịch sử thay đổi](#19-lịch-sử-thay-đổi)

---

## 1. Tóm tắt sản phẩm

**Farm Horror Demo** là game 2D pixel-art kết hợp mô phỏng nông trại nhẹ (farming-lite), khám phá tường thuật (narrative exploration) và kinh dị tâm lý (psychological horror). Người chơi vào vai một người định cư mới đến một ngôi làng nông nghiệp hẻo lánh: làm đất, trồng cây, mua bán và trò chuyện với dân làng. Khi thời gian, thời tiết, lịch NPC và các sự kiện ngẫu nhiên chồng lên nhau, những chuyến đi nguy hiểm, mùa màng thất bại và các hiện tượng bất thường bắt đầu làm lộ mặt tối của cộng đồng.

Trải nghiệm cốt lõi **không dựa vào chiến đấu**. Căng thẳng đến từ ba áp lực cùng lúc:

- **Áp lực thời gian:** một ngày game chỉ có 16 giờ ban ngày và năng lượng giới hạn.
- **Áp lực xã hội:** NPC có lịch riêng, có thể chết, gia đình có thể tan vỡ và cửa hàng có thể đóng vĩnh viễn.
- **Áp lực ẩn dụ:** thế giới có những dấu hiệu "lệch" mà không ai giải thích, người chơi phải tự kết nối.

> **Một câu elevator pitch:** Một ngày bình thường ở nông trại có thể cứu một người, làm mất một mùa vụ, hoặc mở ra điều mà cả ngôi làng cố quên đi.

> **Tagline ngắn:** Bình thường trước. Bất an sau. Thế giới vẫn tiếp tục khi bạn ngủ.

---

## 2. Định vị và thông tin nhanh

| Hạng mục | Định nghĩa |
|---|---|
| Thể loại chính | Narrative exploration |
| Thể loại phụ | Farming-lite, psychological horror |
| Góc nhìn | 2D top-down |
| Phong cách hình ảnh | Pixel-art 16×16, viewport nội tại 320×180 integer-scale lên 1280×720 |
| Renderer | Forward Plus (Godot 4.5) |
| Người chơi mục tiêu | Người thích khám phá chậm, quản lý tài nguyên nhẹ, NPC có hậu quả, horror không jumpscare |
| Chế độ chơi | Single-player |
| Nền tảng mục tiêu | PC trước; console/mobile là backlog |
| Điều khiển hiện tại | WASD di chuyển, E tương tác, Shift sprint, Tab inventory |
| Thời lượng demo mục tiêu | 20–45 phút cho một vòng trải nghiệm có thể chơi lại |
| Trạng thái dự án | Phase 1 Foundation — đang phát triển; nhiều nội dung là hệ thống khung |
| Đội ngũ hiện tại | 1 người (solo developer với AI-assisted workflow) |
| Ngôn ngữ | Tiếng Việt trong code comment, tiếng Anh trong một số lore fragment |

---

## 3. Tầm nhìn, fantasy và design pillars

### 3.1 Player fantasy

Người chơi là một người sống sót/định cư mới trong một làng nông nghiệp hẻo lánh. Họ muốn có một cuộc sống ổn định, nhưng để tồn tại phải **đọc được dấu hiệu của thế giới**: ai đang nói dối, thời tiết đang báo trước điều gì, cây trồng nào đang héo bất thường và chuyến đi nào không nên thực hiện lúc trời tối.

Đây là fantasy về **sự tỉnh táo giữa thế giới tưởng bình thường**, không phải fantasy về anh hùng giết quái vật.

### 3.2 Năm design pillars

1. **Bình thường trước, bất an sau.** Việc tưới cây, ghé cửa hàng và nói chuyện phải đủ đời thường để biến những sai lệch nhỏ thành đáng sợ.
   - *Anti-pillar:* giật mình bằng jumpscare từ đầu, hoặc dùng cutscene giải thích ngay khi có dấu hiệu lạ.

2. **Horror được khám phá, không được giao tận tay.** Người chơi tự nối các mảnh lore, lịch NPC, thời tiết và hậu quả; game không giải thích mọi thứ bằng lời thoại trực tiếp.
   - *Anti-pillar:* NPC kể lại toàn bộ bí mật khi player click chuột phải; bản đồ đánh dấu sẵn các "điểm lore".

3. **Mỗi ngày là một ngân sách quyết định.** Thời gian, năng lượng, tiền và sự chú ý đều hữu hạn. Không thể làm mọi việc trong cùng một ngày.
   - *Anti-pillar:* cho phép player chạy khắp map và làm tất cả quest trong một ngày mà không có chi phí.

4. **Thế giới tiếp tục tồn tại khi người chơi vắng mặt.** NPC có lịch, gia đình có trạng thái, event chain có thể tiến triển và một cơ hội có thể bị bỏ lỡ.
   - *Anti-pillar:* NPC đứng yên tại chỗ như cột mốc, world chỉ tồn tại khi player quan sát.

5. **Hậu quả rõ ràng nhưng không luôn dễ đoán.** Người chơi cần hiểu vì sao rủi ro tăng, nhưng không được biết chắc kết quả của mọi biến cố.
   - *Anti-pillar:* dùng save/load để "fish" kết quả tốt; hiển thị % chiến thắng ngay trên UI.

### 3.3 Tham chiếu thiết kế

Các tựa game dùng làm benchmark tư duy (không phải benchmark thể loại):

| Tựa | Học được gì |
|---|---|
| *Stardew Valley* | Vòng lặp ngày chậm, NPC có lịch, farming không cần skill tree |
| *Darkwood* | Horror qua lệch nhịp, không jumpscare, resource management áp lực |
| *Dwarf Fortress* | Lịch NPC emergent, succession, world simulation khi player AFK |
| *Cultist Simulator* | Lore fragment, không giải thích trực tiếp |
| *Disco Elysium* | Dialogue dày, choice có hậu quả dài hạn |
| *Inscryption* | Không gian quen thuộc bị bẻ cong |

---

## 4. Đối tượng người chơi và bối cảnh thị trường

### 4.1 Persona chính

**Mai, 26 tuổi, kỹ sư phần mềm, thích khám phá chậm.**
- Đã chơi *Stardew Valley* và *Disco Elysium*, thích đọc lại dialogue để tìm manh mối.
- Chơi 1-2 giờ mỗi tối sau giờ làm, ghét grind, thích hệ thống có thể đọc hiểu trong 10 phút.
- Sẵn sàng bỏ cuộc nếu game không tôn trọng thời gian của cô ấy.

### 4.2 Persona phụ

**Anh Khoa, 31 tuổi, content creator indie game.**
- Tìm kiếm game nhỏ có narrative depth để làm video.
- Đánh giá cao sự trung thực về phạm vi (game nhỏ làm tốt > game lớn nửa vời).

### 4.3 Không phải đối tượng

- Người tìm action RPG hoặc combat nặng.
- Người cần feedback rõ ràng dạng "thắng/thua" trong vài phút.
- Người không chịu được game có tốc độ chậm.

---

## 5. Trạng thái sản phẩm hiện tại

Bảng dưới đây là snapshot ngày 2026-08-22, đối chiếu từ code (`scripts/`, `scenes/`, `resources/`) và tài liệu `TODO.md`.

### 5.1 Hệ thống đã có trong code

| Hệ thống | Trạng thái | File tham chiếu |
|---|---|---|
| Player controller | Hoàn chỉnh (FSM 7 state, 4 hướng, raycast + proximity) | `scripts/player/player.gd` |
| Time system | Hoàn chỉnh (1 giờ game ≈ 10 giây thực) | `scripts/autoload/time_manager.gd` |
| Weather & Season | Hoàn chỉnh (8 weather, 4 season × 30 ngày, anomaly) | `scripts/autoload/weather_system.gd` |
| Farming | Hoàn chỉnh logic (7 state, 6 crop type, water streak) | `scripts/world/farm/farm_manager.gd` |
| Item database | Prototype data (22 item resources) | `resources/items/definitions/*.tres` |
| Inventory & Hotbar | Hoàn chỉnh (16 slot, 3 hotbar) | `scripts/ui/inventory_ui.gd`, `scripts/ui/hotbar.gd` |
| Shop UI | Hoàn chỉnh (buy/sell tabs, 50% sell ratio) | `scripts/ui/shop_ui.gd` |
| Dialogue system | Hoàn chỉnh (JSON-driven, typewriter, choices) | `scripts/autoload/dialogue_manager.gd` |
| Family Registry | Hoàn chỉnh (3 family, 5 NPC, 4 status, succession) | `scripts/autoload/family_registry.gd` |
| NPC Schedules | Hoàn chỉnh (4 schedule entries, weekly) | `scripts/autoload/npc_schedules.gd` |
| Risk Calculator | Prototype utility (5 modifiers added to base risk, 4 outcome buckets) | `scripts/autoload/risk_calculator.gd` |
| Event Chain Engine | Hoàn chỉnh (3 chain, 5 state, 6 outcome enum) | `scripts/autoload/event_chain_engine.gd` |
| Quest System | Hoàn chỉnh (4 quest, accept/complete/fail) | `scripts/autoload/quest_system.gd` |
| World Simulator | Hoàn chỉnh (per-day tick) | `scripts/autoload/world_simulator.gd` |
| Catch-up System | Hoàn chỉnh (save migration) | `scripts/autoload/catch_up_system.gd` |
| Consequence Resolver | Hoàn chỉnh (flag change, scene override) | `scripts/autoload/consequence_resolver.gd` |
| Save/Load | Hoàn chỉnh (3 slot, JSON) | `scripts/utils/save_manager.gd` |
| Scene Manager | Hoàn chỉnh (portal, fade) | `scripts/autoload/scene_manager.gd` |
| Camera Manager | Hoàn chỉnh (shake, zoom, limits) | `scripts/autoload/camera_manager.gd` |
| Audio Manager | Code có, asset thiếu | `scripts/autoload/audio_manager.gd` |

### 5.2 Hệ thống chưa nên coi là hoàn chỉnh

| Hạng mục | Vấn đề | Tác động |
|---|---|---|
| 5 NPC scene files | File `shopkeeper_father.tscn`, `shopkeeper_son.tscn`, `farmer_mother.tscn`, `farmer_daughter.tscn`, `hermit.tscn` chưa tồn tại | FamilyRegistry tham chiếu scene_path, runtime sẽ lỗi khi vào khu vực tương ứng |
| 11 UID invalid | `inventory_ui`, `hotbar`, `tooltip_panel`, `dialogue_ui`, `bed`, `shop_ui`, `apple`, `shopkeeper`, `inside_shop_map`, `inside_house_map`, `town_map` cần regen UID | Có thể gây lỗi scene loading trong một số phiên bản Godot |
| Shop scene | `res://scenes/world/shop.tscn` thiếu nhưng `ConsequenceResolver` tham chiếu | Một số consequence không thể render được |
| Audio assets | Folder `assets/audio/{sfx,music,ambient}/` không tồn tại | AudioManager không phát được gì; không có feedback âm thanh |
| TileMap tileset | Một số scene chưa gắn TileSet | Visual thiếu nền cho map |
| Crop visual atlas | Hiện dùng Plants.png decor làm placeholder | Crop sprite không khớp hình dạng thật |
| Pause menu | Chưa có scene | Không thể save/load từ menu trong game |
| Main menu | Chưa có scene | Game khởi động thẳng vào main scene |
| Quest tracker UI | Chưa có | Player khó nhớ nhiều quest đồng thời |
| Test suite | Chưa có | Regression chỉ phát hiện qua playtest thủ công |

### 5.3 Số liệu tổng hợp

| Số liệu | Giá trị |
|---|---:|
| Tổng số file `.gd` | 47 |
| Tổng số autoload | 20 |
| Tổng số scene `.tscn` | 20 |
| Tổng số item resources `.tres` | 22 |
| Tổng số dialogue JSON | 3 |
| Tổng số NPC định nghĩa | 5 |
| Tổng số family | 3 |
| Tổng số quest | 4 |
| Tổng số event chain | 3 |
| Tổng số weather enum | 8 |
| Tổng số season | 4 |
| Số task trong TODO.md | 72 |
| Số task hoàn thành | 0 |

---

## 6. Hệ thống gameplay chi tiết

### 6.1 Player Controller

**FSM (Finite State Machine)** với 7 trạng thái:

```
IDLE → WALKING ⇄ RUNNING ⇄ SPRINTING
   ↓
INTERACTING ↔ IDLE
   ↓
SLEEPING / DEAD (terminal-ish)
```

| Thông số | Giá trị | Ghi chú |
|---|---:|---|
| `move_speed` | 100 | Đi bộ |
| `run_speed` | 180 | Chạy (giữ Tab trong input map hiện tại) |
| `sprint_speed` | 250 | Sprint (giữ Shift, tiêu hao energy) |
| `acceleration` | 800 | px/s² |
| `friction` | 1200 | px/s² |
| `interaction_range` | 80 | pixel |
| Energy drain (running/sprinting) | -delta × stamina_drain_rate × 0.3 | từ `GameState.stamina_drain_rate` |

**Thứ tự ưu tiên khi tương tác** (theo `_interact()` trong `player.gd`):

1. Raycast theo `facing_dir * 80px`
2. Fallback proximity tìm `Apple` (pickup)
3. Fallback proximity tìm `Bed`
4. Fallback proximity tìm NPC trong group `"npc"`
5. Fallback proximity tìm `Counter`

Khi `DialogueManager.is_active == true`, velocity được kéo về 0 bằng `friction` mỗi frame.

### 6.2 Time System

| Thông số | Giá trị |
|---|---:|
| Ngày bắt đầu | 1 |
| Giờ bắt đầu | 6:00 |
| Tỷ lệ thời gian | 1 giờ game ≈ 10 giây thực (mặc định `time_scale = 1.0`) |
| Ban ngày | 6:00 – 21:59 |
| Ban đêm | 22:00 – 5:59 |
| Reset khi sang ngày | Giờ về 6:00, energy hồi 100/100 |
| Công thức night | `hour >= 22` hoặc `hour < 6` |

**Time windows ảnh hưởng risk:**

| Window | Giờ | Time modifier |
|---|---|---:|
| morning | 6-11 | 0.00 |
| noon | 12-13 | 0.00 |
| afternoon | 14-17 | +0.02 |
| evening | 18-20 | +0.10 |
| night | 21-5 | +0.20 |

### 6.3 Energy System

| Thông số | Giá trị |
|---|---:|
| Energy max | 100 |
| Energy khởi đầu | 100/100 |
| Ngưỡng buộc ngủ | energy < threshold sau khi sprint/running |
| Hồi phục | 100% khi qua đêm (bed.sleep_requested) |
| Drain khi sprint | -delta × stamina_drain_rate × 0.3 |

Khi energy cạn, dialogue/UI cảnh báo và thiết kế đích đến là buộc player ngủ.

### 6.4 Farming System

Quản lý bởi `FarmManager` (`scripts/world/farm/farm_manager.gd`).

**CropState enum (7 trạng thái):**

```
EMPTY → PLOWED → SEEDED → SPROUTED → GROWING → MATURE
                                          ↓
                                       WILTED (nếu thiếu nước)
```

**CropType enum (6 loại):**

| ID | Tên | Seed item ID | Harvest item ID |
|---|---|---|---|
| `CropType.WHEAT` | Lúa mì | `seed_wheat` | `wheat` |
| `CropType.CORN` | Ngô | `seed_corn` | `corn` |
| `CropType.TOMATO` | Cà chua | `seed_tomato` | `tomato_harvest` |
| `CropType.POTATO` | Khoai tây | `seed_potato` | `potato_harvest` |
| `CropType.TURNIP` | Củ cải | `seed_turnip` | `turnip_harvest` |
| `CropType.MYSTERY_PLANT` | Cây bí ẩn | (chưa có seed) | `strange_fruit` |

**Water profile (per crop):**

| Crop | water_need (ngày) | growth_per_water | Số lần tưới để mature |
|---|---:|---:|---:|
| WHEAT | 2 | 0.25 | 4 |
| CORN | 1 | 0.20 | 5 |
| TOMATO | 1 | 0.20 | 5 |
| POTATO | 3 | 0.25 | 4 |
| TURNIP | 2 | 0.20 | 5 |
| MYSTERY_PLANT | 1 | 0.20 | 5 |

**Cơ chế wilt:**

- Mỗi ngày nếu không tưới, `unwatered_streak` tăng 1.
- Nếu `unwatered_streak > water_need` → `state = WILTED`, `wilting = true`.
- Ô WILTED phải dùng hoe (`clear_wilted_cell`) để quay về PLOWED trước khi gieo lại.

**Tile ID mapping (cho `FarmPlot` TileMapLayer):**

| State | Tile ID |
|---|---:|
| EMPTY | 0 |
| SOIL | 1 |
| PLOWED (chưa tưới) | 2 |
| WATERED (đã tưới hôm nay) | 3 |
| SEEDED | 4 |
| SPROUTED | 5 |
| GROWING | 6 |
| MATURE | 7 |
| WILTED | 8 |

### 6.5 Inventory, Item và Economy

**Item types (enum trong `item_data.gd`):**

- CONSUMABLE — dùng 1 lần
- TOOL — hoe, water_can
- SEED — gieo trồng
- KEY_ITEM — không bán
- CURRENCY — coin
- MISC — lore, fragment

**Item effects:**

- RESTORE_ENERGY, RESTORE_HEALTH
- WATER_CROPS, CLIMB
- GROW_CROP

**Thông số khởi đầu của player:**

| Tài nguyên | Giá trị |
|---|---:|
| Vàng | 100 |
| Máu | 100/100 |
| Năng lượng | 100/100 |
| Inventory slot | 16 (4×4) |
| Hotbar slot | 3 |

**Tham chiếu giá:**

| Item | Buy | Sell | Stack |
|---|---:|---:|---:|
| Hoe | 50 | 25 | 1 |
| Watering Can | 30 | 15 | 1 |
| Health Potion | 15 | 7 | 10 |
| Apple | 8 | 3 | 20 |
| Wheat seed/harvest | 5 / 8 | 3 / 4 | 20 |
| Corn seed/harvest | 8 / 12 | 4 / 6 | 20 |
| Tomato seed/harvest | 10 / 18 | 5 / 9 | 20 |
| Potato seed/harvest | 6 / 10 | 3 / 5 | 20 |
| Turnip seed/harvest | 4 / 7 | 2 / 3 | 20 |
| Rope | 20 | 10 | 5 |
| Lore Fragment | (không bán) | 5 | 99 |
| Strange Fruit | (không bán) | 25 | 10 |
| Old Key | (không bán) | (không bán) | 1 |

> Lưu ý: bảng giá tham chiếu, giá thực tế nằm trong `.tres` files tại `resources/items/definitions/`.

**Nguyên tắc kinh tế:**

- Mục tiêu: mua công cụ/hạt, biến năng suất farm thành khả năng khám phá, tạo chi phí cơ hội.
- Không dùng kinh tế để ép grind trong demo.
- Sell ratio mặc định: 50% buy price.

### 6.6 NPC, Dialogue và Family

**NPC FSM (7 trạng thái):** IDLE, WALKING, WORKING, RESTING, SPECIAL, SLEEPING, WAKING.

**Lịch mặc định:** 6:00 – 20:00 active, sau 20:00 SLEEPING.

**Bảng NPC đầy đủ (từ `FamilyRegistry`):**

| NPC ID | Tên hiển thị | Họ | Vai trò | Personality | Dialogue ID | Successor | Family |
|---|---|---|---|---|---|---|---|
| `shopkeeper_father` | Old Voss | Voss | Father, shop owner | cautious | `shopkeeper_father_normal` | `shopkeeper_son` | shopkeeper_family |
| `shopkeeper_son` | Young Voss | Voss | Son | reckless | `shopkeeper_son_normal` | (none) | shopkeeper_family |
| `farmer_mother` | Martha Miller | Miller | Mother, farmer | cautious | `farmer_mother_normal` | (next-oldest) | farmer_family |
| `farmer_daughter` | Eliza Miller | Miller | Daughter | normal | `farmer_daughter_normal` | (next-oldest) | farmer_family |
| `hermit` | Old Hanz | (none) | Hermit | old | `hermit_normal` | (none) | hermit_family |

**Family Status enum (4 trạng thái):**

```
INTACT  → REDUCED (1 alive)  → SCATTERED (nhiều alive, không đầy đủ)  → EXTINCT (0 alive)
```

**Cơ chế dialogue swap:**

Khi family status = REDUCED, `get_dialogue_for_current_head()` tự động trả về `<dialogue_id>_grief`. Đây là cách game thể hiện tang chế mà không cần cutscene.

**Family business status:**

`is_business_operational(family_id)` kiểm tra `current_head.alive == true`. Khi head chết:
- Nếu có `successor` → `_promote_successor()` sau 3 ngày (qua `ConsequenceResolver`).
- Nếu không → `_promote_next_oldest()` lấy alive_members[0].

### 6.7 Risk & Consequence Engine

Đây là hệ thống cốt lõi của demo. Định nghĩa nguyên văn trong `scripts/autoload/risk_calculator.gd`.

**Công thức tổng:**

```
total_risk = clampf(
    base_risk
    + weather_modifier
    + time_modifier
    + personality_modifier
    + escort_modifier
    + season_modifier,
    0.0, 1.0
)
```

**BASE_RISK theo hoạt động:**

| Activity | Base risk |
|---|---:|
| `mountain_trip` | 0.20 |
| `forest_walk` | 0.10 |
| `river_crossing` | 0.15 |
| `night_walk` | 0.25 |
| `work_field` | 0.05 |

**WEATHER_MODIFIER (theo `WeatherSystem`):**

| Weather | Modifier |
|---|---:|
| clear | 0.00 |
| overcast | +0.05 |
| fog | +0.10 |
| drizzle | +0.08 |
| rain | +0.15 |
| storm | +0.35 |
| heavy_rain | +0.45 |
| mist | +0.12 |

**TIME_MODIFIER (tính từ `current_time`):**

| Window | Modifier |
|---|---:|
| morning (6-11) | 0.00 |
| noon (12-13) | 0.00 |
| afternoon (14-17) | +0.02 |
| evening (18-20) | +0.10 |
| night (21-5) | +0.20 |

**PERSONALITY_MODIFIER:**

| Personality | Modifier |
|---|---:|
| cautious | -0.10 |
| normal | 0.00 |
| reckless | +0.15 |
| old | +0.10 |
| young | +0.05 |

**ESCORT_MODIFIER:**

| Điều kiện | Modifier |
|---|---:|
| Player escort (`context.player_escorted = true`) | -0.20 |
| Other escort (`context.has_escort = true`) | -0.10 |
| Không escort | 0.00 |

**SEASON_MODIFIER (từ `WeatherSystem.current_season`):**

| Season | Modifier |
|---|---:|
| winter | +0.15 |
| autumn | +0.08 |
| summer | -0.02 |
| spring | 0.00 |

**Outcome roll (`get_outcome_rolls(risk)`):**

```python
roll = randf()
if   roll < risk * 0.4: outcome = "dead"
elif roll < risk * 0.8: outcome = "injured"
elif roll < risk:       outcome = "delayed"
else:                   outcome = "safe"
```

**Ví dụ tính:**

Mountain trip vào chiều thứ 7 mùa đông, trời bão, NPC old, có player escort:

```
base (0.20) + storm (0.35) + afternoon (0.02) + old (0.10) + escort (-0.20) + winter (0.15)
= 0.62 → clamp → 0.62
```

Roll < 0.248 = dead, < 0.496 = injured, < 0.62 = delayed, ≥ 0.62 = safe.

### 6.8 Event Chain Engine

State machine 5 trạng thái:

```
DORMANT → ACTIVE → COMPLETED
            ↓
         PAUSED → ACTIVE
            ↓
         ABORTED
```

**Outcome enum (6 giá trị):** NONE, SAFE, INJURED, DEAD, MISSED, DELAYED.

**Công thức outcome resolve:**

1. Lấy `outcomes[key].weight` từ chain definition.
2. Áp dụng `branches[branch_id].modifiers` nếu điều kiện khớp.
3. Normalize weights về tổng = 1.0.
4. `roll = randf()`, cumulative sum → chọn outcome.

**3 chain hiện tại:**

#### Chain 1: `shopkeeper_mountain` — Shopkeeper's Mountain Trip

| Trigger | `npc_schedule_mountain_day` (mỗi thứ 7) |
|---|---|
| Weather sensitive | Có |
| Base risk | 0.0 (tính qua `RiskCalculator`) |
| Step delays | 0, 2, 5, 10 ngày |

| Outcome | Weight | Consequence IDs |
|---|---:|---|
| `safe` | 0.70 | (none) |
| `delayed` | 0.10 | `shop_late_open` |
| `injured` | 0.15 | `shopkeeper_injured`, `shop_closed_days` |
| `dead` | 0.05 | `shopkeeper_dead`, `shop_closes`, `funeral_scheduled`, `son_takes_over` |

**Branch modifiers:**

| Branch | Condition | Effect |
|---|---|---|
| `injured_player_escorted` | `player_escorted` | injured -0.08, dead -0.03, safe +0.11 |
| `injured_bad_weather` | `weather_storm` | injured +0.15, dead +0.10 |
| `dead_bad_weather` | `weather_heavy_rain` | injured +0.20, dead +0.20 |

#### Chain 2: `festival_day` — Village Festival

| Trigger | `calendar_festival_day` (mỗi 7 ngày theo `WorldSimulator`) |
|---|---|
| Weather sensitive | Có |
| Step delays | 0, 3, 8 ngày |

| Outcome | Weight | Consequence IDs |
|---|---:|---|
| `proceeds` | 0.65 | (none) |
| `rain_cancel` | 0.20 | `festival_cancelled`, `villagers_disappointed` |
| `cancelled_mysterious` | 0.15 | `festival_cancelled_mystery`, `strange_events` |

**Hệ quả đặc biệt:** `strange_events` trigger `WeatherSystem.trigger_anomaly_weather()` → ép bão 3 ngày liên tiếp.

#### Chain 3: `harvest_blight` — Crop Blight

| Trigger | `season_autumn_approaching` (chuyển mùa thu) |
|---|---|
| Weather sensitive | Không |
| Step delays | 0, 5, 10 ngày |

| Outcome | Weight | Consequence IDs |
|---|---:|---|
| `healthy` | 0.50 | (none) |
| `partial_blight` | 0.35 | `crops_reduced`, `food_shortage_warning` |
| `total_blight` | 0.15 | `crops_destroyed`, `food_shortage`, `villagers_leaving` |

### 6.9 Quest System

**4 quest định nghĩa:**

| Quest ID | Tên | Type | Giver | Target NPC | Reward | Chain | Fail conditions |
|---|---|---|---|---|---|---|---|
| `escort_voss_mountain` | Mountain Walk | escort | shopkeeper_father | shopkeeper_father | `{item: old_key, amount: 1}` | shopkeeper_mountain | npc_died_without_player |
| `deliver_medicine` | Medicine Delivery | delivery | farmer_mother | shopkeeper_father | `{item: coin, amount: 50}` | shopkeeper_mountain | (none) |
| `investigate_noise` | Strange Sounds | investigation | hermit | (forest_edge) | `{item: lore_fragment, amount: 1}` | harvest_blight | (none) |
| `attend_festival` | Village Festival | social | shopkeeper_father | (village_square) | (none) | festival_day | player_absent, festival_cancelled |

**Lifecycle:**

```
accept_quest → active → complete_quest | fail_quest
                          ↓                ↓
                       completed       failed (có lý do lưu flag)
```

**Intervention system:**

Khi player `accept_quest` có `intervention_effect`, system ghi nhận flag `quest_<id>_intervention_<chain_id>`. Chain engine đọc flag này qua context để áp dụng branch modifiers.

### 6.10 Weather & Season

**8 weather enum** (xem 6.7 cho risk modifier).

**4 season × 30 ngày:**

| Season | Day length | Đặc trưng thời tiết |
|---|---:|---|
| spring | 30 | 35% clear, nhiều rain/storm |
| summer | 30 | 45% clear, ít mưa |
| autumn | 30 | fog/drizzle/rain/storm phân bố đều |
| winter | 30 | clear 25%, nhiều fog/mist/heavy_rain |

**Anomaly weather:**

- Kích hoạt bởi `WeatherSystem.trigger_anomaly_weather()` (gọi từ `EventChainEngine` khi outcome = `cancelled_mysterious`).
- Ép `current_weather = storm`, intensity = 0.8 trong 3 ngày liên tiếp.
- Phát signal `anomaly_weather_triggered` cho các hệ thống khác (audio, atmosphere).
- Sau 3 ngày, tự động reset `anomaly_weather_active = false`.

**3-day forecast:**

Mỗi ngày generate forecast cho 3 ngày tới. Ngày mai (`forecast[0]`) accurate; ngày mốt và ba ngày sau chỉ là phỏng đoán.

### 6.11 Horror Presentation — 3 lớp

**Lớp 1: Lệch nhẹ (minor deviation)**

- NPC lặp lại lời thoại không khớp ngữ cảnh
- Thời tiết đột ngột đổi giữa clear → storm
- Lịch NPC bị trễ/bỏ mà không có lý do hiển thị
- Vật thể quen thuộc bị dịch chuyển vài pixel
- Âm thanh xa không xác định

**Lớp 2: Hậu quả xã hội (social consequence)**

- NPC bị thương → dialogue đổi sang `<id>_injured`
- NPC chết → family succession trigger, business status đổi
- Cửa hàng đóng 2-4 ngày ngẫu nhiên
- Festival bị hủy vì lý do không rõ
- `Crop Blight` → 35% mất một phần, 15% mất toàn bộ

**Lớp 3: Lộ lore (lore exposure)**

- Strange sounds gần forest edge (quest hook)
- Strange fruit xuất hiện trong mystery plant harvest
- Lore fragment rơi ra từ note cũ (`examine_farm_note.json`)
- Hidden area unlock khi tổng hợp đủ world flag
- "Day 47 — they came again last night" trong `examine_farm_note.json` (hint về cycle 30+ ngày)

### 6.12 Save/Load

**SaveManager** (`scripts/utils/save_manager.gd`):

- 3 slot save
- File path: `user://save_game.dat`
- Format: JSON
- CatchUpSystem migrate save data cũ và apply sau khi load

**Dữ liệu được serialize:**

- `GameState.current_day`, `current_time`, `energy`, `hp`, `gold`
- `GameState.inventory[]`
- `GameState.world_flags{}` (key-value)
- `GameState.farm_cells_data{}`
- `GameState.discovered_areas[]`
- `GameState.lore_fragments_found` (counter)
- `FamilyRegistry` (serialize_families → Dictionary)
- `EventChainEngine.completed_chains[]`
- `WeatherSystem.current_weather`, `current_season`

**Dữ liệu KHÔNG serialize:**

- Player position hiện tại (set lại qua portal/SceneManager)
- Dialogue runtime state
- Audio playing state

---

## 7. Thế giới và cấu trúc không gian

### 7.1 5 khu vực trong demo

| Khu vực | Scene | Chức năng chính |
|---|---|---|
| Farm map | `scenes/maps/farm_map.tscn` | Điểm xuất phát, nhà, ruộng, giếng, cây, cổng farm |
| Farm map v2 | `scenes/maps/farm_map_v2.tscn` | Layout thử nghiệm tile-based 50×37 |
| Inside house | `scenes/maps/inside_house_map.tscn` | Giường, safe zone |
| Inside shop | `scenes/maps/inside_shop_map.tscn` | Giao dịch item |
| Town map | `scenes/maps/town_map.tscn` | Không gian cộng đồng |

### 7.2 Khu vực backlog (chưa xây)

| Khu vực | Vai trò dự kiến |
|---|---|
| Mountain path | Nơi escort Voss, có risk cao nhất |
| Forest edge | Investigation quest `investigate_noise` |
| Village square | Festival chain |
| Hermit cabin | Dialogue với Old Hanz |
| Underground bunker | Late-game lore endpoint |

### 7.3 Scene Transition

`SceneManager` (`scripts/autoload/scene_manager.gd`):

- Portal-driven: `WorldInteractableObject` có `portal_id` + `target_scene`.
- Fade-to-black transition.
- Player placement lưu qua `target_portal_id` trong SceneManager state.
- Farm state (cells, watered flags) persist qua scene reload.

---

## 8. Hướng kể chuyện

### 8.1 Tiền đề

Ngôi làng sống nhờ nông nghiệp và một cửa hàng tổng hợp duy nhất (Voss General Store). Mọi người dựa vào lịch mùa, lễ hội hàng tuần và các mối quan hệ gia đình để giữ cảm giác ổn định. Tuy nhiên, các chuyến đi lên núi vào thứ 7 có tỷ lệ chết 5%, âm thanh ở rìa rừng vào thứ 4 không ai giải thích được, và bệnh trên mùa màng vào mùa thu cho thấy sự ổn định này phụ thuộc vào những điều không ai muốn gọi tên.

### 8.2 Bốn chủ đề chính

1. **Cộng đồng bảo vệ nhau hay bảo vệ bí mật?**
   - Thể hiện qua NPC né tránh câu hỏi, dialogue `_grief` không bao giờ giải thích nguyên nhân.

2. **Sống sót có đáng giá nếu phải im lặng?**
   - Thể hiện qua festival bị hủy mà không lý do, `villagers_leaving` khi blight toàn phần.

3. **Một người ngoài cuộc có thể can thiệp đến đâu trước khi trở thành một phần của vấn đề?**
   - Thể hiện qua intervention mechanic — player escort thay đổi weight outcome nhưng cũng unlock "weight" chain tiếp theo.

4. **Thiên nhiên đang bị bệnh, hay con người chỉ đang nhấp nháy hậu quả của một lời hứa cũ?**
   - Thể hiện qua `strange_fruit`, lore "Day 47" và `harvest_blight` chain.

### 8.3 Phương pháp kể chuyện

Không dùng cutscene dài làm phương thức chính. Story được truyền qua:

- **Dialogue có chọn lọc:** NPC nói như người đang làm việc, không phải người thuyết minh.
- **Lore fragment:** item lore với stack 99, mỗi fragment một mảnh puzzle.
- **NPC schedule conflict:** player phát hiện NPC không về đúng giờ.
- **Event chain consequence:** sau khi chain resolve, dialogue tiếp theo thay đổi.
- **Family status change:** REDUCED/EXTINCT thay đổi toàn bộ NPC behavior ở khu vực đó.
- **Environment shift:** lighting, atmosphere overlay (`atmosphere_manager.gd`).

Người chơi nên có thể hoàn thành một ngày mà vẫn chưa chắc điều gì là siêu nhiên.

### 8.4 Nhịp narrative dự kiến (vertical slice)

| Ngày | Beat |
|---|---|
| 1 | Mở game, học farming cơ bản, gặp Old Voss |
| 2 | Martha đi chợ (river_crossing, base risk 0.15) |
| 3 | Old Hanz đi rừng (forest_walk, base 0.10) |
| 4 | Young Voss đi đêm (night_walk, base 0.25) |
| 5 | Player escort Voss lên núi (chain `shopkeeper_mountain`) |
| 6-7 | Hậu quả chain: shop mở muộn / đóng / Voss chết |
| 7 | Festival chain (mỗi 7 ngày) |
| 14 | Investigation quest |
| 28-30 | Harvest blight chain trigger |

---

## 9. UI/UX và phản hồi

### 9.1 UI hiện có

| UI | Mô tả | File |
|---|---|---|
| Dialogue panel | Speaker name, text typewriter, choice buttons | `scripts/ui/dialogue_ui.gd` |
| Inventory | 4×4 grid, tooltip khi hover, click để dùng | `scripts/ui/inventory_ui.gd` |
| Hotbar | 3 slot, mouse-wheel đổi | `scripts/ui/hotbar.gd` |
| Shop UI | Buy/sell tabs, gold-based pricing | `scripts/ui/shop_ui.gd` |
| Tooltip | Item tooltip | `scripts/ui/tooltip_panel.gd` |
| Sleep prompt | Yes/No dialog | `scripts/ui/sleep_prompt.gd` |
| Inside house HUD | Bed ↔ sleep prompt ↔ day advance | `scripts/ui/inside_house_hud.gd` |

### 9.2 UI cần cho vertical slice

- Quest tracker gọn, ưu tiên mục tiêu active
- Dấu hiệu risk trước hành động có hậu quả lớn (không hiển thị % roll)
- Feedback rõ cho plow/seed/water/harvest/mature/wilted
- Pause menu (resume, save/load, settings, quit)
- Main menu

### 9.3 Accessibility mục tiêu

- Text đọc được ở viewport 320×180
- Tắt hiệu ứng nhấp nháy
- Giảm screen shake
- Volume riêng master/SFX/music/ambient
- Remap input (bước polish)

### 9.4 HUD layout dự kiến

```
[Day 5 | 14:32 | Weather: storm]      [Energy: 78/100 | HP: 100/100 | Gold: 142]

[E] Interact prompt khi có target gần

[Inventory/Hotbar 3 slot]              [Quest tracker gọn]
```

---

## 10. Art và audio direction

### 10.1 Hình ảnh

- **Pixel-art 16×16**, silhouette rõ, hạn chế chi tiết thừa.
- **Ban ngày:** đất, xanh cây, màu gỗ — cảm giác lao động.
- **Dusk/night:** xanh xám, đỏ nâu, vùng tối có chủ đích.
- **Horror:** thay đổi ánh sáng, khoảng trống, sprite lệch frame, vật thể quen thuộc bị đặt sai vị trí.

**Atmosphere manager** (`scripts/world/atmosphere/atmosphere_manager.gd`):

- CanvasModulate theo time-of-day
- Vignette/grain overlay
- "uncanny_shift" event cho horror beat

### 10.2 Âm thanh

**Trạng thái hiện tại:** `AudioManager` có kiến trúc đầy đủ (8 SFX player pool, music, ambient, fade, 4 volume bus) nhưng **không có audio asset thực tế** — folder `assets/audio/{sfx,music,ambient}/` chưa tồn tại.

**Hướng âm thanh mong muốn:**

- **Ambient ban ngày:** gió, côn trùng, làng, công việc.
- **Ambient ban đêm:** khoảng lặng dài, tiếng xa không xác định, âm thanh lệch nhịp.
- **SFX cần:** tool, watering, harvest, pickup, dialogue advance, shop transaction, sleep, anomaly.
- **Music:** tiết chế — 1 chủ đề bình tĩnh hơi bất an, 1 lớp tension cho đêm/event, stinger hiếm cho anomaly.

### 10.3 Placeholder hiện tại

- Icon: Godot default (`scenes/icon.svg`)
- Font: Godot default
- Crop sprite: Plants.png decor atlas (placeholder, không phải crop atlas thật)

---

## 11. Kiến trúc kỹ thuật

### 11.1 19 Autoload Singletons

| Autoload | Script | Trách nhiệm chính |
|---|---|---|
| `GameState` | `scripts/autoload/game_state.gd` | Persistent player/world state |
| `TimeManager` | `scripts/autoload/time_manager.gd` | Day/night cycle, time_scale |
| `WeatherSystem` | `scripts/autoload/weather_system.gd` | 8 weather, 4 season, anomaly |
| `EventManager` | `scripts/autoload/event_manager.gd` | One-shot events, anomaly cooldown |
| `EventChainEngine` | `scripts/autoload/event_chain_engine.gd` | Multi-step chains, outcomes |
| `QuestSystem` | `scripts/autoload/quest_system.gd` | 4 quest, lifecycle |
| `FamilyRegistry` | `scripts/autoload/family_registry.gd` | 3 family, 5 NPC, succession |
| `NPCSchedules` | `scripts/autoload/npc_schedules.gd` | Weekly schedules |
| `RiskCalculator` | `scripts/autoload/risk_calculator.gd` | Risk formula + outcome roll |
| `ConsequenceResolver` | `scripts/autoload/consequence_resolver.gd` | Flag changes, scene override |
| `WorldSimulator` | `scripts/autoload/world_simulator.gd` | Per-day tick |
| `CatchUpSystem` | `scripts/autoload/catch_up_system.gd` | Save migration |
| `DialogueManager` | `scripts/autoload/dialogue_manager.gd` | JSON dialogue, choices |
| `ItemManager` | `scripts/autoload/item_manager.gd` | Pickup hook |
| `ItemDB` | `resources/items/item_database.gd` | Item data dictionary |
| `ItemHandler` | `scripts/autoload/item_handler.gd` | Use item routing |
| `ToolHandler` | `scripts/autoload/tool_handler.gd` | Equip tool for hotbar |
| `AudioManager` | `scripts/autoload/audio_manager.gd` | SFX/music/ambient (no assets yet) |
| `CameraManager` | `scripts/autoload/camera_manager.gd` | Shake, zoom, limits |
| `SceneManager` | `scripts/autoload/scene_manager.gd` | Fade transition, portal placement |

### 11.2 Ownership Rules

| Loại dữ liệu | Owner |
|---|---|
| Persistent player state | `GameState` |
| Weather/season state | `WeatherSystem` |
| NPC family/member state | `FamilyRegistry` |
| Quest state | `QuestSystem` |
| Event chain state | `EventChainEngine` |
| Dialogue runtime | `DialogueManager` |
| Item data | `ItemDB` |
| Item runtime (inventory) | `GameState.inventory` |
| Farm cell data | `GameState.farm_cells_data` |

### 11.3 Communication Pattern

- **Signals** là phương thức liên lạc chính giữa các module.
- **Direct call** chỉ khi một module thực sự sở hữu state kia.
- **Global flag** (qua `GameState.set_flag`) cho state xuyên scene như quest completion.

### 11.4 Serialize Contract

Hệ thống nào ảnh hưởng đến ngày/quest/family/farm/inventory/world flag phải implement:
- `serialize() -> Dictionary`
- `deserialize(data: Dictionary) -> void`

Đã implement: GameState, FarmManager, FamilyRegistry, EventChainEngine.

---

## 12. Phạm vi MVP / Vertical Slice

### 12.1 Must-have (gate Phase 1 → Phase 2)

- Một map farm có nhà, ruộng, cửa hàng, ít nhất 1 NPC active.
- Vòng lặp plow → seed → water → sleep → crop progress → harvest.
- Day/night, energy, inventory, hotbar, buy/sell cơ bản.
- Dialogue + ít nhất 1 quest end-to-end.
- 1 event chain có ≥ 2 outcome nhìn thấy được trong game.
- 1 anomaly/horror beat không dựa vào combat.
- Save/load 1 phiên chơi, scene transition không mất dữ liệu.

### 12.2 Should-have (gate Phase 2 → Phase 3)

- Đủ 3 family/NPC chính trong một tuyến trải nghiệm.
- Escort/delivery có intervention thật sự ảnh hưởng risk/outcome.
- Weather forecast + 1 chain blight/festival hoàn chỉnh.
- Quest tracker + feedback hậu quả rõ ràng.

### 12.3 Won't-have trong demo đầu

- Combat hoàn chỉnh.
- Multiplayer.
- Fishing, cooking.
- Mobile/console port.
- 50+ item, 10+ event chain, toàn bộ bunker/lore arc.

---

## 13. Roadmap đề xuất

| Giai đoạn | Kết quả cần đạt | Acceptance gate |
|---|---|---|
| **Phase 1: Foundation hardening** | Sửa UID, missing scene, audio fallback, smoke test F5 | Game chạy ổn định từ main scene, 1 ngày chơi được không lỗi |
| **Phase 2: Core playable loop** | Farming, shop, sleep, inventory, save/load, 1 quest end-to-end | Must-have đầy đủ |
| **Phase 3: Narrative vertical slice** | Hoàn thiện Voss mountain chain, 1 map mountain/forest, family consequence, lore fragment | 3 chain chạy đúng với % thiết kế, ít nhất 1 family status change trong test |
| **Phase 4: Horror pass** | Time lighting, anomaly presentation, ambient audio, blight/festival outcomes | 3 lớp horror (minor/social/lore) đều có thể trigger được |
| **Phase 5: Content expansion** | NPC dialogue branches, thêm map, item, quest, lore | Should-have đầy đủ |
| **Phase 6: Polish/release** | UI/UX, accessibility, performance, bug triage, build/export, playtest | Build export được, smoke test pass |

---

## 14. Rủi ro sản xuất và quyết định cần theo dõi

| Rủi ro | Tác động | Xác suất | Hướng xử lý |
|---|---|---|---|
| Phạm vi horror mở rộng quá nhanh | Mất trọng tâm demo | Cao | Chốt 1 tuyến chain làm vertical slice |
| Event outcome khó đọc | Player thấy bất công | Trung bình | Cho dấu hiệu, risk context, hậu quả giải thích được |
| Autoload trùng ownership | Bug state khó truy | Trung bình | Duy trì bảng ownership + serialize contract |
| Asset thiếu cho atmosphere | Horror thành text-only | Cao | Ưu tiên âm thanh/ánh sáng/feedback trước content số lượng lớn |
| UID/missing scene/reference | Game không chạy ổn định | Cao | Gate Foundation trước khi thêm chain mới |
| Không có test/playtest | Regression silent | Cao | Smoke test cho day advance, farm state, quest outcome, save/load |
| Ngôn ngữ đa dạng trong lore (Việt/Anh) | Localization khó | Thấp | Chốt canonical Việt cho game, Anh cho lore fragment |
| Solo developer burnout | Dự án đứng | Trung bình | Phase 1-3 có scope giảm, phase 4+ có thể dời |

---

## 15. Acceptance criteria cho bản demo

- [ ] Người chơi khởi động được game từ main scene và di chuyển trong farm map.
- [ ] Có thể tương tác bằng E với bed, NPC, shop, ít nhất 1 vật thể/item.
- [ ] Hoàn thành được 1 chu kỳ ngày: làm việc, tiêu hao năng lượng, ngủ, sang ngày mới.
- [ ] Crop giữ đúng trạng thái sau khi đổi ngày và khi chuyển scene.
- [ ] Inventory, mua/bán, reward quest cập nhật đúng vàng/item.
- [ ] 1 quest chuyển được qua active → completed/failed và lưu cờ lý do.
- [ ] 1 event chain có outcome khác nhau tạo thay đổi quan sát được.
- [ ] Risk thay đổi khi đổi weather/time/personality/escort theo công thức.
- [ ] Horror beat tạo bất an bằng môi trường/thời tiết/hậu quả, không cần combat.
- [ ] Save/load khôi phục ngày, giờ, inventory, farm, quest, world flags.
- [ ] Không có lỗi blocking do UID hoặc scene reference trong phạm vi vertical slice.

---

## 16. Open questions

| Câu hỏi | Phụ trách | Thời điểm quyết | Trạng thái |
|---|---|---|---|
| Danh tính chính xác của player và lý do đến làng là gì? | Narrative | Trước khi viết tuyến opening | Mở |
| Horror là siêu nhiên, sinh thái hay hậu quả xã hội của một bí mật? | Creative/Narrative | Trước vertical slice | Mở |
| Cho phép NPC chết vĩnh viễn trong demo hay dùng trạng thái thay thế? | Design | Trước khi khóa family consequence | Mở |
| Mountain path và forest edge có phải map chơi được trong bản demo không? | Production | Khi chốt scope MVP | Mở |
| Thời lượng một ngày thực tế có cần cố định lại sau playtest không? | Design/QA | Sau smoke test đầu | Mở |
| Tên thương mại cuối cùng có còn là "Farm Horror" không? | Creative | Trước public build | Mở |
| Có nên thêm mini-game puzzle (sorting/match-3) vào lộ trình không? | Design | Sau Phase 3 | Mới thêm |
| Co-op multiplayer có khả thi cho late phase không? | Production | Sau Phase 5 | Mới thêm |

---

## 17. Tài liệu và mã nguồn tham chiếu

### 17.1 Tài liệu dự án

- `README.md` — định hướng dự án và learning path
- `TODO.md` — trạng thái công việc, known issues, backlog
- `UID_FIX_INSTRUCTIONS.md` — hướng dẫn tái tạo UID
- `COMMANDS-QUICK-REF.md` — slash commands catalog
- `docs/farm_v2_readme.md` — prototype tile-based farm
- `docs/farm_v2_layout.txt` — ASCII layout 50×37
- `AGENTS.md` — agent workflow

### 17.2 Templates

- `docs/templates/gdd-template.md` — gdd 8 sections
- `docs/templates/concept-template.md` — concept doc
- `docs/templates/character-sheet-template.md` — NPC sheet
- `docs/templates/systems-index-template.md` — systems tracking
- `docs/templates/test-plan-template.md` — test plan

### 17.3 Code tham chiếu chính

| File | Vai trò |
|---|---|
| `scripts/autoload/game_state.gd` | Persistent state |
| `scripts/player/player.gd` | Player FSM + interaction |
| `scripts/autoload/time_manager.gd` | Time scale, day/night |
| `scripts/autoload/weather_system.gd` | Weather, season, anomaly |
| `scripts/autoload/risk_calculator.gd` | Risk formula + outcome |
| `scripts/autoload/event_chain_engine.gd` | Chain, branch, consequence |
| `scripts/autoload/quest_system.gd` | Quest definitions + lifecycle |
| `scripts/autoload/family_registry.gd` | NPC family + succession |
| `scripts/autoload/npc_schedules.gd` | Weekly NPC schedules |
| `scripts/world/farm/farm_manager.gd` | Farming rules |
| `scripts/autoload/world_simulator.gd` | Per-day tick |
| `scripts/autoload/catch_up_system.gd` | Save migration |
| `scripts/autoload/consequence_resolver.gd` | Flag/schedule changes |
| `scripts/autoload/dialogue_manager.gd` | Dialogue runtime |
| `scripts/utils/save_manager.gd` | Save/load 3 slot |
| `scripts/autoload/scene_manager.gd` | Scene transition + portal |

### 17.4 Resources

- `resources/items/definitions/*.tres` — 22 item data
- `resources/dialogue/welcome.json` — opening dialogue
- `resources/dialogue/shopkeeper.json` — placeholder shopkeeper
- `resources/dialogue/examine_farm_note.json` — lore fragment "Day 47"
- `resources/tilesets/farm_tileset.tres` — farm TileSet
- `tilesets/game_tile_set.tres` — Grassland TileSet (with terrain autotile)

### 17.5 Scenes

- `scenes/main.tscn` — main scene
- `scenes/Player.tscn` — player scene
- `scenes/maps/*.tscn` — 6 maps
- `scenes/npc/shopkeeper.tscn` — only NPC scene currently
- `scenes/ui/*.tscn` — 5 UI scenes
- `scenes/world/*.tscn` — 5 world objects/scenes
- `scenes/tools/atlas_boot.tscn` — TileSet builder

---

## 18. Phụ lục

### Phụ lục A — Bảng ItemData đầy đủ

22 item resource tại `resources/items/definitions/`. Bảng tóm tắt:

| ID | Type | Effect | Buy | Sell | Stack | Lore/Ngữ cảnh |
|---|---|---|---:|---:|---:|---|
| `hoe` | TOOL | (action) | 50 | 25 | 1 | Cày đất |
| `water_can` | TOOL | WATER_CROPS | 30 | 15 | 1 | Tưới cây |
| `health_potion` | CONSUMABLE | RESTORE_HEALTH | 15 | 7 | 10 | Hồi máu |
| `apple` | CONSUMABLE | RESTORE_ENERGY | 8 | 3 | 20 | Ăn tăng năng lượng |
| `rope` | TOOL | CLIMB | 20 | 10 | 5 | Leo núi |
| `old_key` | KEY_ITEM | (none) | (không bán) | (không bán) | 1 | Mở khóa bí ẩn |
| `lore_fragment` | MISC | (none) | (không bán) | 5 | 99 | Mảnh puzzle |
| `strange_fruit` | MISC | (none) | (không bán) | 25 | 10 | "Something about it feels... wrong" |
| `seed_wheat` | SEED | GROW_CROP | 5 | 3 | 20 | → wheat |
| `wheat` | (harvest) | (none) | 8 | 4 | 20 | Sau thu hoạch |
| `seed_corn` | SEED | GROW_CROP | 8 | 4 | 20 | → corn |
| `corn` | (harvest) | (none) | 12 | 6 | 20 | Sau thu hoạch |
| `seed_tomato` | SEED | GROW_CROP | 10 | 5 | 20 | → tomato_harvest |
| `tomato_harvest` | (harvest) | (none) | 18 | 9 | 20 | Sau thu hoạch |
| `seed_potato` | SEED | GROW_CROP | 6 | 3 | 20 | → potato_harvest |
| `potato_harvest` | (harvest) | (none) | 10 | 5 | 20 | Sau thu hoạch |
| `seed_turnip` | SEED | GROW_CROP | 4 | 2 | 20 | → turnip_harvest |
| `turnip_harvest` | (harvest) | (none) | 7 | 3 | 20 | Sau thu hoạch |

### Phụ lục B — NPC Personality → Risk Modifier

| Personality | Risk modifier | Ví dụ NPC |
|---|---:|---|
| cautious | -0.10 | shopkeeper_father, farmer_mother |
| normal | 0.00 | farmer_daughter |
| reckless | +0.15 | shopkeeper_son |
| old | +0.10 | hermit |
| young | +0.05 | (chưa có NPC) |

### Phụ lục C — Dialogue IDs hiện có

| Dialogue ID | File JSON | Trạng thái |
|---|---|---|
| `welcome` | `resources/dialogue/welcome.json` | Có speaker `???`, 3 line cryptic |
| `shopkeeper` | `resources/dialogue/shopkeeper.json` | Placeholder tiếng Việt, speaker "Không Mana" |
| `examine_farm_note` | `resources/dialogue/examine_farm_note.json` | Lore "Day 47" |
| `shopkeeper_father_normal` | (chưa có) | Tham chiếu từ FamilyRegistry |
| `shopkeeper_son_normal` | (chưa có) | Tham chiếu từ FamilyRegistry |
| `farmer_mother_normal` | (chưa có) | Tham chiếu từ FamilyRegistry |
| `farmer_daughter_normal` | (chưa có) | Tham chiếu từ FamilyRegistry |
| `hermit_normal` | (chưa có) | Tham chiếu từ FamilyRegistry |
| `<id>_grief` | (chưa có) | Auto-swap khi family REDUCED |
| `<id>_injured` | (chưa có) | Auto-swap khi chain outcome injured |

### Phụ lục D — Weather → Risk Modifier

| Weather | RiskCalculator modifier | WeatherSystem.WEATHER_RISK |
|---|---:|---:|
| clear | 0.00 | 0.00 |
| overcast | +0.05 | 0.05 |
| fog | +0.10 | 0.10 |
| mist | +0.12 | 0.20 |
| drizzle | +0.08 | 0.15 |
| rain | +0.15 | 0.25 |
| storm | +0.35 | 0.45 |
| heavy_rain | +0.45 | 0.60 |

> Lưu ý: bảng này có hai nguồn — `RiskCalculator.WEATHER_MODIFIER` được dùng trong gameplay, `WeatherSystem.WEATHER_RISK` là bản tham chiếu. Hiện tại hai bảng chưa đồng bộ; Phase 1 cần chốt một bảng canonical.

### Phụ lục E — Risk Outcome Roll Buckets

```
roll < risk * 0.4  → dead    (40% của risk)
roll < risk * 0.8  → injured (40% tiếp theo)
roll < risk        → delayed (20% tiếp theo)
roll >= risk       → safe    (phần còn lại)
```

**Ví dụ risk = 0.62:**

- Roll < 0.248 → dead
- Roll < 0.496 → injured
- Roll < 0.62 → delayed
- Roll ≥ 0.62 → safe

**Phân bố xác suất (với risk = 0.62):**

- dead: 24.8%
- injured: 24.8%
- delayed: 12.4%
- safe: 38.0%

### Phụ lục F — Tương quan Phase ↔ TODO.md

TODO.md có 5 phase với 72 task. Mapping tương đối:

| Phase | TODO | Số task |
|---|---|---:|
| Phase 1: Critical Fixes | UID regen, missing NPC scene, audio fallback | 14 |
| Phase 2: Core Systems | Save/load, shop UI, dialogue expand, farming | 18 |
| Phase 3: Content & Polish | Animation, FX, weather visual | 15 |
| Phase 4: Testing & QA | Test suite, smoke test, playtest | 12 |
| Phase 5: Distribution & Post-launch | Build, marketing, telemetry | 13 |

> TODO.md gốc có tổng ~72 task, breakdown chi tiết theo nhóm con trong file.

### Phụ lục G — Skill và Resource Count

| Loại | Số lượng |
|---|---:|
| Script GDScript `.gd` | 47 |
| Scene `.tscn` | 20 |
| Item resource `.tres` | 24 |
| TileSet resource `.tres` | 2 |
| Dialogue JSON | 3 |
| Tileset PNG (imported) | 16×18 grid FieldsTileset, 42×18 Plants |
| Raw tile art PNG | 378 |
| Audio asset | 0 (chưa có) |

---

## 19. Lịch sử thay đổi

| Phiên bản | Ngày | Thay đổi | Tác giả |
|---|---|---|---|
| 1.0 | 2026-07-15 | Bản đầu tiên, mô tả ngắn pitch + 8 systems cơ bản | Solo dev |
| 1.5 | 2026-08-15 | Cập nhật số liệu risk formula, weather modifier, NPC list | Solo dev |
| 2.0 | 2026-08-22 | **Master rewrite.** Mở rộng từ 17 lên 19 sections, thêm Phụ lục A-G (ItemData, Personality, Dialogue, Weather, Outcome, Phase-TODO, Count), thêm 2 open questions, đồng bộ lại số liệu theo code hiện tại (47 scripts trong `scripts/`, 20 autoload, 22 items, 5 NPCs, 4 quests, 3 chains, 8 weather), bổ sung Roadmap chi tiết, Risk section có ví dụ tính cụ thể. | Solo dev |

---

**Ghi chú cuối:** Tài liệu này là nguồn tham chiếu cho dự án `Farm Horror Demo`. Mọi thay đổi trong code phải kéo theo cập nhật GDD — đặc biệt là mục 5 (Trạng thái sản phẩm), mục 6 (Gameplay systems) và mục 18 (Phụ lục). Khi thêm quest/event/item/NPC mới, cần cập nhật các bảng tương ứng trước khi merge code.
