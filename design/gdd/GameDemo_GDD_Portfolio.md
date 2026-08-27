# GameDemo — Game Design Document

> **Phiên bản:** Portfolio VI v2  
> **Ngày đối chiếu repository:** 2026-08-27  
> **Engine:** Godot 4.5 / GDScript  
> **Thể loại:** Farming / Life Simulation RPG, 2D top-down  
> **Trạng thái:** Graybox prototype đang phát triển  
> **Mục đích:** Tài liệu GDD đầy đủ đi kèm portfolio ứng tuyển Game Designer Intern  
> **Vai trò khi nộp hồ sơ:** Tài liệu tham chiếu chuyên sâu; đọc sau portfolio tóm tắt và playable build

## 1. Phạm vi và cách đọc tài liệu

Tài liệu này mô tả design intent, gameplay rules và phạm vi hiện tại của **GameDemo**. Các thuật ngữ chuyên ngành như `Core Loop`, `Player Fantasy`, `Systems Design`, `state machine`, `opportunity cost`, `Level Design`, `Game Balancing`, `UX`, `playtest` và `runtime validation` được giữ bằng tiếng Anh để tránh mất nghĩa chuyên môn.

Mọi hạng mục được phân loại theo bốn trạng thái:

| Trạng thái | Ý nghĩa |
|---|---|
| **Đã triển khai** | Có code/scene/data tương ứng trong repository |
| **Có framework, cần validation** | Có implementation nền nhưng chưa có đủ bằng chứng runtime hoặc regression test |
| **Đang phát triển** | Có một phần implementation nhưng chưa tạo thành loop hoàn chỉnh |
| **Tầm nhìn** | Design direction, chưa được trình bày như feature đã hoàn thành |

Tài liệu không coi số lượng script hoặc autoload là bằng chứng trực tiếp về chất lượng Game Design. Bằng chứng chính là: design problem, player action, rule, feedback, consequence và khả năng kiểm chứng.

## 2. Cách dùng tài liệu khi ứng tuyển

Đây là bản GDD đầy đủ, dùng để chứng minh chiều sâu về rules, state, tuning và scope. Người tuyển dụng nên xem portfolio tóm tắt, video playable build và link chơi thử trước; không cần đọc toàn bộ tài liệu này ở vòng đầu. Các mục **Đã triển khai** vẫn cần được đối chiếu bằng runtime evidence trước khi công bố là playable build.

## 3. Tổng quan sản phẩm

### 2.1 One-liner

**GameDemo** là một game farming/life-sim 2D, nơi người chơi xây dựng cuộc sống trong một cộng đồng nhỏ bằng cách trồng trọt, giao dịch, quản lý thời gian và năng lượng, quan sát lịch NPC, thực hiện nhiệm vụ và phản ứng với những thay đổi kéo dài qua nhiều ngày.

### 2.2 Điểm khác biệt định hướng

Farming là nền kinh tế và nhịp sinh hoạt cơ bản. Giá trị dài hạn đến từ việc các hệ thống kết nối với nhau:

```text
Farming
  -> Inventory / Economy
  -> Time & Energy budget
  -> NPC / Quest opportunities
  -> World-state consequences
  -> Kế hoạch cho ngày tiếp theo
```

Một lớp narrative mystery tồn tại dưới đời sống bình thường. Đây là nội dung tùy chọn: người chơi có thể tập trung vào farming, trading và social interaction mà không bị ép phải giải toàn bộ bí ẩn.

### 2.3 Player Fantasy

> “Đây là một cộng đồng đang sống. Tôi có routine riêng, nhưng cách tôi dùng thời gian và đối xử với mọi người sẽ tạo ra câu chuyện của mình.”

Người chơi được kỳ vọng cảm thấy:

- có quyền tự chọn ưu tiên trong ngày;
- có năng lực khi hiểu và tối ưu farming loop;
- có liên kết với NPC thông qua lịch trình, dialogue và quest;
- tò mò khi thế giới xuất hiện những dấu hiệu không hoàn toàn được giải thích;
- chịu trách nhiệm khi quyết định tạo ra consequence ở ngày sau.

