# Bản đồ Mã nguồn & Kiến trúc Dự án (Old Town / GameDemo)

> **Mục đích file này:** Giúp bất kỳ agent nào (hoặc session mới) nhanh chóng
> định vị cấu trúc dự án, hiểu kiến trúc tổng thể và tìm đúng nơi chứa logic cần
> sửa/đọc mà không phải dò từng file.
>
> **Đọc file này TRƯỚC KHI làm bất kỳ thay đổi code nào.**
>
> Engine: **Godot 4.5** (Forward Plus) · Ngôn ngữ: **GDScript** · Scene khởi động:
> `res://scenes/maps/inside_house_map.tscn`.

---

## 1. Tóm tắt nhanh (30 giây)

- Đây là **game 2D top-down** kết hợp **farming + mô phỏng đời sống + yếu tố
  kinh dị/bí ẩn**.
- **Toàn bộ trạng thái game nằm trong các Autoload (singleton)** khai báo ở
  `[autoload]` của `project.godot` — KHÔNG nằm trong scene. Đây là xương sống
  của dự án.
- **Dữ liệu cấu hình** (thông số, text, lịch NPC, nhiệm vụ, hội thoại) được tách
  ra file **JSON/.tres** trong `resources/`, load qua `ConfigManager`/`ItemDB`.
- **Trạng thái trung tâm** là `GameState` (`scripts/autoload/game_state.gd`).
- **Giao tiếp giữa các hệ thống** chủ yếu bằng **signal** của Godot.
- **Quy ước bắt buộc:** comment code và file `.md` viết **tiếng Việt**; tên
  biến/hàm/class giữ tiếng Anh (xem `.cursor/rules/common/common-vietnamese-documentation.md`).

**Thứ tự đọc khi mới vào dự án:**
1. `project.godot` (autoload + input + display)
2. `scripts/autoload/game_state.gd` (trạng thái trung tâm)
3. `scripts/autoload/farm_enums.gd` (enum nền tảng của farming)
4. `README.md`, `RULES.md`, `AGENTS.md`
5. File này.

---

## 2. Cấu trúc thư mục (worktree)

```text
game-demo/
├── project.godot            # Cấu hình Godot: autoload, input, display, main scene
├── AGENTS.md                # Danh sách agent + workflow cộng tác (entry point cho agent)
├── RULES.md                 # Quy tắc bắt buộc (commit, agent/skill/hook format…)
├── README.md                # Giới thiệu project + điều khiển
├── export_presets.cfg       # Cấu hình export
│
├── scenes/                  # Scene Godot (.tscn)
│   ├── main.tscn            # (main) — scene khởi động thực tế là inside_house_map
│   ├── Player.tscn          # Nhân vật người chơi
│   ├── maps/                # Bản đồ thế giới
│   ├── npc/                 # Scene NPC (neighbor, shopkeeper)
│   ├── ui/                  # Scene UI (dialogue, hotbar, inventory, shop, clock…)
│   ├── world/               # Vật thể world (giường, quầy, ô đất, bảng quest…)
│   └── tools/               # Scene công cụ build (atlas_boot)
│
├── scripts/                 # Toàn bộ mã GDScript
│   ├── autoload/            # Singleton toàn cục (xem §5) — TRÁI TIM dự án
│   ├── player/              # player.gd (di chuyển, tương tác, ngủ, knock-out)
│   ├── npc/                 # npc.gd (base), neighbor.gd, shopkeeper.gd
│   ├── world/               # bed, counter, portal, farm, quest_board, atmosphere…
│   ├── ui/                  # HUD, inventory, shop, dialogue, hotbar, energy…
│   ├── data/                # Resource dữ liệu: PortalData, RouteData, WaypointData
│   ├── tools/               # Script build/utility phát triển
│   └── utils/               # save_manager.gd, util.gd
│
├── resources/               # Dữ liệu & tài nguyên (KHÔNG phải code logic chính)
│   ├── config/              # JSON cấu hình gameplay/NPC/schedule/text/money
│   ├── dialogue/            # JSON hội thoại (1 file = 1 đoạn hội thoại)
│   ├── items/               # item_data.gd (Resource), item_database.gd (autoload ItemDB)
│   │   └── definitions/     # 1 file .tres = 1 vật phẩm
│   ├── quest/               # quest_data.json
│   ├── localization/        # vi.json (bản dịch UI tiếng Việt)
│   └── tilesets/            # .tres tileset
│
├── tilesets/                # Texture tileset + asset môi trường (PNG)
├── docs/                    # Tài liệu: characters, templates, farm_v2, ARCHITECTURE.md
├── design/gdd/              # Game Design Document
└── tools/                   # playtest_harness.gd, smoke_test.gd (test/QA)
```

