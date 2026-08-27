# Game Design Portfolio — Ứng tuyển Falcon Game Studio

> **Ứng viên:** [Họ và tên]  
> **Vị trí:** Game Designer Intern  
> **Dự án cá nhân:** GameDemo  
> **Vai trò:** Game Designer / Systems Designer / Technical Designer  
> **Engine:** Godot 4.5 / GDScript  
> **Ngày cập nhật:** 2026-08-27  
> **Khuyến nghị gửi:** Dùng bản này làm portfolio chính; GDD đầy đủ đi kèm làm tài liệu tham chiếu

## 1. Em muốn thể hiện điều gì qua project này?

GameDemo là một prototype farming/life-sim 2D đang ở giai đoạn graybox. Em làm project này để thử trả lời một câu hỏi thiết kế:

> Làm thế nào để những hoạt động quen thuộc như trồng trọt, mua bán và giao tiếp với NPC tạo ra những lựa chọn có ý nghĩa, thay vì chỉ trở thành một checklist lặp đi lặp lại?

Em không xem đây là một sản phẩm đã hoàn thiện. Điều em muốn thể hiện qua portfolio là cách em:

- xác định Player Fantasy và Core Loop;
- chuyển design intent thành rule, state và data;
- thiết kế các hệ thống liên kết thay vì feature tách rời;
- phân tích bug runtime như một vấn đề design contract;
- kiểm soát scope và ghi rõ implementation status;
- xây kế hoạch playtest/validation thay vì gọi initial tuning là final balance.

## 2. Em đang mạnh ở đâu?

Sau khi đối chiếu lại GDD với phần implementation, em thấy thế mạnh rõ nhất của mình là:

### 2.1 Systems Design

Em thường nhìn một trải nghiệm dưới dạng mối quan hệ giữa resource, state, feedback và consequence. Trong GameDemo:

```text
Time + Energy
  -> giới hạn hành động
Farming
  -> tạo item
Inventory / Economy
  -> chuyển item thành khả năng chuẩn bị
Quest / NPC
  -> tạo mục tiêu và relationship
Sleep / Day change
  -> cập nhật crop, schedule và state
```

### 2.2 Technical Design

Em có thể chuyển rule thành prototype và trao đổi với programmer bằng ngôn ngữ cụ thể: state machine, ownership, signal, data schema, transition và edge case. Điểm này giúp em không dừng ở ý tưởng, nhưng em hiểu implementation không thay thế playtest.

### 2.3 NPC và World-state Design

Marcus là bằng chứng rõ nhất: em thiết kế NPC như một persistent entity có schedule, scene, route và state thay vì actor spawn lại theo map. Em đã chuyển lỗi teleport/sai portal thành một route contract có thể tái sử dụng.

### 2.4 Documentation và Scope Management

Em phân biệt rõ `Đã triển khai`, `Có framework nhưng cần validation`, `Đang phát triển` và `Tầm nhìn`. Cách này giúp design doc không hứa quá phần implementation, đồng thời làm rõ milestone tiếp theo.

### 2.5 Những năng lực đang phát triển

- Level Design có player-flow và pacing evidence.
- Game Balancing dựa trên playtest/data thay vì cảm tính.
- UX validation với người chơi chưa biết design.
- Data Analysis và iteration report.
- Làm việc trong cross-functional team thay vì solo workflow.

## 3. Game là gì và người chơi thực sự làm gì?

GameDemo là một farming/life-sim 2D. Người chơi:

- cày đất, gieo hạt, tưới, chờ crop phát triển và thu hoạch;
- sắp xếp item trong Inventory/Toolbar;
- mua seed/tool và bán produce;
- quản lý Time, Energy và Gold;
- trò chuyện với NPC, theo dõi routine và relationship;
- đọc Quest Board, nhận dynamic delivery quest và giao đúng resource;
- ngủ để chuyển ngày và quan sát thế giới thay đổi.

Một lớp mystery nằm dưới đời sống bình thường nhưng chưa phải core requirement. Người chơi có thể trải nghiệm farming/social loop mà không bị ép theo mystery.

## 4. Core Gameplay Loop

```text
Quan sát trạng thái ngày mới
  -> chọn ưu tiên
  -> farm / trade / interact / quest
  -> tiêu Time và Energy
  -> nhận reward hoặc consequence
  -> ngủ
  -> crop, NPC và quest chuyển state
  -> cập nhật kế hoạch
```

Mechanic cốt lõi nhất là **daily decision loop**: Time/Energy tạo decision budget, còn NPC schedule và quest tạo opportunity window. Farming là nền kinh tế giúp người chơi chuẩn bị cho các lựa chọn đó.

## 5. Case Study 1 — Daily Decision Loop

### 5.1 Design Goal