## 3. Design Pillars

### 3.1 Mỗi ngày là một decision budget

`Time`, `Energy` và `Gold` giới hạn số hoạt động. Người chơi không thể farm, trade, socialize và explore tối đa trong cùng một ngày.

### 3.2 Cộng đồng tồn tại ngoài tầm nhìn của người chơi

NPC có state, schedule, scene hiện tại và route. Mục tiêu là để người chơi gặp NPC tại nơi hợp lý theo thời gian, thay vì NPC luôn chờ tại một điểm cố định.

### 3.3 Information hỗ trợ inference

Thông tin phải giúp người chơi hình thành hypothesis và ra quyết định. Uncertainty không được biến thành opacity: người chơi có thể đoán sai, nhưng phải có khả năng giải thích vì sao họ đã chọn như vậy.

### 3.4 Consequence có continuity

Một quyết định tốt cho design không nhất thiết tạo ra cutscene lớn. Nó có thể thay đổi giờ mở cửa, dialogue, relationship, quest, schedule hoặc khả năng tiếp cận resource trong ngày kế tiếp.

### 3.5 Mystery được khám phá, không áp đặt

Horror/mystery được thể hiện qua sai lệch nhỏ, item, dialogue và world state. Farming/life-sim loop vẫn phải đứng vững nếu người chơi không theo đuổi lớp nội dung này.

## 4. Target Player và trải nghiệm mục tiêu

### 4.1 Target Player

- Người thích farming/life-sim có nhịp chơi chậm.
- Người thích Systems Design và world state có liên kết.
- Người thích quan sát NPC, routine và environmental storytelling.
- Người chấp nhận graybox prototype nếu gameplay intent rõ ràng.

### 4.2 Không phải trọng tâm hiện tại

- Combat-heavy RPG.
- Multiplayer hoặc competitive play.
- Final-art showcase.
- Economy hoặc live-ops hoàn chỉnh.

## 5. Core Gameplay Loop

### 5.1 Micro Loop — 10 đến 30 giây

```text
Chọn tool/item
  -> xác định ô hoặc target
  -> thực hiện hành động
  -> nhận feedback trạng thái
  -> cập nhật Energy / Inventory
```

Ví dụ: chọn hoe → cày ô đất hợp lệ → ô chuyển sang `PLOWED` → tiêu hao 1 Energy.

### 5.2 Daily Loop — một ngày trong game

```text
Quan sát ngày mới
  -> lập kế hoạch
  -> farm / mua / bán / giao tiếp / nhận quest
  -> điều chỉnh theo Time và Energy
  -> trở về ngủ hoặc chịu knockout
  -> ngày mới cập nhật crop, quest và NPC schedule
```

### 5.3 Session Loop

```text
Ổn định routine
  -> tăng resource và knowledge
  -> nhận quest / phát hiện pattern NPC
  -> đưa ra quyết định có trade-off
  -> quan sát consequence
  -> điều chỉnh strategy
```

### 5.4 Long-term Loop — Tầm nhìn

Tăng năng lực kinh tế, xây relationship, hiểu cộng đồng và mở dần lớp mystery. Dynamic Market, Negotiation và narrative arc hoàn chỉnh thuộc **Tầm nhìn**, chưa phải bằng chứng hiện tại.

## 6. Player Actions và điều khiển

| Action | Input mặc định | Trạng thái |
|---|---|---|
| Di chuyển bốn hướng | WASD | Đã triển khai |
| Interact | E | Đã triển khai |
| Sprint | X | Đã triển khai; tuning cần playtest |
| Inventory | Tab | Đã triển khai framework |
| Chọn Toolbar | 1–5 | Đã triển khai |
| Farm action | Chuột/tool tùy context | Đã triển khai framework; edge case cần validation |