> Lưu ý: thư mục `.godot/` (cache/import của engine), `.pnpm-store/`,
> `.claude/`, `.cursor/` là metadata công cụ — không chứa logic game.

---

## 3. Bản đồ "tìm logic theo tính năng" (tra cứu nhanh)

| Bạn cần sửa/tìm hiểu gì? | Mở file nào? |
|---|---|
| Trạng thái game (vàng, máu, năng lượng, inventory, cờ sự kiện) | `scripts/autoload/game_state.gd` |
| Enum crop state/type, map seed→crop, thông số nước | `scripts/autoload/farm_enums.gd` |
| Load config JSON | `scripts/autoload/config_manager.gd` |
| Đồng hồ, ngày/đêm, tốc độ thời gian | `scripts/autoload/time_manager.gd` |
| Chuyển scene + fade + vị trí spawn/portal | `scripts/autoload/scene_manager.gd` |
| Lịch & di chuyển NPC, spawn/despawn theo scene | `scripts/autoload/npc_manager.gd` |
| Base NPC (state, schedule, pathfinding) | `scripts/npc/npc.gd` |
| NPC hàng xóm Marcus (lịch day1 intro, quest) | `scripts/npc/neighbor.gd` |
| NPC chủ shop (Voss) | `scripts/npc/shopkeeper.gd` |
| Hội thoại (đọc JSON, chạy dòng, action) | `scripts/autoload/dialogue_manager.gd` + `scripts/ui/dialogue_ui.gd` |
| Nhiệm vụ (accept/complete/expire, quest bảng tin) | `scripts/autoload/quest_system.gd` |
| Bảng nhiệm vụ trong world | `scripts/world/quest_board.gd` + `scripts/world/quest_board_ui.gd` |
| Chuỗi sự kiện phân nhánh (event chain) | `scripts/autoload/event_chain_engine.gd` |
| Sự kiện thế giới / anomaly | `scripts/autoload/event_manager.gd` |
| Tính rủi ro (risk) cho hoạt động | `scripts/autoload/risk_calculator.gd` |
| Hệ quả (scene change, flag, kế thừa gia đình) | `scripts/autoload/consequence_resolver.gd` |
| Mô phỏng thế giới khi player vắng mặt | `scripts/autoload/world_simulator.gd` |
| Gia đình & trạng thái kinh doanh | `scripts/autoload/family_registry.gd` |
| Lịch trình NPC (Dwarf-Fortress style) | `scripts/autoload/npc_schedules.gd` |
| Route/waypoint qua portal | `scripts/autoload/npc_route_manager.gd` + `scripts/data/route_data.gd` |
| Farming: state ô đất, sinh trưởng theo ngày | `scripts/autoload/farm_tick_manager.gd` (state) + `scripts/world/farm/farm_manager.gd` (render) |
| Ô đất + tương tác click chuột | `scripts/world/farm/farm_plot.gd` |
| Visual cây trồng theo stage | `scripts/world/farm/crop_visual_manager.gd` |
| Điều khiển player (WASD, E, sprint, ngủ, cutscene) | `scripts/player/player.gd` |
| Năng lượng + knock-out (ngất, trừ vàng, giảm tốc) | `scripts/autoload/energy_manager.gd` |
| Dùng vật phẩm (consume/seed/tool) | `scripts/autoload/item_handler.gd` |
| Trang bị tool | `scripts/autoload/tool_handler.gd` |
| Nhặt/thả vật phẩm | `scripts/autoload/item_manager.gd` |
| Database vật phẩm (tra cứu ItemData) | `resources/items/item_database.gd` |
| Định nghĩa 1 vật phẩm (giá, loại, effect) | `resources/items/item_data.gd` + `resources/items/definitions/*.tres` |
| Inventory UI (21 ô, drag/drop) | `scripts/ui/inventory_ui.gd` |
| Shop (mua/bán) | `scripts/ui/shop_ui.gd` |
| Hotbar/toolbar (phím 1–5) | `scripts/ui/hotbar.gd` + `scripts/ui/hotkey_input_manager.gd` |
| Routing phím tắt toàn cục (TAB mở inventory) | `scripts/autoload/input_router.gd` |
| Lưu/load game | `scripts/utils/save_manager.gd` + `scripts/autoload/catch_up_system.gd` |
| Thời tiết, mùa, dự báo | `scripts/autoload/weather_system.gd` |
| Ánh sáng ngày/đêm + hiệu ứng thời tiết | `scripts/world/atmosphere/atmosphere_manager.gd` |
| Âm thanh (BGM/SFX) | `scripts/autoload/audio_manager.gd` |
| Camera theo player | `scripts/autoload/camera_manager.gd` |
| Hiển thị cảnh báo lơ lửng trên đầu player | `scripts/autoload/floating_warning.gd` |
| Prompt `[E]` khi đứng gần vật | `scripts/autoload/interaction_prompt_manager.gd` |
| Làm mờ UI nền khi mở popup | `scripts/autoload/ui_focus_manager.gd` |
| Giường + prompt ngủ | `scripts/world/bed.gd` + `scripts/ui/sleep_prompt.gd` |
| Portal chuyển scene | `scripts/world/world_transition.gd` + `scripts/data/portal_data.gd` |
| Vật thể tương tác được (examine/pickup) | `scripts/world/interactable.gd` + `scripts/world/world_interactable_object.gd` |
| Quầy shop | `scripts/world/counter.gd` + `scripts/world/counter_zone.gd` |
| Test/QA (smoke test, playtest) | `tools/playtest_harness.gd` + `tools/smoke_test.gd` |