Em muốn mỗi ngày có ít nhất một lựa chọn khiến người chơi không thể tối ưu mọi mục tiêu cùng lúc.

Ví dụ:

- Ở lại farm để hoàn tất routine và bảo vệ crop.
- Đi town sớm để nhận quest hoặc mua seed.
- Gặp Marcus theo schedule để giao item và tăng relationship.
- Tiết kiệm Energy hoặc chấp nhận rủi ro knockout.

### 5.2 Mechanics đã triển khai

| Mechanic | Initial rule |
|---|---:|
| Max Energy | 20 |
| Farm action cost | 1 Energy |
| Low Energy threshold | 5 |
| Low Energy move multiplier | 0.75 |
| Knockout Gold loss | 25% |
| Toolbar | 5 slot |
| Inventory | 21 slot |

### 5.3 Design Rationale

- Time tạo urgency và time window.
- Energy giới hạn volume hành động.
- Gold loss tạo consequence nhưng không xóa toàn bộ progress.
- Toolbar tạo preparation layer giữa Inventory và action.

### 5.4 Giới hạn hiện tại

Các số trên mới là `initial tuning`. Repository chưa có playtest dataset để chứng minh daily loop đã đạt nhịp tốt. Em cần đo routine duration, Energy còn lại và lý do người chơi đổi kế hoạch.

## 6. Case Study 2 — Marcus: Persistent NPC và Schedule

### 6.1 Design Problem

NPC schedule ban đầu dễ bị xử lý như lệnh teleport: đến mốc giờ, NPC đổi scene hoặc xuất hiện ở target. Điều này phá cảm giác “cộng đồng đang sống”.

### 6.2 Iteration

Em tách bốn khái niệm:

1. `Schedule target`: NPC cần ở đâu theo thời gian.
2. `Route source`: waypoint NPC phải đi tới trước khi rời map.
3. `Portal arrival`: điểm xuất hiện hợp lệ ở map đích.
4. `Post-arrival target`: vị trí NPC tiếp tục đi tới sau handoff.

```text
Persistent NPC instance
  -> schedule chọn objective
  -> velocity movement tới source portal
  -> scene handoff
  -> destination portal
  -> post-arrival movement
  -> tiếp tục routine
```

### 6.3 Điều tôi đã làm

- Thiết kế schedule Day 1 và routine từ Day 2 cho Marcus.
- Tách route data khỏi schedule data.
- Thiết kế route progress gồm `route_id`, waypoint index, scene và position.
- Giữ một runtime instance do NPCManager quản lý.
- Nối dialogue theo thời điểm và quest state.
- Ghi limitation về navigation/save-load thay vì gọi system hoàn chỉnh.

### 6.4 Giá trị Game Design

Đây không chỉ là sửa code. Iteration này làm rõ rule player-facing: NPC phải di chuyển theo không gian hợp lý, đi qua portal nhìn thấy được và giữ continuity khi người chơi đổi map.

### 6.5 Giới hạn hiện tại

Cross-scene route và save/load giữa route vẫn cần regression test. Obstacle pathfinding chưa hoàn chỉnh.

## 7. Case Study 3 — Quest Board và Dynamic Delivery

### 7.1 Design Goal

Quest không nên tách khỏi farming loop. Dynamic delivery dùng chính crop/item mà người chơi sản xuất để tạo deadline, Gold reward và relationship change.

### 7.2 Player Flow

```text
Mở Quest Board
  -> đọc yêu cầu / deadline / reward
  -> nhận quest
  -> farm, mua hoặc giữ resource
  -> chọn đúng item trên Toolbar
  -> giao cho đúng NPC
  -> nhận Gold + relationship
```

### 7.3 Rules đã triển khai

- Quest Board và UI.
- Daily quest cache.
- Dynamic delivery quest theo crop thật.
- Required amount 1–5.
- Deadline ban đầu 2–3 ngày.
- Gold reward 25–125 theo amount.
- Relationship reward và fail penalty.
- Chặn hai delivery quest yêu cầu cùng item.

### 7.4 Design Value

System này nối ba loop: farming tạo resource, quest tạo mục tiêu, NPC tạo social context. Đây là ví dụ rõ về việc tôi thiết kế feature để củng cố Core Loop thay vì tăng feature count.

### 7.5 Giới hạn hiện tại

Appearance chance, reward curve, deadline và communication UX chưa được playtest. Đây là framework hoạt động ở mức code/scene, không phải final balance.

## 8. Năng lực Game Design được thể hiện