Interaction sử dụng raycast priority và proximity fallback. Khi UI hoặc dialogue chiếm focus, input được route để tránh player đồng thời điều khiển world.

## 7. Time và Energy

### 7.1 Design Purpose

Time tạo deadline tự nhiên; Energy giới hạn số action. Hai resource này phải tạo `opportunity cost`, không chỉ tạo inconvenience.

### 7.2 Luật hiện tại

| Parameter | Initial tuning | Ghi chú |
|---|---:|---|
| Max Energy | 20 | Đọc từ config |
| Low Energy threshold | 5 | Kích hoạt trạng thái vùng đỏ |
| Farm action cost | 1 Energy | Plow, plant, water, harvest, clear wilted |
| Low Energy move multiplier | 0.75 | Actual code value; cần thống nhất comment và UX text |
| Knockout gold loss | 25% | Làm tròn lên |
| Knockout Energy sau tỉnh | Tối đa 5 | Không hồi đầy như ngủ đúng giờ |
| Knockout speed penalty | ×0.75 | Giữ tới khi được reset đúng flow |

Ngủ muộn sau 23:30 có rule giới hạn Energy hồi phục ở 75% max. Knockout và AFK penalty đã có logic nhưng cần regression test cho day boundary, spawn và save/load.

### 7.3 Experiential Goal

- Người chơi nhìn thấy Energy thấp trước khi bị phạt.
- Failure phải giải thích được và cho phép recovery.
- Routine cơ bản không được tiêu hết Energy trước khi người chơi hiểu hệ thống.

## 8. Farming System

### 8.1 State Machine

```text
EMPTY -> PLOWED -> SEEDED -> SPROUTED -> GROWING -> MATURE
   ^                                                     |
   |---------------------- HARVEST ----------------------|

SEEDED / SPROUTED / GROWING -> WILTED
WILTED -> PLOWED sau khi dọn
```

### 8.2 Các loại crop hiện tại

- Wheat
- Corn
- Tomato
- Potato
- Turnip
- Mystery Plant

### 8.3 Player-facing Rules

1. Chỉ có thể gieo seed trên ô đã `PLOWED`.
2. Water và growth state được lưu theo ngày.
3. Crop thiếu chăm sóc có thể `WILTED`.
4. Harvest trả item vào Inventory/Toolbar theo rule hiện tại.
5. Chỉ action hợp lệ mới nên tiêu hao Energy.

### 8.4 Trạng thái

**Có framework, cần validation.** Basic crop cycle và persistent state đã có. Invalid action transaction, harvest cost/yield và visual feedback vẫn cần runtime/playtest pass.

## 9. Inventory, Toolbar và Item

### 9.1 Cấu trúc hiện tại

- 21 Inventory slots.
- 5 Toolbar slots gắn phím 1–5.
- Item có type, stack size, buy/sell price và effect.
- Repository có 22 item definitions.

### 9.2 Design Purpose

Inventory là giới hạn chuẩn bị; Toolbar là lớp ưu tiên moment-to-moment. Việc chuyển item giữa Inventory và Toolbar phải rõ nguồn và atomic để không duplicate hoặc xóa sai stack.

### 9.3 Trạng thái

**Có framework, cần validation.** Drag/drop, swap và consume đã có code. Fixed-slot integrity và cross-inventory removal vẫn cần regression test.

## 10. Economy và Trading

### 10.1 Nền kinh tế hiện tại

```text
Mua seed/tool
  -> farm
  -> harvest
  -> bán produce
  -> nhận Gold
  -> tái đầu tư
```

Item có thể có `sell_price` riêng. Nếu không có, fallback là:

```text
Sell Price = Buy Price × 0.5
```

Basic buy/sell UI và Gold state đã có. Transaction source matching và economy balance chưa được xác nhận bằng playtest.

### 10.2 Faucet và Sink hiện tại

| Loại | Nguồn/đích |
|---|---|
| Faucet | Bán produce, quest reward |
| Sink | Mua seed, tool, item; knockout mất 25% Gold |