---

## 4. Kiến trúc tổng thể & luồng dữ liệu

### 4.1 Mô hình chung

```
                project.godot  [autoload]
                        │  (singleton, luôn sống, load theo thứ tự khai báo)
                        ▼
   ┌────────────────────────────────────────────────────────────┐
   │  ConfigManager ──► GameState (dữ liệu trung tâm)            │
   │        │                ▲        ▲                         │
   │        │ (JSON)         │ signal │ signal                   │
   │        ▼                │        │                         │
   │  TimeManager ───────────┴────────┴──► FarmTickManager       │
   │  WeatherSystem ─► RiskCalculator ─► EventChainEngine        │
   │  NPCManager ◄── SceneManager (chuyển scene)                 │
   │  DialogueManager / QuestSystem / ItemHandler / …            │
   └────────────────────────────────────────────────────────────┘
                        │ đọc/ghi thông qua signal hoặc gọi trực tiếp
                        ▼
            Scene (map) → Node (Player, NPC, FarmManager, UI…)
```

- **Autoload = nguồn sự thật (source of truth).** Scene chỉ render + nhận input
  rồi gọi vào autoload; autoload phát signal ngược lại để UI/Node cập nhật.
- **Signal là kênh giao tiếp chính.** Ví dụ: `GameState.inventory_changed`,
  `GameState.day_changed`, `GameState.farm_day_changed`,
  `TimeManager.time_changed`, `SceneManager.scene_changing`,
  `QuestSystem.quest_completed`, v.v.

### 4.2 Luồng khởi động (boot)

1. Godot load `project.godot` → khởi tạo tuần tự các autoload.
2. `ConfigManager._ready()` load toàn bộ JSON trong `resources/config/`.
3. `GameState._ready()` load giá trị mặc định từ `ConfigManager`.
4. Các autoload khác (`_ready`) tự build dữ liệu nội bộ (VD: `FamilyRegistry`
   build danh sách gia đình, `NPCSchedules` build lịch mặc định, `ItemDB` load
   danh sách vật phẩm).
5. Scene chính `inside_house_map.tscn` được chạy.

### 4.3 Luồng chuyển ngày (day cycle)

- `TimeManager._process()` tăng `GameState.current_time` theo delta.
- Qua mốc 6:00 → `GameState.advance_day(6.0)`:
  - tăng `current_day`, reset giờ, hồi năng lượng, emit `day_changed` +
    `farm_day_changed`.
- `FarmTickManager` nghe `farm_day_changed` → cập nhật sinh trưởng cây, reset
  nước tưới.
- `ConsequenceResolver` nghe `day_changed` → áp dụng hậu quả đã lên lịch.
- `WorldSimulator` nghe `day_changed` → chạy mô phỏng thế giới.

### 4.4 Luồng tương tác cơ bản (bấm E)

1. `InteractionPromptManager` theo dõi các interactable gần player → chọn 1
   target (theo priority + khoảng cách).
2. `player.gd` bấm `interact` (E) → gọi `interact()` trên target (portal, bed,
   NPC, quest board, vật thể…).
3. Đối tượng xử lý: mở dialogue, chuyển scene, mở shop, nhận quest…

