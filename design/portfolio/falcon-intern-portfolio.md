# Game Design Portfolio — Farm Horror Demo

> **Mục đích:** Hồ sơ ứng tuyển Game Designer Intern  
> **Ứng viên:** Solo developer  
> **Dự án:** Farm Horror Demo  
> **Engine:** Godot 4.5 / GDScript  
> **Trạng thái:** Prototype foundation; tài liệu phân biệt rõ phần đã triển khai, framework và đề xuất thiết kế.

## 1. Tóm tắt một trang

**Farm Horror Demo** là game 2D top-down về một người sống trong ngôi làng nông nghiệp nơi việc làm ruộng, lịch NPC và các biến cố bất thường cùng tranh giành thời gian của người chơi. Trải nghiệm cốt lõi là chọn việc cần làm trong một ngày hữu hạn, đọc dấu hiệu của thế giới, rồi chấp nhận hậu quả xã hội của quyết định đó.

### Vai trò của tôi

Tôi tự thiết kế và triển khai prototype: core loop, game state, farming, inventory, quest, NPC schedule, risk calculation, event chain, family consequence, dialogue flow, UI khung và scene composition. Tôi cũng chịu trách nhiệm ghi chép design, debug và scope planning.

### Điều dự án chứng minh được

- Tôi có thể chuyển một fantasy thành state, rule, input/output và consequence cụ thể.
- Tôi hiểu cách design và implementation ràng buộc lẫn nhau trong một prototype nhỏ.
- Tôi biết một hệ thống chạy được chưa đồng nghĩa với một trải nghiệm đã được validate; vì vậy các giá trị chưa playtest được đánh dấu là **initial tuning**.
- Tôi đang phát triển thêm năng lực level design, balancing và playtest có cấu trúc; đây là những phần tôi muốn học sâu hơn trong môi trường studio.

### Artifact cần đính kèm trước khi gửi

- [ ] Link build hoặc video gameplay 60–120 giây.
- [ ] Một screenshot map có annotation route/objective.
- [ ] Một bảng tuning trước/sau có nguồn dữ liệu playtest.
- [ ] Link repository hoặc bản PDF portfolio đã render.

## 2. Project facts đã kiểm tra trong repository

| Hạng mục | Số liệu hiện tại | Cách hiểu đúng |
|---|---:|---|
| Script trong `scripts/` | 47 `.gd` | Bao gồm gameplay, UI, tool và autoload |
| Script `.gd` toàn project | 49 | Thêm 2 resource/database script |
| Scene | 20 `.tscn` | Bao gồm map, UI, NPC và world object |
| Autoload đăng ký | 20 | Không gọi tất cả là gameplay system |
| Item definitions | 22 `.tres` | Bao gồm tool, seed, harvest, consumable và lore |
| Dialogue JSON | 3 | Runtime dialogue data hiện có |
| Audio asset | 0 | AudioManager là framework, chưa phải audio-complete build |
| Trạng thái | Foundation/prototype | Có framework chưa hoàn thiện và known issues |

`TODO.md` hiện là snapshot production với nhiều việc chưa hoàn tất. Tôi không dùng “0/72 task” như thành tích; trong hồ sơ gửi ngoài, điều quan trọng là nói rõ demo nào đã chạy được và phần nào còn là kế hoạch.

## 3. Design problem

### Câu hỏi thiết kế

Làm thế nào để một ngày ở nông trại tạo ra lựa chọn có ý nghĩa mà không cần combat hoặc jumpscare liên tục?

### Design answer

Tôi ghép ba lớp:

1. **Budget:** thời gian, năng lượng và tiền giới hạn số việc có thể làm.
2. **Information:** thời tiết, lịch NPC và dialogue cho người chơi dấu hiệu nhưng không tiết lộ toàn bộ kết quả.
3. **Consequence:** event chain thay đổi quest, cửa hàng, gia đình và các ngày sau.

Công thức này là design hypothesis của prototype. Nó chỉ trở thành design đã được chứng minh sau khi có playtest và iteration có ghi nhận.

### Core loop

```text
Đọc tình trạng ngày mới
  -> chọn ưu tiên (farm / giao tiếp / điều tra / chuẩn bị)
  -> thực hiện hành động và tiêu tài nguyên
  -> nhận thêm thông tin hoặc kích hoạt biến cố
  -> quyết định can thiệp hay bỏ qua
  -> ngủ, để thế giới tiến triển
  -> quan sát hậu quả và cập nhật kế hoạch
```