### 10.3 Tầm nhìn

Dynamic Market và Negotiation chưa được triển khai như loop hoàn chỉnh. Hướng design là để price/availability phản ứng với supply, demand, weather, event và NPC need; mọi biến động cần có dấu hiệu player-facing.

## 11. NPC và Social Simulation

### 11.1 NPC Model

NPC framework hỗ trợ:

- persistent runtime instance;
- state và schedule step;
- scene hiện tại;
- route progress;
- interaction/dialogue;
- relationship;
- serialize/load state nền tảng.

### 11.2 Case Study — Marcus

Marcus là case study rõ nhất cho Technical Design và Systems Design.

**Vấn đề ban đầu:** NPC đổi map bằng schedule target dẫn đến teleport, sai portal hoặc route cũ bị áp dụng lại.

**Design contract mới:**

```text
Schedule target
  -> Route source waypoint
  -> NPC di chuyển bằng velocity
  -> Source portal handoff
  -> Destination portal arrival
  -> Post-arrival movement
  -> Chờ schedule step tiếp theo
```

Day 1 có intro flow riêng. Từ Day 2, Marcus có routine qua Marcus House, Marcus Farm, Town và Inside Shop.

### 11.3 Điều đã làm được

- Tách schedule, route và portal thành ba trách nhiệm khác nhau.
- Thiết kế persistent NPC state thay vì spawn actor độc lập theo scene.
- Lưu `route_id`, waypoint index, scene và position trong runtime state.
- Thêm route catalog/manager và handoff hook giữa scene.
- Viết schedule và dialogue theo thời điểm cho Marcus.

### 11.4 Giới hạn

Cross-scene route, obstacle navigation, save/load giữa route và mọi cặp map chưa có test report đầy đủ. Vì vậy hệ thống được ghi là **Có framework, cần validation**, không phải hoàn chỉnh.

## 12. Dialogue và Localization

### 12.1 Dialogue

Dialogue framework hỗ trợ JSON data, typewriter, choices, input blocking và direction theo state. Marcus có intro, idle dialogue theo thời điểm, delivery và quest-complete dialogue.

### 12.2 Localization

Vietnamese localization catalog đã có cho UI, quest, NPC và item text. Một số fallback/comment/data vẫn còn tiếng Anh; chiến lược dài hạn cần chốt VN-only hay multi-language.

### 12.3 Design Purpose

Dialogue không chỉ truyền lore. Nó phải cung cấp information, thể hiện relationship/state và giúp player hiểu objective hoặc consequence.

## 13. Quest System

### 13.1 Tính năng hiện tại

- Quest Board và UI.
- Static quest definitions.
- Dynamic delivery quest theo crop/item thật trong game.
- Daily quest cache.
- Deadline 2–3 ngày cho quest phù hợp.
- Gold và relationship reward.
- Duplicate-item rejection cho delivery quest.
- Dialogue giao item cho đúng NPC.

### 13.2 Dynamic Delivery Loop

```text
Quest Board tạo yêu cầu
  -> player nhận quest
  -> produce / giữ / mua resource
  -> chọn đúng item trên Toolbar
  -> giao cho NPC
  -> Gold + relationship thay đổi
```

### 13.3 Design Purpose

Quest sử dụng core resource thay vì tạo minigame tách biệt. Nó tạo mục tiêu ngắn hạn, deadline và lý do để player kết nối farming với social interaction.

### 13.4 Trạng thái

**Đã triển khai framework; cần playtest.** Quest Board và dynamic delivery có code/scene/data. Difficulty, appearance chance, deadline và reward curve là initial tuning.

## 14. Event, Consequence và Mystery

### 14.1 Event Structure mục tiêu

```text
Trigger
  -> Information
  -> Player decision
  -> Outcome
  -> Consequence
  -> World-state change
```

### 14.2 Existing Framework

Risk calculation, event chain, consequence resolver, weather, family registry và world flags đã có code nền. Tuy nhiên TODO hiện ghi rõ một số chain chưa được nối end-to-end và nhiều consequence/content còn thiếu.