### 4.5 Luồng hội thoại

1. NPC gọi `DialogueManager.start_dialogue(id, npc_name)`.
2. `DialogueManager` đọc `resources/dialogue/{id}.json`.
3. `DialogueUI` hiển thị từng dòng, chờ người chơi nhấn E/chuột.
4. Kết thúc → chạy `action` (nếu có), emit `dialogue_ended`.

### 4.6 Luồng lưu/load

- **Lưu:** `SaveManager.save_game()` → gọi `CatchUpSystem.prepare_save_data()`
  (gom mọi trạng thái từ `GameState`, `FamilyRegistry`, `WeatherSystem`,
  `FarmTickManager`, NPC runtime) → ghi JSON ra `user://save_game_{slot}.dat`.
- **Load:** `SaveManager.load_game()` → `CatchUpSystem.apply_save_data()` →
  `SceneManager.change_scene()` về scene đã lưu.

---

## 5. Danh mục Autoload (theo thứ tự khai báo trong `project.godot`)

Thứ tự khai báo = thứ tự khởi tạo; hệ thống phụ thuộc phải đứng sau hệ thống nó
cần (VD: `ConfigManager` trước `GameState`).

| # | Tên autoload | File | Vai trò |
|---|---|---|---|
| 1 | `FarmEnums` | `autoload/farm_enums.gd` | Enum + const dùng chung cho farming (CropState, CropType, map seed/crop, thông số nước) |
| 2 | `ConfigManager` | `autoload/config_manager.gd` | Load + tra cứu toàn bộ JSON config; dịch text UI |
| 3 | `GameState` | `autoload/game_state.gd` | **Trạng thái trung tâm**: người chơi, ngày/giờ, năng lượng, inventory, toolbar, vàng, world_flags, quan hệ NPC |
| 4 | `AudioManager` | `autoload/audio_manager.gd` | Phát nhạc nền + hiệu ứng âm thanh |
| 5 | `CameraManager` | `autoload/camera_manager.gd` | Camera bám theo player |
| 6 | `DialogueManager` | `autoload/dialogue_manager.gd` | Điều khiển hội thoại, đọc JSON, chạy dòng, action |
| 7 | `EventManager` | `autoload/event_manager.gd` | Quản lý sự kiện thế giới / anomaly / missed events |
| 8 | `SceneManager` | `autoload/scene_manager.gd` | Chuyển scene, fade, spawn portal, nhớ vị trí player mỗi scene |
| 9 | `TimeManager` | `autoload/time_manager.gd` | Đồng hồ game, ngày/đêm, AFK penalty |
| 10 | `WeatherSystem` | `autoload/weather_system.gd` | Thời tiết, mùa, dự báo, risk theo thời tiết |
| 11 | `FamilyRegistry` | `autoload/family_registry.gd` | Gia đình, thành viên sống/chết, kế thừa, trạng thái kinh doanh |
| 12 | `NPCSchedules` | `autoload/npc_schedules.gd` | Lịch trình NPC theo ngày/tuần |
| 13 | `RiskCalculator` | `autoload/risk_calculator.gd` | Tính rủi ro hoạt động (base + weather + time + …) |
| 14 | `ConsequenceResolver` | `autoload/consequence_resolver.gd` | Áp dụng hậu quả lên lịch (đổi scene, flag, kế thừa gia đình) |
| 15 | `EventChainEngine` | `autoload/event_chain_engine.gd` | Chuỗi sự kiện nhiều bước, phân nhánh, outcome (SAFE/INJURED/DEAD…) |
| 16 | `WorldSimulator` | `autoload/world_simulator.gd` | Mô phỏng thế giới khi player vắng (NPC vẫn sinh hoạt) |
| 17 | `CatchUpSystem` | `autoload/catch_up_system.gd` | Gom/phục hồi dữ liệu save (metadata lưu trữ thụ động) |
| 18 | `SaveManager` | `utils/save_manager.gd` | Ghi/đọc file save (3 slot), serialize qua CatchUpSystem |
| 19 | `QuestSystem` | `autoload/quest_system.gd` | Quản lý nhiệm vụ, bảng tin hàng ngày, quest theo cây trồng |
| 20 | `NPCManager` | `autoload/npc_manager.gd` | **Quản lý NPC toàn cục**: 1 instance duy nhất, spawn/despawn theo scene + schedule |
| 21 | `NPCRouteManager` | `autoload/npc_route_manager.gd` | Registry route waypoint dùng chung cho NPC và portal |
| 22 | `ItemManager` | `autoload/item_manager.gd` | Nhặt/thả vật phẩm (gọi GameState.add/remove_item) |
| 23 | `ItemDB` | `resources/items/item_database.gd` | Database vật phẩm; tra cứu `ItemData` theo id |
| 24 | `InteractionPromptManager` | `autoload/interaction_prompt_manager.gd` | Chọn target tương tác gần nhất + xử lý bấm E |
| 25 | `ItemHandler` | `autoload/item_handler.gd` | Dùng vật phẩm (consume/seed/tool), dùng slot toolbar |
| 26 | `ToolHandler` | `autoload/tool_handler.gd` | Trang bị/hủy trang bị tool |
| 27 | `EnergyManager` | `autoload/energy_manager.gd` | Tiêu hao năng lượng + knock-out (ngất, trừ vàng, giảm tốc) |
| 28 | `EnergyBar` | `ui/energy_bar.gd` | Thanh năng lượng (autoload để luôn hiển thị) |
| 29 | `UIFocusManager` | `autoload/ui_focus_manager.gd` | Làm mờ UI nền khi mở popup |
| 30 | `FarmTickManager` | `autoload/farm_tick_manager.gd` | **State farm + logic theo ngày** (chạy mọi scene) |
| 31 | `FloatingWarning` | `autoload/floating_warning.gd` | Text cảnh báo lơ lửng trên đầu player |
| 32 | `HotkeyInputManager` | `ui/hotkey_input_manager.gd` | Ánh xạ phím 1–5 → chọn slot toolbar, chặn khi mở UI |
| 33 | `InputRouter` | `autoload/input_router.gd` | Phím tắt toàn cục (TAB mở inventory) hoạt động mọi scene |