| Năng lực | Bằng chứng trong project | Mức hiện tại |
|---|---|---|
| Game Concept / Player Fantasy | Daily life trong community có continuity | Có định hướng rõ |
| Gameplay Design | Farming, interaction, quest, sleep loop | Prototype |
| Systems Design | Time/Energy/Farm/Economy/NPC/Quest liên kết | Thế mạnh |
| Technical Design | State, route, data, transition, persistence | Thế mạnh |
| Economy Design | Faucet/sink cơ bản, buy/sell, reward | Nền tảng; cần balance |
| NPC/Social Design | Marcus schedule, relationship, dialogue | Có bằng chứng mạnh |
| Narrative Design | Optional mystery, state-based dialogue | Partial |
| Quest Design | Quest Board + dynamic delivery | Có framework |
| Level Design | Farm/town/shop/Marcus route và onboarding beats | Có nền tảng; thiếu playtest |
| Game Balancing | Config và tuning knobs | Initial tuning; chưa validated |
| UX Design | Focus/input routing, prompts, warnings | Có implementation; cần user test |
| Data Analysis | Validation plan/funnel đề xuất | Chưa có dataset |
| Scope Management | Status matrix, known limitations, roadmap | Thế mạnh |

## 9. Những gì đã có và chưa có

### 9.1 Đã triển khai hoặc có bằng chứng code/scene

- Player movement, interaction và sprint.
- Farming state/action framework.
- Energy, low-energy và knockout rules.
- Inventory, Toolbar và item database.
- Fixed-price buy/sell framework.
- Dialogue JSON, choice và state direction.
- Marcus NPC, schedule và route framework.
- Quest Board và dynamic delivery quest.
- Relationship state và reward/penalty.
- Vietnamese localization catalog.
- Save schema và persistent world-state foundation.

### 9.2 Có framework nhưng cần runtime validation

- Farming transaction edge cases.
- Inventory/Toolbar exact-source removal.
- Buy/sell atomic transaction.
- NPC cross-scene route.
- Save/load khi NPC giữa route.
- Time/day/AFK boundary.
- Event/consequence integration.

### 9.3 Tầm nhìn, không trình bày như feature hoàn thành

- Dynamic Market.
- Negotiation.
- Advanced social/romance.
- Mystery arc hoàn chỉnh.
- Final art/audio/content volume.
- Data-driven balancing từ live/playtest data.

## 10. Game Balancing và Validation Mindset

Em phân biệt ba loại dữ liệu:

1. `Initial tuning`: giá trị để prototype chạy.
2. `Simulation result`: kết quả từ rule/code, chưa đại diện cho trải nghiệm người chơi.
3. `Playtest result`: quan sát người chơi thật, dùng để quyết định iteration.

### Kế hoạch playtest tối thiểu

- 3–5 người chưa đọc GDD.
- Chơi 15–20 phút.
- Ghi funnel: intro → farm → shop → quest → sleep.
- Đo time-to-first-action, Energy còn lại và số lần không hiểu failure.
- Hỏi người chơi có nhận ra pattern của Marcus không.
- Ghi bảng `Initial → Problem → Revision → Result`.

Em chưa có dataset này nên chưa thể nói project đã được balance.

## 11. Tại sao Falcon Game Studio?

Em quan tâm đến Falcon vì đây là môi trường để designer làm việc trực tiếp với level, difficulty, UX và data trong quy trình sản xuất thực tế. GameDemo là farming/life-sim, không phải puzzle; em không đánh đồng hai genre. Giá trị chuyển đổi nằm ở khả năng formalize objective/constraint/state, xây data-driven rules, phân tích failure path, thiết kế progression và lập kế hoạch playtest. Tại Falcon, em muốn chuyển nền tảng Systems/Technical Design này thành năng lực Level Design, Game Balancing và Data Analysis trong một team production.

### 11.1 Thông tin công khai đã kiểm chứng

Tại thời điểm 2026-08-27, trang tuyển dụng chính thức của Falcon có vị trí **Game Designer Intern [F01]**. Nội dung công khai nhấn mạnh các công việc như `Level Design`, `Game Balancing` và `Data Analysis` cho game Puzzle. Danh mục game chính thức của Falcon có các sản phẩm như **Goods Puzzle: Sort Challenge**, **Screw Puzzle**, **Color Water Sort Wooden Puzzle**, **Match Family Tile Puzzle**, bên cạnh **1945 Air Force**, **Galaxiga** và **Falcon Squad**.

Nguồn:

- [Falcon Game Designer Intern F01](https://falcongames.com/tuyen_dung/hn-f01-game-designer-intern-15m-net/?lang=vi)
- [Falcon Career](https://falcongames.com/career/)
- [Falcon Games](https://falcongames.com/game/)

### 11.2 Điểm phù hợp thật sự

Project của em không phải puzzle game, vì vậy em không đánh đồng farming/NPC simulation với puzzle level. Transferable skills của em là:

- formalize objective, constraint và state;
- xây hệ thống data-driven có tuning knobs;
- phân tích edge case và failure path;
- thiết kế progression từ mechanic đơn lẻ tới system combination;
- hiểu implementation để giao tiếp với programmer;
- ghi rõ hypothesis và validation plan;
- iterate từ vấn đề thực tế thay vì chỉ thêm feature.

### 11.3 Giá trị em muốn phát triển tại Falcon

Em muốn áp dụng nền tảng Systems/Technical Design vào quy trình có team, nơi level, difficulty, UX và metric được kiểm chứng thường xuyên. Em đặc biệt muốn học cách biến design hypothesis thành playtest/data evidence ở quy mô production.

## 12. Bài trả lời phỏng vấn 2–3 phút

> GameDemo là một farming/life-sim 2D nơi người chơi xây dựng routine trong một cộng đồng nhỏ. Người chơi cày đất, gieo hạt, tưới và thu hoạch; sau đó mang sản phẩm đi bán, mua resource, nhận quest và tương tác với NPC có lịch trình riêng. Mục tiêu của em không chỉ là tạo một chuỗi việc phải làm, mà là khiến mỗi ngày người chơi phải chọn điều gì quan trọng với mình.
>
> Core Gameplay Loop là: người chơi quan sát trạng thái ngày mới, lập kế hoạch, thực hiện farming hoặc hoạt động xã hội, quản lý Time và Energy, rồi ngủ để crop, quest và NPC chuyển sang state tiếp theo. Sang ngày mới, người chơi nhìn thấy kết quả và điều chỉnh strategy.
>
> Mechanic cốt lõi nhất là daily decision loop được tạo bởi Time/Energy kết hợp với NPC schedule và quest opportunity. Ví dụ người chơi có thể ở lại farm để bảo vệ crop, hoặc rời farm để gặp Marcus, nhận nhiệm vụ và tăng relationship. Nếu cố làm tất cả, người chơi có thể cạn Energy hoặc bỏ lỡ time window.
>
> Em cho rằng mechanic này tạo ra trải nghiệm em muốn vì nó hỗ trợ Autonomy, Competence và Relatedness. Người chơi có Autonomy khi tự chọn ưu tiên; có Competence khi hiểu system và tối ưu routine; có Relatedness khi NPC có cuộc sống không xoay hoàn toàn quanh người chơi. Phần em đã làm được là farming, Energy, Quest Board, dynamic delivery và Marcus schedule/route framework. Phần chưa hoàn thành là balancing bằng playtest, route regression, Dynamic Market và mystery arc. Vì vậy bước tiếp theo của em là validate một vertical slice end-to-end, không phải tiếp tục thêm nhiều system.

## 13. Câu hỏi em chuẩn bị cho interviewer

- Team đánh giá một design proposal bằng tiêu chí nào trước khi prototype?
- Designer tại Falcon phối hợp với Product, Developer, Artist và QA theo workflow nào?
- Với Intern, expectation giữa Level Design, Systems Design, UX và Data Analysis được phân bổ ra sao?
- Team quyết định difficulty bằng playtest nội bộ, remote test hay live data?
- Một iteration được coi là thành công dựa trên metric và qualitative feedback nào?

## 14. Portfolio Evidence cần hoàn tất trước khi gửi

- [ ] Link playable build vượt qua smoke test.
- [ ] Video 2–3 phút cho Core Loop.
- [ ] Video/screenshot Marcus qua một route xuyên map.
- [ ] Screenshot Quest Board và delivery completion.
- [ ] Annotated map thể hiện onboarding/player flow.
- [ ] Một bảng balancing `Initial → Problem → Revision → Result`.
- [ ] Một playtest note có sample size và observation.
- [ ] Link GDD đầy đủ: `GameDemo_GDD_Portfolio_VI_v2.md`.

## 15. Lời kết

GameDemo cho thấy em mạnh ở **Systems Design, Technical Design, NPC/world-state design và documentation có kiểm soát scope**. Project cũng cho thấy khoảng trống của em: chưa có đủ Level Design evidence, Game Balancing data và structured playtest.

Em không nghĩ những khoảng trống này là nội dung cần che giấu. Chúng xác định chính xác bước học tiếp theo: đưa một vertical slice tới trạng thái có thể chơi, đo được và iterate được trong môi trường team.

---

### Tài liệu tham chiếu nội bộ

- `design/gdd/GameDemo_GDD_Portfolio_VI_v2.md`
- `TODO.md`
- `project.godot`
- `scripts/autoload/energy_manager.gd`
- `scripts/autoload/quest_system.gd`
- `scripts/autoload/npc_manager.gd`
- `scripts/autoload/npc_route_manager.gd`
- `scripts/npc/neighbor.gd`
- `resources/localization/vi.json`