### 14.3 Mystery Direction

Mystery Plant, strange fruit, lore fragment và các event kỳ lạ là layer nội dung đang phát triển. Chúng không được mô tả như một mystery arc đã hoàn thành.

### 14.4 Design Constraint

Randomness chỉ có giá trị khi người chơi có information và agency. Nếu outcome không thể đọc hoặc học, RNG trở thành noise.

## 15. World và Level Design

### 15.1 Existing Maps

- Player Farm
- Inside House
- Town
- Inside Shop
- Marcus Farm
- Marcus House
- Các farm layout/tool scene thử nghiệm

### 15.2 Spatial Goals

- Farm cho phép đọc nhanh nhà, ruộng và route ra town.
- Portal phải nhất quán giữa source/destination.
- NPC route phải nhìn thấy được khi player cùng map.
- Shop tập trung Quest Board, buy/sell và social interaction.
- Marcus Farm/House tạo bằng chứng rằng NPC có home/work routine.

### 15.3 Onboarding Beats đề xuất

1. Rời nhà và gặp Marcus.
2. Học interaction/dialogue.
3. Thực hiện plow → plant → water.
4. Đi town/shop và đọc Quest Board.
5. Ngủ để thấy crop/NPC/quest tiến triển qua ngày.

Đây là `Level Design` direction; chưa có playtest data chứng minh pacing cuối cùng.

## 16. UI/UX và Feedback

### 16.1 Existing UI

- HUD ngày/Gold/Energy.
- Inventory và Toolbar.
- Shop UI.
- Dialogue UI.
- Quest Board UI.
- Sleep prompt.
- Interaction prompt và floating warning.

### 16.2 UX Principles

- Action thất bại phải nói rõ thiếu Energy, sai target hay Inventory đầy.
- UI focus không để input xuyên xuống world.
- Quest phải thể hiện objective, deadline và reward.
- Low Energy và late-time warning phải xuất hiện trước penalty.
- Consequence phải được nhận ra trong cùng session hoặc ngày kế tiếp.

## 17. Progression

### 17.1 Hiện tại

- Resource progression: seed → crop → Gold → seed/tool.
- Knowledge progression: hiểu farm state, NPC schedule và quest pattern.
- Relationship progression: reward/penalty theo quest.

### 17.2 Tầm nhìn

- Dynamic Market mastery.
- Negotiation.
- Friendship/romance split.
- Complete mystery/lore progression.
- Tool/crop/content expansion.

## 18. Game Balancing Framework

Các giá trị hiện tại là `initial tuning` trừ khi có playtest report.

| Tuning knob | Giá trị hiện tại | Hypothesis cần kiểm tra |
|---|---:|---|
| Max Energy | 20 | Đủ cho routine cơ bản và một lựa chọn phụ |
| Farm action cost | 1 | Dễ hiểu, nhưng không làm mọi action đồng giá trị mãi mãi |
| Low Energy threshold | 5 | Cảnh báo đủ sớm trước knockout |
| Sell fallback ratio | 0.5 | Produce tạo lợi nhuận mà không vô hiệu hóa economy |
| Base quest chance | 0.5 | Quest xuất hiện đủ thường xuyên nhưng không ép mỗi ngày |
| Delivery deadline | 2–3 ngày | Tạo planning nhưng không phụ thuộc RNG crop bất công |
| Quest Gold | 25–125 | Reward tỷ lệ với required amount |

### 18.1 Validation Plan

- 3–5 người chưa đọc GDD, mỗi người 15–20 phút.
- Ghi funnel: intro → farm action → shop → quest → sleep.
- Đo time-to-first-farm-action, time-to-shop, Energy còn lại khi ngủ.
- Hỏi player có hiểu vì sao họ thất bại và Marcus đang đi đâu không.
- Ghi `Initial → Observed problem → Revision → Result` cho mỗi iteration.