---

## 6. Các hệ thống chính (chi tiết)

### 6.1 GameState — trạng thái trung tâm
- **File:** `scripts/autoload/game_state.gd` (924 dòng).
- Lưu: `current_day`, `current_time`, `energy`/`max_energy`, `health`,
  `gold`, `inventory` (21 ô cố định `{id, amount}`), `toolbar` (5 slot),
  `world_flags` (cờ sự kiện), `npc_relationships`, `discovered_areas`,
  `lore_fragments_found`, `weather_type`, `is_day`.
- Các cờ trạng thái gameplay quan trọng: `is_sleeping`, `is_paused`,
  `game_interacting`, `player_movement_locked`, `cinematic_intro_state`,
  `just_left_inside_house`, `slept_after_2330`.
- **Signals:** `inventory_changed`, `day_changed`, `farm_day_changed`,
  `energy_changed`, `toolbar_changed`.
- Hàm cốt lõi: `advance_day(reset_to_hour)`, `advance_time(hours)`,
  `add_item`/`remove_item`/`has_item`, `set_flag`/`get_flag`/`has_flag`,
  `modify_relationship`.

> **Nguyên tắc:** chỉ `GameState` được phép giữ dữ liệu toàn cục. Hệ thống khác
> đọc/ghi thông qua nó, KHÔNG tự tạo biến global riêng.

### 6.2 Thời gian & ngày (TimeManager + GameState)
- **File:** `scripts/autoload/time_manager.gd` (228 dòng).
- Thời gian chạy 0–24 liên tục; 6:00 = bắt đầu ngày mới; 24:00 wrap về 0.
- Mốc quan trọng: 1:00 (mod 24) → AFK penalty; 6:00 → `advance_day`.
- Hỗ trợ `pause()`, `set_time_scale()`.
- Signals: `time_changed(current_time, is_day)`, `day_changed(new_day)`,
  `hour_elapsed(hour)`.

### 6.3 Farming (FarmTickManager + FarmManager + FarmPlot)
- **State:** `scripts/autoload/farm_tick_manager.gd` (367 dòng) — giữ `cells`
  dict (`"x,y"` → `{type, state, growth_progress, watered, unwatered_streak, …}`),
  chạy `_day_boundary_update` khi `farm_day_changed`. Là **autoload** nên cây
  vẫn phát triển dù player ở scene nào.
- **Render:** `scripts/world/farm/farm_manager.gd` (293 dòng) — scene-side, chỉ
  vẽ tile + route action, **không giữ state**.
- **Tương tác ô đất:** `scripts/world/farm/farm_plot.gd` (637 dòng) — `TileMapLayer`
  quản lý grid + highlight + click chuột (plow/water/plant/harvest).