## 4. Case study: Voss Mountain Trip

Đây là case study chính vì nó nối được time budget, NPC schedule, risk, quest và consequence trong một tình huống có thể trình diễn.

### 4.1 Design intent

Old Voss có lịch đi núi vào thứ Bảy. Người chơi có thể biết trước lịch, chuẩn bị vật phẩm hoặc nhận quest hộ tống. Khi event được resolve, Voss có thể an toàn, về muộn, bị thương hoặc chết; hậu quả ảnh hưởng cửa hàng và người kế nhiệm.

### 4.2 Hai lớp xác suất khác nhau

Đây là điểm cần nói chính xác trong interview:

- `RiskCalculator` tính một **risk score 0–1** từ hoạt động, thời tiết, thời gian, personality, escort và mùa.
- `EventChainEngine` resolve `shopkeeper_mountain` bằng **base outcome weights** 70/10/15/5 rồi áp dụng branch modifier của chain.
- Hai hệ thống hiện có liên kết qua world simulation và context, nhưng không phải một công thức duy nhất biến risk score thành đúng các weight 70/10/15/5.

Tôi coi đây là một giới hạn prototype cần làm rõ hoặc hợp nhất trong iteration tiếp theo, thay vì trình bày như một hệ thống đã được validate hoàn chỉnh.

### 4.3 Quyết định của người chơi

| Người chơi biết | Người chơi chưa biết |
|---|---|
| Ngày/giờ Voss rời đi; thời tiết hiện tại; NPC có personality; escort làm giảm risk score | Outcome cuối cùng; hậu quả xã hội; thời điểm chính xác của các thay đổi sau event |

Các lựa chọn được thiết kế:

- Tiếp tục chăm ruộng để giữ tiến độ crop.
- Mua/chuẩn bị vật phẩm trước khi Voss rời đi.
- Đi cùng Voss, đổi energy và thời gian lấy một modifier có lợi.
- Bỏ qua và chấp nhận thế giới tự tiến triển.

Trong build hiện tại, **escort là agency trực tiếp được triển khai rõ nhất**. “Chờ bão qua” và “điều tra để mở thông tin mới” vẫn là hướng vertical slice, chưa nên ghi là feature đã hoàn thiện.

### 4.4 Outcome và hậu quả

| Outcome cơ sở | Hậu quả thiết kế |
|---|---|
| Safe | Chuỗi tiếp tục, không có hậu quả lớn |
| Delayed | Cửa hàng mở muộn |
| Injured | Cửa hàng đóng vài ngày; dialogue/quest có thể phản ứng |
| Dead | Cửa hàng đóng, tang lễ được lên lịch, Young Voss có thể kế nhiệm |

Mục tiêu không phải làm người chơi thua bởi một cú roll vô nghĩa. Vì vậy vertical slice cần bổ sung feedback về risk, cơ hội chuẩn bị và cách giải thích hậu quả. Nếu người chơi đã can thiệp đúng nhưng vẫn thất bại, game phải cho thấy đó là lựa chọn rủi ro có chủ đích, không phải lỗi hệ thống.

## 5. Case study: Farm map như một level nhỏ

Farm map hiện là không gian chơi thật trong scene, nhưng chưa phải level puzzle hoàn chỉnh. Tôi trình bày nó như một **level pass đang thiết kế**, không giả vờ rằng mọi beat đã được playtest.

### Objective

Trong ngày đầu, người chơi học cách chuẩn bị một ô đất, gieo seed, tưới cây và tìm đường tới nhà/cửa hàng trước khi năng lượng hoặc thời gian trở thành rào cản.

### Teaching sequence

| Beat | Player action | Design purpose |
|---|---|---|
| 1. Spawn tại farm | Di chuyển, nhận diện nhà và ruộng | Cho người chơi đọc không gian trước khi chịu áp lực |
| 2. Ô đất gần lối đi | Dùng hoe | Giới thiệu tương tác theo ô và feedback trạng thái |
| 3. Seed + water | Chuyển hotbar, gieo, tưới | Giới thiệu chuỗi hành động nhiều bước |
| 4. Nhà/bed | Đi vào nhà và ngủ | Cho thấy ngày là một budget có điểm kết thúc |
| 5. Cửa hàng | Đổi scene, xem item và giá | Nối farming với chuẩn bị cho ngày sau |

### Constraint và failure cases