Repository hiện chưa có dataset playtest chính thức; tài liệu không tuyên bố đã validate fun hoặc final balance.

## 19. Technical Design liên quan trực tiếp tới Game Design

Technical Design là một thế mạnh của project, nhưng chỉ có giá trị khi giúp design kiểm chứng được:

- Config/data cho Energy, player, inventory và quest.
- State machine cho farm, NPC và quest.
- Persistent `GameState` qua scene.
- Signal-driven communication.
- NPC route/schedule separation.
- Save schema nền cho world/NPC state.
- Localization catalog.

Implementation detail không thay thế design rationale; nó là bằng chứng rằng rule đã được chuyển thành prototype.

## 20. Scope Matrix

| Hệ thống | Trạng thái hiện tại |
|---|---|
| Player movement/interaction | Đã triển khai |
| Farming core cycle | Có framework, cần validation |
| Time/day | Có framework, cần validation |
| Energy/knockout | Đã triển khai rule; cần regression test |
| Inventory/Toolbar | Có framework, cần validation |
| Fixed-price buy/sell | Có framework, cần playtest |
| Marcus dialogue/schedule | Đã triển khai data và runtime framework |
| Persistent NPC route | Có framework, cần validation |
| Quest Board/dynamic delivery | Đã triển khai framework, cần playtest |
| Vietnamese localization | Đang triển khai; chưa phủ toàn bộ text |
| Event/consequence | Đang phát triển |
| Mystery layer | Có một phần / Tầm nhìn |
| Dynamic Market | Tầm nhìn |
| Negotiation | Tầm nhìn |
| Advanced social/romance | Tầm nhìn |
| Final art/audio | Ngoài scope prototype hiện tại |
| Automated tests/playtest dataset | Chưa có |

## 21. Known Limitations và Risk

- Invalid UID và missing scene references cũ cần được xử lý/kiểm tra lại.
- NPC pathfinding quanh obstacle chưa hoàn chỉnh.
- Save/load round-trip cho NPC giữa route chưa được xác nhận.
- Một số farm/inventory/shop transaction edge case cần regression test.
- Event chain chưa có đủ player-facing information và consequence content.
- Audio chưa phải bằng chứng của prototype.
- Một số comment/config/doc count đã lệch implementation và cần sync định kỳ.

## 22. Roadmap theo Scope

### Milestone A — Playable Evidence

1. Chạy smoke test từ intro → farm → shop → quest → sleep.
2. Sửa blocking UID/reference.
3. Ghi video 2–3 phút và screenshot có annotation.

### Milestone B — NPC Vertical Slice

1. Validate Marcus qua mọi route chính.
2. Test save/load giữa route.
3. Bổ sung obstacle pathfinding hoặc giới hạn route hợp lệ.

### Milestone C — Game Design Validation

1. Playtest Time/Energy routine.
2. Tune Quest appearance/deadline/reward.
3. Ghi before/after iteration report.

### Milestone D — Content Direction

1. Nối một event/consequence end-to-end.
2. Chốt Mystery Plant hook.
3. Quyết định Dynamic Market có nằm trong vertical slice hay không.

## 23. Acceptance Criteria cho Portfolio Build

- [ ] Người chơi hiểu farm action cơ bản mà không cần đọc GDD.
- [ ] Có thể hoàn thành plow → plant → water → sleep → growth.
- [ ] Inventory/Toolbar không duplicate hoặc mất sai item trong flow chính.
- [ ] Buy/sell cập nhật đúng item và Gold.
- [ ] Quest Board tạo/nhận dynamic delivery quest và giao đúng NPC.
- [ ] Marcus xuất hiện đúng scene/state ở các mốc chính.
- [ ] NPC dùng đúng portal khi chuyển map trong route đã chọn.
- [ ] Save/load không phá day, inventory, quest hoặc NPC route state.
- [ ] Low Energy/knockout có warning, penalty và recovery dễ hiểu.
- [ ] Video portfolio chỉ trình bày feature vượt qua smoke test.