- **Visual:** `scripts/world/farm/crop_visual_manager.gd` (185 dòng).
- **Enum:** `farm_enums.gd` — `CropState` (EMPTY→PLOWED→SEEDED→SPROUTED→GROWING→
  MATURE/WILTED), `CropType`, map `SEED_TO_CROP`, `CROP_TO_HARVEST`,
  `DEFAULT_WATER_PROFILES`.

> **Gotcha quan trọng:** farming state nằm ở `FarmTickManager` (autoload), KHÔNG
> phải `FarmManager` (scene node). Khi sửa logic farming theo ngày → sửa
> `farm_tick_manager.gd`; khi sửa hiển thị/tương tác → `farm_manager.gd` /
> `farm_plot.gd`.

### 6.4 NPC & lịch trình
- **Base:** `scripts/npc/npc.gd` (615 dòng) — `CharacterBody2D`, state
  (IDLE/WALKING/WORKING/RESTING/SLEEPING…), `schedule` (Array[Dictionary]),
  NavigationAgent2D, avoid logic.
- **Quản lý toàn cục:** `scripts/autoload/npc_manager.gd` (923 dòng) — mỗi NPC
  chỉ có **1 instance duy nhất** xuyên suốt session; spawn/despawn vào scene
  hiện tại dựa trên schedule step (`time`, `state`, `action`, `pos`, `scene`).
  Registry tập trung ở `NPC_REGISTRY`.
- **Marcus (hàng xóm):** `scripts/npc/neighbor.gd` (620 dòng) — day-1 intro
  cutscene, lịch đặc biệt khi chưa gặp player.
- **Voss (chủ shop):** `scripts/npc/shopkeeper.gd` (98 dòng).
- **Lịch trình:** `npc_schedules.gd` (Dwarf-Fortress style, theo ngày/tuần) và
  config `resources/config/npc_schedule_config.json`.
- **Route:** `npc_route_manager.gd` — danh sách route waypoint giữa các map.

### 6.5 Hội thoại (DialogueManager + DialogueUI)
- **File:** `scripts/autoload/dialogue_manager.gd` (554 dòng) +
  `scripts/ui/dialogue_ui.gd` (299 dòng).
- Đọc JSON từ `res://resources/dialogue/{dialogue_id}.json`.
- Cấu trúc JSON: danh sách dòng + tùy chọn (choices) + action.
- Signals: `dialogue_started`, `dialogue_ended`, `dialogue_closed`.

### 6.6 Nhiệm vụ (QuestSystem)
- **File:** `scripts/autoload/quest_system.gd` (958 dòng).
- Loại quest: escort, delivery, investigation, social.
- API: `accept_quest(id)`, `complete_quest(id)`, `is_quest_active(id)`,
  `check_expired_quests()`.
- Bảng tin hàng ngày: `_daily_board_quests` cache theo ngày; quest ngẫu nhiên
  theo cây trồng (`FARM_CROPS`).
- Dữ liệu: `resources/quest/quest_data.json`.
- UI: `scripts/world/quest_board.gd` (world Area2D) + `quest_board_ui.gd`.

### 6.7 Sự kiện, rủi ro & hệ quả
- **EventManager** (`event_manager.gd`): world events, anomalies (horror),
  missed events; cooldown, `MIN_ANOMALY_INTERVAL`.
- **RiskCalculator** (`risk_calculator.gd`): `BASE_RISK` theo hoạt động,
  `WEATHER_MODIFIER`, time modifier, personality, escort, season.
- **EventChainEngine** (`event_chain_engine.gd`): chuỗi nhiều bước, phân nhánh,
  `Outcome` (SAFE/INJURED/DEAD/MISSED/DELAYED), `MAX_CHAIN_LENGTH`.
- **ConsequenceResolver** (`consequence_resolver.gd`): áp dụng hậu quả lên lịch
  (`scene_change`, `event`, `flag_change`, `family_succession`).
- **WorldSimulator** (`world_simulator.gd`): mô phỏng khi player vắng.

### 6.8 Vật phẩm, tool & inventory
- **ItemData** (`resources/items/item_data.gd`): `Resource` định nghĩa vật phẩm —
  `Type` (CONSUMABLE/TOOL/SEED/KEY_ITEM/CURRENCY/MISC), `Category`, `Effect`,
  giá mua/bán, `water_need`, `growth_per_water`.
- **ItemDB** (`resources/items/item_database.gd`): load các `.tres` trong
  `resources/items/definitions/`, tra cứu theo id.