- Energy giới hạn số hoạt động; sprint đổi energy lấy thời gian di chuyển.
- Crop có thể héo nếu thiếu nước qua ngày.
- Tương tác cần đúng khoảng cách/hướng nhìn; feedback phải cho biết vì sao hành động thất bại.
- Player có thể bỏ qua farming để khám phá; trade-off này cần được thể hiện bằng mục tiêu hoặc opportunity cost, không chỉ bằng text.

### Difficulty/pacing pass đề xuất

Đây là kế hoạch kiểm chứng, chưa phải kết quả playtest:

1. Ngày 1: không có biến cố nguy hiểm; dạy farm, shop và sleep.
2. Ngày 2: thêm một quest có deadline mềm; kiểm tra người chơi có nhìn thấy lịch NPC không.
3. Ngày 3: thêm weather/risk signal; kiểm tra người chơi có chuẩn bị hay chỉ chạy theo mục tiêu gần nhất.
4. Sau đó mới mở Voss chain; consequence phải xuất hiện trong cùng phiên chơi hoặc ngay ngày kế tiếp.

## 6. Balancing và validation plan

Tôi không đưa các con số hiện tại ra như “đã cân bằng”. Chúng là initial tuning được lấy từ code để prototype có thể chạy.

| Variable | Initial value | Hypothesis cần kiểm tra | Metric/feedback |
|---|---:|---|---|
| Day speed | 1 giờ game ≈ 10 giây thực | Một ngày đủ ngắn để tạo ưu tiên nhưng đủ dài cho một routine farm và một interaction | Thời gian hoàn thành routine; số lần bỏ dở vì hết giờ |
| Energy | 100 | Người chơi phải chọn giữa sprint/farm/khám phá, không bị khóa quá sớm | Energy còn lại khi ngủ; số lần cạn energy ngoài ý muốn |
| Sprint speed | 250 | Di chuyển nhanh hơn đáng kể nhưng không xóa opportunity cost | Tỉ lệ dùng sprint; thời gian route farm → shop |
| Escort modifier | -0.20 risk score | Escort có giá trị nhưng không biến thành đáp án luôn đúng | Tỉ lệ chọn escort; lý do người chơi nêu sau khi chơi |
| Mountain base weights | 70/10/15/5 | Outcome hiếm vẫn đáng nhớ, không phá run quá thường xuyên | Phân bố outcome trong simulation; cảm nhận công bằng |

### Test protocol tối thiểu trước khi gửi portfolio

- 3–5 người chơi chưa đọc design doc.
- Mỗi người chơi 15–20 phút, ghi màn hình nếu được phép.
- Hỏi sau phiên: “Bạn nghĩ việc gì là ưu tiên?”, “Bạn hiểu vì sao outcome xảy ra không?”, “Bạn có thấy escort đáng giá không?”.
- Ghi funnel đơn giản: spawn → farm action → shop → sleep → quest/event.
- Chỉ gọi một thay đổi là iteration khi có **giá trị trước, vấn đề quan sát, thay đổi và lý do**.

Hiện repository chưa chứa dataset playtest hoặc test report. Vì vậy portfolio này không tuyên bố đã có validation mà chưa có bằng chứng.

## 7. Những gì đã triển khai và những gì còn là framework

| Hạng mục | Trạng thái | Bằng chứng |
|---|---|---|
| Player movement/interact | Prototype implemented | `scripts/player/player.gd` |
| Day/night và state | Framework implemented; cần kiểm tra edge case chuyển ngày | `scripts/autoload/time_manager.gd`, `game_state.gd` |
| Farm plot state | Prototype implemented | `scripts/world/farm/farm_manager.gd`, `farm_plot.gd` |
| Inventory/shop/dialogue UI | Prototype implemented | `scripts/ui/*.gd`, scene UI |
| Quest definitions | Framework + lifecycle cơ bản | `scripts/autoload/quest_system.gd` |
| Risk calculation | Implemented utility | `scripts/autoload/risk_calculator.gd` |
| Event chain outcomes | Implemented framework | `scripts/autoload/event_chain_engine.gd` |
| NPC schedule | Data/simulation framework | `scripts/autoload/npc_schedules.gd` |
| Family succession | State framework; scene/content còn thiếu | `scripts/autoload/family_registry.gd` |
| Audio/horror presentation | Framework/placeholder direction | `scripts/autoload/audio_manager.gd`, TODO |
| Automated tests/playtest report | Chưa có | TODO |

## 8. Liên hệ với vị trí Puzzle/Level Design