## 24. Tóm tắt đóng góp Game Design

Qua prototype này, tôi đã thực hiện:

- xác định Player Fantasy và Core Loop;
- thiết kế daily decision budget bằng Time/Energy;
- formalize farming state machine và action rules;
- thiết kế economy faucet/sink cơ bản;
- xây Quest Board và dynamic delivery loop gắn farming với NPC;
- thiết kế Marcus schedule, route contract và persistent world state;
- phân tách implemented/planned scope;
- chuyển bug runtime thành design constraint có thể tái sử dụng;
- xây validation plan cho balancing và player comprehension.

Điểm mạnh nổi bật nhất là **Systems Design kết hợp Technical Design**: chuyển rule và world-state relationship thành prototype có thể kiểm chứng, đồng thời nhận diện rõ phần chưa được playtest.

## 25. Bài trình bày 2–3 phút

> GameDemo là một farming/life-sim 2D nơi người chơi xây dựng routine trong một cộng đồng nhỏ. Trong game, người chơi cày đất, gieo hạt, tưới và thu hoạch; sau đó mang sản phẩm đi bán, mua resource, nhận quest và tương tác với NPC có lịch trình riêng. Điểm tôi muốn tạo ra không chỉ là cảm giác hoàn thành checklist, mà là cảm giác mỗi ngày người chơi phải chọn điều gì quan trọng với mình.
>
> Core Loop của game là: quan sát trạng thái ngày mới, lập kế hoạch, thực hiện farming hoặc hoạt động xã hội, quản lý Time và Energy, rồi ngủ để crop, quest và NPC chuyển sang state tiếp theo. Sang ngày mới, người chơi nhìn thấy kết quả và điều chỉnh kế hoạch.
>
> Mechanic cốt lõi nhất là daily decision loop được tạo bởi Time/Energy kết hợp với NPC schedule và quest opportunity. Ví dụ, người chơi có thể tiếp tục chăm ruộng để bảo vệ sản lượng, hoặc rời farm để gặp Marcus, nhận nhiệm vụ và mở thêm relationship. Nếu cố làm tất cả, họ có nguy cơ cạn Energy hoặc bỏ lỡ một time window.
>
> Tôi cho rằng mechanic này tạo ra trải nghiệm mong muốn vì nó hỗ trợ ba cảm giác: Autonomy khi player tự chọn ưu tiên, Competence khi họ hiểu system và tối ưu routine, và Relatedness khi lịch NPC khiến cộng đồng tồn tại ngoài player. Prototype hiện đã có farming, Energy, Quest Board, dynamic delivery và Marcus schedule/route framework. Phần tôi chưa coi là hoàn thành là balancing qua playtest, NPC route regression, Dynamic Market và mystery arc. Vì vậy bước tiếp theo của tôi là validate một vertical slice end-to-end thay vì tiếp tục thêm feature.

## 26. Tài liệu và bằng chứng tham chiếu

- `project.godot` — input, main scene, autoload registry.
- `resources/config/game_config.json` — initial tuning.
- `scripts/autoload/energy_manager.gd` — Energy/knockout rules.
- `scripts/world/farm/farm_plot.gd`, `farm_manager.gd` — farming rules.
- `scripts/autoload/quest_system.gd` — Quest Board/dynamic delivery data.
- `scripts/npc/neighbor.gd` — Marcus design implementation.
- `scripts/npc/npc.gd`, `scripts/autoload/npc_manager.gd`, `npc_route_manager.gd` — persistent NPC route framework.
- `resources/localization/vi.json` — Vietnamese localization catalog.
- `TODO.md` — known issues, validation gaps và roadmap.

---

**Ghi chú trung thực:** Đây là GDD của một prototype cá nhân đang phát triển. “Có code” không được dùng như đồng nghĩa với “đã cân bằng” hoặc “đã chứng minh vui”. Tài liệu chỉ gọi một kết quả là validated khi có runtime evidence, playtest note hoặc regression test tương ứng.