- **ItemHandler** (`item_handler.gd`): `use_item()` phân loại theo `item_type`;
  `use_toolbar_slot()` cho phím 1–5.
- **ItemManager** (`item_manager.gd`): nhặt/thả → `GameState.add_item/remove_item`.
- **ToolHandler** (`tool_handler.gd`): `equip/unequip/is_equipped`.
- **Inventory UI:** `scripts/ui/inventory_ui.gd` (993 dòng) — 21 ô, drag/drop;
  **Shop:** `shop_ui.gd` (677 dòng); **Hotbar:** `hotbar.gd` (480 dòng).

### 6.9 Năng lượng & knock-out
- **File:** `scripts/autoload/energy_manager.gd` (173 dòng).
- Mỗi hành động gọi `spend_energy()`; về 0 → knock-out: fade đen, ngất tại chỗ,
  trừ 25% vàng, giảm 25% tốc độ.
- Ngưỡng vùng đỏ `LOW_ENERGY_THRESHOLD = 5.0` → giảm tốc độ di chuyển.
- Thanh hiển thị: `scripts/ui/energy_bar.gd`.

### 6.10 Lưu/load
- **File:** `scripts/utils/save_manager.gd` (104 dòng) + `scripts/autoload/catch_up_system.gd` (115 dòng).
- 3 slot, file `user://save_game_{slot}.dat` (JSON).
- `CatchUpSystem.prepare_save_data()` gom toàn bộ trạng thái; `apply_save_data()`
  phục hồi.

### 6.11 Thời tiết & mùa
- **File:** `scripts/autoload/weather_system.gd` (445 dòng).
- `Weather` enum (CLEAR/OVERCAST/FOG/DRIZZLE/RAIN/STORM/HEAVY_RAIN/MIST),
  dự báo 3 ngày, anomaly weather, risk theo thời tiết.
- Ánh sáng/hiệu ứng: `scripts/world/atmosphere/atmosphere_manager.gd`.

---

## 7. Scene map (`scenes/`)

| Scene | Vai trò |
|---|---|
| `maps/inside_house_map.tscn` | **Scene khởi động** — bên trong nhà người chơi |
| `maps/farm_map.tscn` | Nông trại người chơi (bản gốc) |
| `maps/farm_map_v2.tscn` | Nông trại bản v2 (build bằng `tools/build_farm_v2.gd`) |
| `maps/Farm_.tscn` | Biến thể farm (thử nghiệm) |
| `maps/town_map.tscn` | Thị trấn |
| `maps/inside_shop_map.tscn` | Bên trong cửa hàng |
| `maps/marcus_farm_map.tscn` | Nông trại Marcus (hàng xóm) |
| `maps/marcus_house_map.tscn` | Nhà Marcus |
| `Player.tscn` | Nhân vật người chơi |
| `npc/neighbor.tscn` | NPC Marcus |
| `npc/shopkeeper.tscn` | NPC chủ shop |
| `ui/dialogue_ui.tscn`, `ui/hotbar.tscn`, `ui/inventory_ui.tscn`, `ui/shop_ui.tscn`, `ui/energy_bar.tscn`, `ui/clock_display.tscn`, `ui/tooltip_panel.tscn` | Các UI |
| `world/bed.tscn`, `world/counter_zone.tscn`, `world/farm/farm_plot.tscn`, `world/farm/crop_visual_manager.tscn`, `world/items/apple.tscn`, `world/quest_board.tscn`, `world/quest_board_ui.tscn` | Vật thể world |
| `tools/atlas_boot.tscn` | Scene chạy script build TileSet |

---

## 8. Resource map (`resources/`)

| Đường dẫn | Nội dung |
|---|---|
| `config/game_config.json` | Thông số game: speed, energy, quest chance, fade… |
| `config/npc_config.json` | Thông số NPC (tên, vị trí, scene, schedule) |
| `config/npc_schedule_config.json` | Lịch trình NPC (284 dòng) |
| `config/money_config.json` | Giá trị tiền tệ (vàng khởi đầu…) |
| `config/ui_text_config.json` | Text UI |
| `config/quest_text_config.json` | Text nhiệm vụ |
| `dialogue/*.json` | Hội thoại (welcome, neighbor*, shopkeeper*, examine_farm_note) |
| `items/item_data.gd` + `items/item_database.gd` | Định nghĩa + database vật phẩm |
| `items/definitions/*.tres` | 22 vật phẩm (seed, crop, harvest, tool, key item…) |
| `quest/quest_data.json` | Định nghĩa nhiệm vụ |
| `localization/vi.json` | Bản dịch tiếng Việt (key → text) |
| `tilesets/farm_tileset.tres` | Tileset nông trại |