Tôi không cho rằng risk formula tự động tương đương puzzle design. Một hệ thống chỉ trở thành puzzle khi người chơi có thông tin đủ để suy luận, lựa chọn có không gian giải, feedback rõ và failure có thể học được.

Điểm tôi có thể mang sang một team puzzle:

- **Decomposition:** tách objective, constraint, input, output và failure state.
- **Tuning mindset:** coi số liệu là hypothesis, không phải chân lý; thay đổi phải gắn với metric.
- **Pacing:** giới thiệu một biến mới, cho người chơi một beat luyện tập, rồi mới kết hợp biến.
- **Code literacy:** đọc được data flow và trao đổi cụ thể với programmer.
- **Documentation:** viết rule và edge case đủ rõ để người khác implement.

### Bài tập puzzle minh họa do tôi đề xuất

Đây là exercise cá nhân, **không phải dữ liệu nội bộ của Falcon**:

| Level | Mục tiêu học | Constraint mới | Tiêu chí pass |
|---|---|---|---|
| 1 | Nhận diện và ghép một loại vật phẩm | Không có timer | Hoàn thành không cần text dài |
| 2 | Ghép hai loại vật phẩm | Giới hạn lượt nhẹ | Hiểu vì sao nước đi sai |
| 3 | Đặt thứ tự hành động | Thêm blocker | Có ít nhất hai solution hợp lệ |
| 4 | Tối ưu route | Timer hoặc move budget rõ ràng | Người chơi retry và cải thiện |
| 5 | Kết hợp mechanic | Một blocker động | Difficulty tăng từ một biến, không tăng mọi biến cùng lúc |

Mục đích của bảng là cho thấy cách tôi tiếp cận onboarding và difficulty; tôi không dùng nó để nhận công đã thiết kế level cho sản phẩm của Falcon.

## 9. Những bài học chính

1. **Một architecture tốt chưa chứng minh gameplay tốt.** Cần đưa người chơi vào vòng lặp càng sớm càng tốt.
2. **Outcome ngẫu nhiên cần được đặt trong information design.** Nếu player không thể hiểu hoặc học từ failure, RNG trở thành noise.
3. **NPC schedule chỉ có giá trị khi tạo quyết định.** Simulation phải chuyển thành quan sát, lựa chọn và consequence.
4. **Số liệu cần rationale và validation status.** Initial tuning, simulated result và playtest result phải được ghi tách biệt.
5. **Scope là một design tool.** Một chain hoàn chỉnh có giá trị hơn nhiều chain chỉ có definition.

## 10. Kế hoạch hoàn thiện portfolio

Trước khi gửi, tôi sẽ hoàn thành theo thứ tự:

1. Chốt một vertical slice có thể chơi từ farm → interaction → sleep → consequence.
2. Quay video và chụp screenshot có annotation.
3. Chạy playtest nhỏ, lưu raw notes và bảng tuning trước/sau.
4. Cập nhật các claim trong portfolio chỉ bằng kết quả có thể kiểm chứng.
5. Render PDF 5–7 trang chính; để phụ lục code/GDD ở cuối hoặc link riêng.

## 11. Câu hỏi dành cho interviewer

- Team định nghĩa một level “đạt” bằng completion rate, retry behavior, time-to-solve hay metric nào khác?
- Intern thường sở hữu một feature nhỏ end-to-end đến mức nào: spec, implementation handoff, tuning và post-launch review?
- Team dùng playtest nội bộ, remote test hay live data để quyết định difficulty?
- Designer làm việc với programmer và artist qua template hoặc workflow nào?

## 12. Tài liệu tham chiếu

- Master GDD: `design/gdd/farm-horror-gdd.md`.
- Project overview: `README.md`.
- Production snapshot: `TODO.md`.
- Risk: `scripts/autoload/risk_calculator.gd`.
- Event chain: `scripts/autoload/event_chain_engine.gd`.
- Quest: `scripts/autoload/quest_system.gd`.
- NPC schedule: `scripts/autoload/npc_schedules.gd`.
- Family state: `scripts/autoload/family_registry.gd`.

---

**Lời kết:** Tôi gửi dự án này như bằng chứng về cách tôi suy nghĩ, xây prototype và tự nhận diện khoảng trống cần cải thiện. Tôi không trình bày một prototype foundation như sản phẩm đã hoàn thiện; mục tiêu của tôi là dùng nền tảng system thinking này để học nhanh hơn về level design, balancing, UX và quy trình làm game theo dữ liệu trong môi trường studio.