---

## 9. Quy ước & quy tắc (bắt buộc)

1. **Comment + `.md` bằng tiếng Việt** — xem
   `.cursor/rules/common/common-vietnamese-documentation.md`. Tên biến/hàm/class
   giữ tiếng Anh.
2. **Docstring GDScript dùng `##`** (hiện trong Godot editor), comment thường
   dùng `#`.
3. **Dữ liệu tách khỏi code:** thông số điều chỉnh được đưa vào
   `resources/config/*.json`, load qua `ConfigManager` — không hardcode.
4. **Ưu tiên signal hơn là poll state** giữa các hệ thống.
5. **Không tạo state global ngoài `GameState`** (trừ các autoload chuyên biệt đã
   có: FarmTickManager giữ state farm, NPCManager giữ registry NPC).
6. **Conventional commits:** `feat(...)`, `fix(...)`, `docs:`, v.v. (xem `RULES.md`).
7. **Group của Godot** dùng để tìm node nhanh: `player`, `farm_manager`,
   `farm_plot`, `farm_tick_manager`, `interactable`, `world_object`,
   `quest_board`, `energy_manager`, `item_manager`, `dialogue_manager`.
8. **Truy cập autoload:** ưu tiên identifier trực tiếp (`GameState.x`); khi cần
   tránh parse error lúc editor chưa reload, dùng `get_node_or_null("/root/…")`
   (xem `farm_manager.gd` `_resolve_farm_tick()`).

---

## 10. Gotchas / điểm dễ vấp (đọc kỹ trước khi sửa)

- **Farm state bị tách đôi:** state + day-boundary logic ở `FarmTickManager`
  (autoload), render ở `FarmManager` (scene). Đừng sửa nhầm chỗ.
- **NPC là instance duy nhất:** `NPCManager` giữ 1 instance/NPC xuyên session;
  scene không tự instantiate NPC. Khi thêm NPC mới → thêm vào `NPC_REGISTRY`
  trong `npc_manager.gd` + tạo `.tscn` trong `scenes/npc/`.
- **`farm_day_changed` ≠ `day_changed`:** `day_changed` = calendar day (có thể
  đổi lúc 00:00); `farm_day_changed` chỉ emit lúc 6:00. FarmTickManager nghe
  `farm_day_changed`.
- **Input chia 3 tầng:** `InputRouter` (TAB toàn cục), `HotkeyInputManager`
  (phím 1–5), `player.gd` (WASD/E). Khi mở dialogue/cutscene thì dùng
  `GameState.player_movement_locked` / `cinematic_intro_state` /
  `DialogueManager.is_active` để chặn.
- **Save đi qua `CatchUpSystem`:** không serialize trực tiếp trong `SaveManager`;
  mọi trạng thái mới cần lưu phải được thêm vào `prepare_save_data()` /
  `apply_save_data()`.
- **Inventory cố định 21 ô:** `GameState._ensure_inventory_slots()` luôn đảm bảo
  đủ entry `{id:"", amount:0}` để drag/drop nhất quán.
- **Có nhiều bản farm map** (`farm_map.tscn`, `farm_map_v2.tscn`, `Farm_.tscn`):
  xác định đúng map đang dùng trước khi sửa bố cục.
- **`atlas_boot.gd` / `build_farm_v2.gd`** là công cụ build (headless), không
  phải logic runtime.

---

## 11. Hướng dẫn onboarding cho agent/session mới

1. Đọc `AGENTS.md` + file này.
2. Đọc `project.godot` để biết danh sách autoload + input map.
3. Đọc `game_state.gd` và `farm_enums.gd` (2 file nền tảng).
4. Xác định tính năng cần làm bằng bảng ở **§3**, mở đúng file.
5. Đọc header comment của file đó (các file đều có docstring tiếng Việt giải
   thích mục đích + cách dùng).
6. Trước khi viết code: tuân thủ quy trình cộng tác trong `AGENTS.md`
   (Question → Options → Decision → Draft → Approval), hỏi trước khi dùng
   Write/Edit, trình draft trước khi sửa nhiều file.
7. Sau khi code: chạy thử (F5/F6), kiểm tra Output/Debugger; dùng
   `tools/smoke_test.gd` / `tools/playtest_harness.gd` nếu cần.
8. Cập nhật file này nếu bạn tạo thư mục/hệ thống mới — để các agent sau không
   phải dò lại.
