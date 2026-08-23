# GAME DEMO — PORTFOLIO DRAFT (Falcon Game Studio — Game Designer Intern, Puzzle)

> **Ngày:** 2026-08-23
> **Vị trí ứng tuyển:** Game Designer Intern — dòng Puzzle
> **Project showcase:** Game Demo (2D farming/life simulation prototype, Godot 4.5 + GDScript)
> **Tài liệu này:** portfolio gửi kèm interview, không phải GDD đầy đủ (xem `design/gdd/game-demo-gdd-v2.md` cho bản master).

Lưu ý dành cho reviewer: bản portfolio này **trình bày quyết định thiết kế**, không trình bày toàn bộ hệ thống. Tôi tách rõ những gì đã implement khỏi những gì đang là design direction. Nếu cần chi tiết kỹ thuật, mời xem GDD master.

---

## 1. Bìa & 3 highlight

**Một câu về sản phẩm:**
Game Demo là một prototype farming/life simulation 2D, nơi người chơi xây dựng cuộc sống và quan hệ trong một cộng đồng nhỏ thông qua sản xuất, giao thương và những quyết định hàng ngày. Bên dưới cuộc sống bình thường có một lớp anomaly tùy chọn, không bắt buộc.

**Ba hệ thống tôi muốn showcase trong vòng phỏng vấn:**

1. **Risk Calculator** — hệ thống tính xác suất rủi ro của NPC, dùng dữ liệu thật từ 6 nguồn modifier để tạo ra choice without obvious right answer.
2. **Event Chain Engine** — DSL nhỏ cho phép khai báo chuỗi outcome có branch, trigger, consequence — pattern phù hợp để áp dụng cho level pacing của puzzle game.
3. **NPC + Family + Schedule** — hệ thống tạo câu chuyệu emergent từ 5 NPC với lịch trình theo ngày trong tuần, không cần hard-code từng kịch bản.

---

## 2. Tổ quan dự án — thành thật

**Thông tin nhanh:**

| Mục | Giá trị |
|---|---|
| Engine | Godot 4.5 |
| Ngôn ngữ | GDScript |
| Type | Farming/life simulation 2D, có lớp narrative tùy chọn |
| Quy mô | 57 scripts, 21 scene, 22 item resource, 24 autoload |
| Thể loại chính | Farming / life simulation |
| Scope hiện tại | Foundation / prototype (Phase 1) |
| Phase | Đang trong Phase 1 — Foundation |

**Trạng thái Phase 1:**

- **Có**: farming loop end-to-end, time/energy, day/night, NPC dialogue cơ bản, shop buy/sell, save/load architecture, 4 quest, 3 event chain, risk calculator, weather system.
- **Đang làm**: 5 NPC scene (hiện mới có 1), polish UI, fix invalid UID, audio asset.
- **Chưa có**: scene Mountain/Forest/River cross, branch dialogue, full dynamic market, negotiation system, fish/cooking.

**Ghi chú trung thực:**
Tôi không đứng đây nói "đây là game hoàn chỉnh 100%". Đây là prototype Phase 1. Một số hệ thống trong file đề cập là **design direction**, không phải feature đã build. Nếu reviewer muốn tôi chỉ ra đường ranh giới giữa "đã làm" và "đang định thiết kế", tôi có thể làm ngay.

---

## 3. Design Philosophy

### Sáu design pillar (và anti-pillar tương ứng)

1. **Life comes first** — farming và mua bán là gameplay chính. Anti-pillar: không có quest nào bắt buộc đào sâu mystery.
2. **Limited resources create choice** — thời gian, năng lượng, vàng đều hữu hạn. Anti-pillar: không có "vô hạn stamina" sau upgrade.
3. **Systems create observable consequences** — mọi action có impact lên state. Anti-pillar: không có quest "vô hình".
4. **The community feels alive** — NPC có schedule, family, personality. Anti-pillar: không có NPC "đứng chờ".
5. **Information supports decisions** — không hiển thị con số risk, chỉ hiển thị ngữ cảnh. Anti-pillar: không bao giờ hiện "Risk = 47%" trên UI.
6. **Mystery is optional depth** — layer có thật nhưng tách rời core loop. Anti-pillar: không có flag nào của mystery lock progression chính.

### Mini case study: Tại sao mystery không phải core loop?

Trong GDD cũ, mystery được đặt vào design pillar số 1. Tôi đã đính chính lại. Lý do:

- Code và scene đã build cho thấy core loop là **farming + mua bán + quan hệ NPC**. Tất cả autoload đều point về đó.
- Mystery chỉ xuất hiện trong 3 vị trí cục bộ: signal `anomaly_weather_triggered`, flag `strange_events_active`, và một NPC `cancelled_mysterious` outcome weight 0.15 trong festival chain.
- Nếu mystery là core, gameplay sẽ không survive khi người chơi bỏ qua nó. Tôi muốn core bền — ai chỉ chơi farming cũng vui.

**Bài học cho portfolio:** đừng gán "core pillar" cho thứ mà bạn không commit đủ resource để support.

---

## 4. System Showcase #1: Risk Calculator

Hệ thống tính rủi ro của NPC khi thực hiện hoạt động nguy hiểm.

### Công thức (tóm tắt bằng lời)

Một NPC thực hiện activity → risk tổng = **base + weather + time + personality + escort + season**, clamp trong [0, 1]. Sau đó game roll 1 số ngẫu nhiên trong [0, 1] và map vào 4 outcome: safe (roll > risk), delayed, injured, dead (roll < risk * 0.4).

### Bảng base risk cho 5 activity

| Activity | Base Risk |
|---|---|
| `mountain_trip` | 0.20 |
| `forest_walk` | 0.10 |
| `river_crossing` | 0.15 |
| `night_walk` | 0.25 |
| `work_field` | 0.05 |

### Ví dụ dồn modifier

Old Voss leo núi vào một ngày Saturday **mưa bão + mùa đông + 7 giờ tối + personality cautious + không có escort**:

- Base: 0.20
- Weather storm: +0.35
- Winter: +0.15
- Evening (18-22h): +0.10
- Cautious personality: -0.10
- **Tổng = 0.70**

=> Roll nhỏ hơn 0.28 → Voss **chết**. Nếu player escort (-0.20) → tổng giảm còn 0.50 → cơ hội chết giảm từ 28% xuống 20%.

### Phân tích thiết kế

Tại sao cộng dồn, không nhân?

- Cộng dồn tạo ra **không có safe choice tuyệt đối**. Luôn có xác suất thất bại.
- Ngược lại, cộng dồn cũng tạo ra **không có unsafe choice tuyệt đối**. NPC cautious vẫn có 1% chết nếu mọi thứ xấu cùng lúc.
- Quyết định của player trở thành: **"bạn chấp nhận bao nhiêu phần trăm?"**, thay vì "bạn biết hay không biết kết quả".
- Đó là kiểu uncertainty tôi muốn: có nguyên nhân, có thể suy luận, không thể chắc chắn.

### Puzzle angle

Pattern này cũng áp dụng được cho puzzle game dạng level design:

- Mỗi level = 1 stack các modifier (player skill, tool, difficulty, time, hint).
- Outcome buckets (clear / 3-star / 2-star / fail) tương tự (safe / delayed / injured / dead).
- Player đọc **context** của level (modifier) thay vì thấy % rõ ràng.

### Mini case study: quyết định của player

Hình dung 1 buổi sáng thứ 7:

- Player dậy, energy 20/20, gold 350.
- Mở weather forecast → ngày mai (chủ nhật) là mưa bão. Hôm nay (thứ 7) heavy_rain.
- Thấy prompt "Old Voss sắp đi leo núi lúc 07:00".
- Quest đang active: `escort_voss_mountain`. Reward: `old_key` × 1.

Câu hỏi thiết kế quan trọng: **player có nên escort Voss không?**

Thông tin player có:

- Old Voss personality = cautious (-0.10).
- escort = player giảm -0.20.
- weather heavy_rain = +0.45.
- winter = +0.15.
- base = 0.20.

Nếu escort: total = 0.20 + 0.45 + 0.15 + 0.10 (evening) - 0.10 - 0.20 = **0.60**.

- Roll < 0.24: dead (24%).
- Roll < 0.48: injured (24%).
- Roll < 0.60: delayed (12%).
- Roll > 0.60: safe (40%).

Nếu không escort: total = 0.80 → cơ hội chết = 32%.

**Trade-off thật sự:**

- Escort Voss → tiêu 5-10 energy, giảm cơ hội Voss chết ~8%, không làm việc nhà khác.
- Không escort → tiết kiệm energy, làm việc khác được, chấp nhận Voss có khả năng chết 32%.

**Kết quả thiết kế:** player **cảm thấy như họ phải đưa ra quyết định quan trọng**, mặc dù không có số nào hiện trên UI. Họ chỉ thấy "mưa to", "ông Voss già", "leo núi lúc tối". Não họ tự tính (sai, nhưng vẫn có cảm giác cần đưa ra lựa chọn).

Đó là runtime psychological model mà tôi muốn player tự xây — game không cần hiển thị nó.

---

## 5. System Showcase #2: Event Chain Engine

DSL nhỏ để khai báo chuỗi sự kiện có outcome branch.

### Cấu trúc (diễn giải bằng lời)

Một chain gồm:

- **Outcomes** = dictionary kết quả, mỗi outcome có `weight` (xác suất) và `consequences` (hệ quả đi kèm).
- **Branches** = dictionary điều kiện, mỗi branch có `condition` (player_escorted / weather_storm / ...) và `modifiers` (đẩy trọng số outcome lên/xuống).
- **Steps** = timeline (delay 0, 2, 5, 10 in-game day) — mỗi step trigger một action.

### Ví dụ: chain `shopkeeper_mountain`

Outcomes:

| Outcome | Weight | Hệ quả |
|---|---|---|
| safe | 0.70 | — |
| delayed | 0.10 | shop mở muộn |
| injured | 0.15 | shop đóng vài ngày, Voss bị thương |
| dead | 0.05 | Voss chết, shop đóng vĩnh viễn, con trai thay, lễ tang lập lịch |

Branches:

- Player escort → injured_weight giảm 0.08, dead_weight giảm 0.03, safe_weight tăng 0.11.
- Trời storm → injured tăng 0.15, dead tăng 0.10.
- Trời heavy_rain → injured tăng 0.20, dead tăng 0.20.

Timeline (in-game day): NPC rời nhà (d=0) → NPC leo núi (d=2) → outcome_resolved (d=5) → NPC về hoặc không (d=10).

### Phân tích thiết kế

Tại sao tách riêng Event Chain Engine khỏi Risk Calculator?

- **Risk Calculator** trả lời câu hỏi "chuyện này nguy hiểm bao nhiêu?" — dạng scalar đơn.
- **Event Chain** trả lời câu hỏi "có chuyện gì xảy ra, theo trình tự nào?" — dạng narrative grammar.
- Tách riêng = dễ tái sử dụng. Risk dùng cho NPC schedule; Event Chain dùng cho quest, festival, blight.
- Chain có thể chain (chain trong chain) nếu cần, không phải sửa engine.

### Puzzle angle

Pattern phù hợp cho puzzle level editor:

- Một level = 1 chain có nhiều outcome (clear / 2-star / 1-star / fail).
- Branch modifiers = player choices trước level (bring item? skip tutorial?).
- Steps = animation checkpoints hoặc hint reveal.
- Khi player edit level, họ chỉ chỉnh `weight` và `condition`, không phải động vào logic.

### Mini case study: chuỗi consequence khi Voss chết

Roll ra 0.02 (nhỏ hơn 0.28 * 5% raw weight). Outcome = **dead**.

Apply 4 consequence:

1. `shopkeeper_dead` → set flag.
2. `shop_closes` → `GameState.set_flag("shop_open", false)` + `ConsequenceResolver.apply_scene_change("shop.tscn", "set_shop_state", "closed")`.
3. `funeral_scheduled` → `ConsequenceResolver.schedule_event("funeral", 3)` (3 ngày sau).
4. `son_takes_over` → `ConsequenceResolver.schedule_family_succession("shopkeeper_family", "shopkeeper_son", +3)`. Family head đổi từ `shopkeeper_father` sang `shopkeeper_son`.

Ngày +3:

- Family head = Young Voss.
- dialogue của shop chuyển từ `shopkeeper_father_normal` sang `shopkeeper_son_normal`.
- Voss con giờ có lịch leo núi (vì nó là family head?) — chưa, lịch cũ vẫn lưu, không auto-clone.
- `family_shopkeeper_status` = INTACT → REDUCED (1 người còn) hoặc SCATTERED (2 người).

**Player thấy gì?**

- Sáng ngày +3, vào shop → không ai đứng sau quầy.
- Nói chuyện với Young Voss → dialogue khác, giọng khác.
- Ngôi làng có funeral scheduled.

Đây là emergent consequence. Designer không viết script "if Voss dies then player sees X". Designer chỉ setup system (chain + consequence), còn lại là universe tự sản sinh.

---

## 6. System Showcase #3: NPC + Family + Schedule

Hệ thống NPC với family state, lịch trình theo tuần, và dialogue biến đổi theo state.

### 5 NPC qua 3 family

| Thành viên | Family | Personality | Successor | Lịch trình |
|---|---|---|---|---|
| Old Voss | Voss | cautious | Young Voss | mountain_trip thứ 7 |
| Young Voss | Voss | reckless | — | night_walk thứ 5 |
| Martha Miller | Miller | cautious | — | market_day thứ 3 |
| Eliza Miller | Miller | normal | — | — |
| Old Hanz | Hermit | old | — | forest_walk thứ 4 |

### Family status & succession

Family có 4 trạng thái: INTACT → REDUCED → SCATTERED → EXTINCT. Nếu family head chết:

1. Tìm successor (chỉ Old Voss có — khai báo sẵn = Young Voss).
2. Nếu không có successor, promote thành viên còn sống đầu tiên.
3. Status tự động cập nhật theo alive_count.

### Dialogue biến đổi theo status

`get_dialogue_for_current_head` — nếu family REDUCED → append `_grief` suffix. Ví dụ: dialogue của Old Voss khi bình thường = `shopkeeper_father_normal`. Sau khi Voss chết và Young Voss lên thay = `shopkeeper_son_normal`.

### Phân tích thiết kế

Tại sao làm 3 layer (NPC + Family + Schedule) thay vì chỉ 1?

- **NPC layer** cho biết "ai đó có thể tương tác".
- **Family layer** cho biết "NPC có quan hệ, có thể bị ảnh hưởng gián tiếp".
- **Schedule layer** cho biết "NPC có hành vi theo thời gian, không chờ player".

Kết quả: NPC có thể tự tạo situation (vợ chồng, con cái, mất mát, kế thừa) mà **không cần scriptwriter viết từng kịch bản**. Tôi gọi đây là emergent narrative — Dwarf-Fortress-style.

### Puzzle angle

Pattern này có thể dùng cho puzzle game có companion system:

- Companion có personality + state + relationship.
- Player tương tác → state đổi → hint/puzzle gợi ý khác đi.
- Không phải chỉnh story, chỉ chỉnh state.

### Mini case study: một tuần "bình thường"

Thứ 2: Player gặp Old Voss ở shop. dialogue = `shopkeeper_father_normal` (Voss ở nhà vì chỉ leo núi thứ 7).

Thứ 3: Martha đi chợ 8:00-15:00. Schedule `market_day` trigger. Risk chain `river_crossing` không define nên không có event chain — Martha chỉ đi về. Player có thể không thấy Martha.

Thứ 4: Old Hanz đi rừng 6:00-17:00. Không có chain. Old Hanz mất tích khỏi map từ 6h sáng.

Thứ 5: Young Voss đi dạo đêm 21:00-23:00. Không có chain. Nhân vật này player không gặp buổi tối.

Thứ 6: không có schedule nào.

Thứ 7: Old Voss leo núi 7:00-18:00. Chain `shopkeeper_mountain` trigger. Nếu weather không tốt, chain roll và có thể outcome `dead`. Nếu outcome `dead` thì consequences nổ tích tắc theo schedule.

**Quan sát thiết kế:** player trải qua một tuần "bình thường" không có sự kiện gì khác thường. Họ thấy:

- Voss làm việc bình thường (visible).
- Martha biến mất 1 ngày.
- Old Hanz biến mất nửa ngày.
- Young Voss không thấy buổi tối.

Sau 3-4 tuần, player bắt đầu hiểu lịch → dần hiểu community → bắt đầu predict ai có thể ở đâu hôm nay.

Đây là cảm giác "thế giới sống mà không cần tôi". Khi NPC chết (Old Voss dead), player **so sánh** với tuần trước → nhận ra something đã đổi → mới bắt đầu công cuộc điều tra.

Đây là lý do tôi không thêm tutorial "đây là lịch của NPC". Player tự khám phá.

---

## 7. Design Process

### Vòng lặp của tôi

```
Concept
  ↓ (đọc reference, brainstorm)
System spec
  ↓ (viết pseudo-trước, sau đó viết code)
Implementation refactor
  ↓ (build → playtest → chỉnh)
Validation
  ↓ (verify trải nghiệm, edge case)
Iterate
```

### Ba quyết định cụ thể

**1. Risk Calculator — đi từ multiply sang add & clamp.**

Lần đầu tôi viết risk = `base * (1 + weather + time + personality + ...)`. Khi playtest thử, infinite loop với weather "storm" vì modifier stack có thể vượt rất cao. Refactor sang cộng dồn + clamp `[0, 1]`. Trade-off: mất tính "scaling", nhưng có được bounded risk — cleaner cho downstream.

**2. Dialogue by status — dùng string suffix, không phải enum switch.**

Có 2 cách:

- A: `enum DialogueKey { ... }` với switch case.
- B: `dialogue_id + "_grief"` với string concat.

Tôi chọn B vì khi thêm state mới (REDUCED → GRIEVING → SOMETHING_ELSE) chỉ cần đổi logic append suffix, không phải thêm enum value và rewire.

**3. Schedule lookup — `day_of_week == (current_day - 1) % 7`, không phải day-of-year.**

Đầu tiên tôi định làm schedule theo day-of-year (1 = ngày 1, 8 = ngày 8, ...). Nhưng NPC trong làng nông thôn sống theo tuần (đi chợ thứ 3, leo núi thứ 7). Refactor sang modulo 7. Trade-off: không thể có lịch "1 lần mỗi 14 ngày" dễ dàng, nhưng đúng pattern đời thực hơn.

### Công cụ tôi dùng

- **GDScript** — đủ nhanh cho prototype.
- **Autoload pattern** — global state chia theo concern (Time / Energy / Risk / ...).
- **Signal-driven** — không polling, không gọi loop qua 24 script.
- **Data-driven chain** — outcome + weight + condition lưu trong Dictionary, không hard-code.

---

## 7.1. Nguyên tắc GDD tôi dùng (có thể áp dụng cho bất kỳ dòng game nào)

Trong quá trình viết GDD cho Game Demo, tôi đã hình thành 6 nguyên tắc giúp tài liệu trở nên **thực sự** dùng được:

### Nguyên tắc 1 — Tách Implementation khỏi Design Direction rõ ràng

Trong GDD có 4 ô:

- **Implemented** (đã chạy được trong build).
- **In Progress** (đang code, một nửa).
- **Designed / Future** (chỉ trong tài liệu, chưa code).
- **Won't-have** (chủ động loại khỏi MVP).

Mỗi feature khi viết phải thuộc 1 trong 4 ô. Không có "vùng xám". Lý do: nếu không phân loại, GDD sẽ bị "design by wishful thinking" — design nhiều feature hay, nhưng không có kế hoạch rõ ràng để build.

**Áp dụng vào Falcon:** intern viết level spec cũng nên rõ ràng: level này đã qua playtest chưa? đã có 4 design variant chưa? đã reserve 1 slot cho A/B test chưa?

### Nguyên tắc 2 — Quote code, đừng paraphrase

Khi GDD nói "player có thể mua hạt giống", đính kèm đường dẫn file `.tres` cụ thể. Khi nói "NPC cautious", quote Enum hoặc string từ code. Đường dẫn và enum name giúp designer + dev + tester có ngôn ngữ chung.

**Áp dụng vào Falcon:** spec level nên quote state machine, quote trigger condition, không chỉ mô tả chung chung.

### Nguyên tắc 3 — Open Questions là tính năng, không phải lỗ hổng

Mỗi câu hỏi chưa khóa (ví dụ "Hint reveal pacing?") là một cơ hội để cả team biết đang chờ quyết định. Có 11 câu open questions trong GDD v2 của tôi. Mỗi tuần tôi review để xem câu nào đã có câu trả lời.

**Áp dụng vào Falcon:** nếu intern tạo được 1 list open questions cho 1 dòng puzzle level thì dev lead sẽ rất thích — nó cho thấy intern hiểu trade-off.

### Nguyên tắc 4 — Phụ lục quan trọng hơn narrative

Một số designer viết GDD như luận văn: dài, đẹp, narrative. Nhưng khi dev implement, họ cần **tra cứu nhanh**. Phụ lục (A-F trong GDD của tôi) chứa bảng 22 item, bảng 5 NPC, công thức risk. Đây là phần dev dùng nhiều nhất.

**Áp dụng vào Falcon:** khi viết level spec, có 1 cheat sheet (số move, hint count, target audience) ở phụ lục — designer khác và QA sẽ ưu tiên cheat sheet hơn narrative dài.

### Nguyên tắc 5 — Show cost, not just benefit

Mỗi feature trong GDD nên đi kèm **cost**: mất bao nhiêu dev-week, cần bao nhiêu asset, scope mở rộng ở đâu. Ví dụ: "thêm strange_fruit crop" không chỉ là "thêm 1 item" — mà cần: thêm seed file, thêm plant logic, thêm mystery trigger, thêm dialogue reference. Tổng: 3-5 ngày dev + polish.

**Áp dụng vào Falcon:** intern propose feature nên kèm effort estimate. Điều này giúp team đánh giá trade-off giữa nhiều initiative.

### Nguyên tắc 6 — Test bằng cách dạy

Tôi tự test GDD bằng cách đưa cho 1 người không biết project đọc trong 15 phút, hỏi "sản phẩm này là gì, player làm gì, mechanic cốt lõi là gì". Nếu họ trả lời đúng, GDD đủ rõ. Nếu không, tôi sửa.

**Áp dụng vào Falcon:** mỗi level spec nên có 1 đoạn "2-sentence summary" trên đầu. Nếu không thể tóm tắt 2 câu, level spec chưa rõ.

---

## 7.2. Những câu hỏi về puzzle dòng Puzzle của Falcon

Dựa trên những game đã biết của Falcon, tôi đoán một vài câu hỏi mà intern GDD có thể gặp:

1. **Difficulty curve:** Level 1-10 dễ để onboard, 10-50 là core, 50+ thử thách. Cái khó là "làm sao 10-50 không lặp lại cảm giác 50+". Làm thế nào?
2. **Hint gating:** Hint miễn phí hay pay? Daily limit? Khi nào player cần hint? Đây là cả live ops decision lẫn design decision.
3. **Stuck recovery:** Player stuck 5 phút thì game phản ứng gì? Auto-skip level? Show tutorial? Spawn power-up? Cách nào trade-off với "feel of mastery"?
4. **Star distribution:** 3-star / 2-star / 1-star ratio mục tiêu bao nhiêu? Too generous = player không cố. Too harsh = player quit.
5. **A/B test variable:** Mỗi tuần có thể thử 1 biến (hình ảnh, hint delay, level ordering) — intern giúp phân tích metric.

Tôi chưa có câu trả lời chính xác cho 5 câu này. Đó là kiểu design challenge tôi rất muốn học khi vào Falcon.

### Một vài suy nghĩ về puzzle level editor

Nếu Falcon có một puzzle game có 1000+ level, intern GDD có thể đóng góp vào:

1. **Level editor data schema.** Format JSON hoặc tương đương: `level_id, board_size, blocks, win_condition, max_moves, hint, star_thresholds`. Đây là phần "data-driven" giống EventChain mà tôi đã build.
2. **Difficulty auto-balancer.** Cho 1 level, chạy 100 simulation, đếm median solve moves. Nếu median < target → tăng block. Nếu median > target → giảm block.
3. **Failing test player.** Một agent chơi 1000 lần để check level có thể qua. Nếu không → report failure.
4. **Variant generator.** Từ level A → generate A.snow / A.desert / A.reverse. Vẫn giữ mechanic, chỉ thay đổi context.
5. **Hint asset library.** Tag hint theo category (color, pattern, spatial, sequence) để puzzle designer browse.

Tôi biết 5 ý trên nghe grand, nhưng mỗi cái cũng đủ scope 1 sprint cho intern với mentor.

---

## 8. Bài học & tham vọng

### 5 điều đã học

1. **Split system vs data.** Risk calculator tách khỏi event chain dù chúng liên quan. Cho phép test độc lập.
2. **Outcome không bao giờ hidden.** Player phải có thể suy luận được tại sao một cái gì đó xảy ra. Đó là phần "uncertainty, not opacity".
3. **Consequence phải observable.** Mỗi event outcome tạo ít nhất 1 thay đổi state nhìn thấy được (shop đóng, NPC chết, family status đổi).
4. **Có thể chơi được khi bỏ qua 90% hệ thống.** Mystery là optional, dynamic market chưa có nhưng game vẫn đầy đủ loop.
5. **Trung thực về scope là kỹ năng.** Tôi đã học cách tách "Designed Future" khỏi "Implemented Current". Đây là kỹ năng rất quan trọng khi nộp portfolio / làm việc nhóm.

### Audit thực tế trong codebase (3 phát hiện)

Trong quá trình viết GDD master, tôi đã audit codebase để đối chiếu với những gì đã được claim trong tài liệu cũ. Ba phát hiện đáng chú ý:

**1. Đính chính định vị.**

Vào đầu quá trình viết GDD, tôi đặt "Farm Horror" làm genre chính và đẩy horror vào pillar 1-2. Sau khi đối chiếu với code, tôi nhận ra:

- Code chỉ có 3 điểm chạm với "horror" (anomaly weather signal, strange events flag, NPC dialogue `_grief` variant).
- Code đã build cho thấy core loop là farming + mua bán + quan hệ NPC.

Quyết định cuối: **đính chính định vị** sang farming/life simulation prototype, hạ horror xuống optional depth layer. Hành động kỹ thuật:

- Tạo GDD v2 file mới (`game-demo-gdd-v2.md`), không sửa file cũ để giữ archive.
- Thêm §7 với 4 nhóm **Implemented / In Progress / Designed Future / Won't-have** để không overclaim.
- Lập bảng `NPC scene_path reference` để biết chính xác 5/5 NPC đang được tham chiếu nhưng chỉ 1/5 có scene file.

**Bài học:** "đọc code trước khi viết spec" nghe sáo nhưng thật sự quan trọng. Tôi đã tránh được việc claim "game horror" với 3 điểm chạm.

**2. NPC scenes không tồn tại.**

Khi audit codebase tôi phát hiện:

- 5 NPC được define trong `family_registry.gd` (`shopkeeper_father`, `shopkeeper_son`, `farmer_mother`, `farmer_daughter`, `hermit`).
- 5 scene path được tham chiếu (`res://scenes/npc/<id>.tscn`).
- Nhưng chỉ có 1 file thực sự tồn tại (`shopkeeper.tscn`).

Đây là khoảng cách giữa **spec** và **deliverable** mà tôi sẽ tập trung giải quyết ở Phase 1. Trong portfolio tôi ghi rõ "5 NPC defined, 1 NPC playable" — thay vì nói "5 NPC hoạt động đầy đủ".

**3. Harvest file duplication.**

Resource folder có 10 file `<crop>.tres` và `<crop>_harvest.tres` với giá khác nhau (ví dụ: `turnip.tres` sell 30, `turnip_harvest.tres` sell 11). Đây là hai ID khác nhau cho cùng một concept. Khi một dev nào đó thay giá, hai file có thể drift.

Đây là kiểu bug tech debt tôi sẽ ưu tiên audit trong Phase 1 cleanup. Đối với portfolio, tôi ghi rõ "22 items, 5 có duplicate harvest variant" thay vì "22 unique items".

---

### 5 điều muốn cải thiện (liên quan puzzle game design)

1. **Level editor data-driven.** Học từ Event Chain: editor = 1 file cấu hình, không phải code.
2. **Player skill curve.** Farming loop có giá trị nhưng chưa có skill ceiling. Puzzle game cần solve curve rõ ràng.
3. **Hint system.** Player bỏ cuộc thì gợi ý gì? Có nên auto-unlock sau N lần fail? (Hiện chưa có.)
4. **Replay value for emergent narrative.** Một save có thể replay không, hay chỉ vào đúng 1 arc? Học cách thiết kế branching save.
5. **Onboarding rõ trong 2 phút.** Tôi chưa có tutorial — farming loop khá "lạ" cho người chơi quen Stardew. Cần test first 2 minutes.

### Roadmap tóm tắt

- **Phase 1 (đang làm)**: fix UID, thêm NPC scene, polish UI.
- **Phase 2**: farming polish, shop ổn định, dialogue per NPC.
- **Phase 3**: relationship tier, quest tracker, consequence feedback rõ hơn.
- **Phase 4** (future direction): dynamic market, negotiation system, NPC economic behavior.
- **Phase 5** (future direction): lore system, anomaly variants, hidden areas.
- **Phase 6**: UX, audio, balance, playtest.

---

## 9. Tại sao Falcon Game Studio?

Lưu ý trung thực: tôi chưa tìm hiểu sâu portfolio Falcon Game Studio — website chỉ liệt kê 4 sản phẩm (FireSquad, HighGear, StarDrone, ClimbRescue) mà không kèm mô tả chi tiết trên trang chủ. Một vài câu dưới đây dựa trên cái tên và định vị công ty:

**Tại sao Falcon:**

- Falcon là một puzzle + casual game studio đã có nhiều sản phẩm live — đây là điểm đến tốt để học puzzle design từ practice, không phải từ textbook.
- Dòng **Puzzle** của Falcon có vẻ tập trung vào **system + level design** (các game như Goods Sorting, Screw Puzzle là dạng player tương tác với hệ thống ngày càng phức tạp). Đây chính xác là kỹ năng tôi đã luyện qua Risk Calculator và Event Chain Engine.
- Tôi thích làm việc trên **game dài hạn, có vòng lặp**. Ngành puzzle mobile có chu kỳ rõ ràng: prototype → soft launch → live ops. Tôi muốn hiểu full pipeline này.

**Những gì tôi có thể đóng góp:**

- Hệ thống phân tích (Risk, Chain) có thể tái sử dụng cho level difficulty curve.
- Khả năng viết **spec rõ ràng** cho engineer (GDD master chính là ví dụ).
- Tư duy "tách UI ra khỏi logic" — áp dụng cho việc design puzzle có thể A/B test UI mà không động gameplay.
- Trung thực về scope — tôi sẽ không claim làm được thứ chưa làm.

**Câu hỏi tôi muốn hỏi interviewer:**

1. Trong team design của Falcon, intern sẽ làm việc gì ở 3 tháng đầu? Có một project cụ thể đang chờ intern không?
2. Falcon đo lường thành công của một puzzle level bằng metric nào? (retention D1, completion rate, hoặc qualitative playtest?)
3. Trong soft launch, bạn cân bằng giữa "player giải được puzzle" và "player muốn share" như thế nào?
4. Có space cho intern propose một mechanic nhỏ (1-2 sprint) không?

**Một ghi chú về puzzle game design nói chung:**

Khi phân tích pattern của Risk Calculator để áp dụng cho puzzle game, tôi thấy 3 điểm chuyển đổi:

1. **Scalar risk → Distribution of outcome stars.** Thay vì 4 bucket (safe/dead/injured/delayed), puzzle game thường dùng 3-star rating. Cùng dạng "roll xuống bucket", nhưng bucket visual khác.
2. **Modifier stack → Difficulty slider + level designer intent.** Trong puzzle game, modifier thường là "số move tối đa", "có hint", "blocked cells". Designer chọn lúc build level thay vì runtime.
3. **Information gating → First-attempt vs hint-after-fail.** Risk Calculator dùng context-only (player thấy weather, NPC personality). Puzzle game tương tự: lần đầu nên ẩn số, sau N lần fail thì hiện.

Có 2 trade-off lớn khi áp dụng pattern Risk Calculator vào puzzle:

- **Pro:** Tạo cảm giác "uncertainty, not opacity" — player không bực vì giả ngẫu nhiên.
- **Con:** Cần design tốt để context đủ informative, không mơ hồ.

Tôi nghĩ pattern này xứng đáng được thử trong puzzle game early prototype. Sẵn sàng thảo luận chi tiết trong interview.

---

## 10. Phụ lục kỹ thuật (tóm tắt)

| Mục | Số liệu |
|---|---|
| Scripts GDScript | 57 |
| Scenes `.tscn` | 21 |
| Item resources `.tres` | 22 |
| Autoload scripts | 24 |
| Maps playable | 6 scene (`farm_map`, `farm_map_v2`, `town_map`, `inside_house_map`, `inside_shop_map`, `Farm_`) |
| NPC defined | 5 (qua FamilyRegistry) |
| NPC playable scene | 1 (`shopkeeper.tscn`) |
| Family | 3 (Voss / Miller / Hermit) |
| Schedule entries | 4 |
| Risk activities | 5 |
| Weather types | 8 |
| Seasons | 4 (mỗi mùa 30 ngày) |
| Quests | 4 |
| Event chains | 3 |
| Trading items | 22 (chưa dynamic price) |

**Tài liệu tham chiếu:**

- Game Design Document master: `design/gdd/game-demo-gdd-v2.md` (27 sections, ~1100 dòng).
- Source code: xem trong project, đường dẫn tương đối `scripts/...` (57 files).

---

## 11. Phase 1 — 3 việc cụ thể tôi sẽ làm trong 4 tuần tới

Không liệt kê 10 ý tưởng hay. Chỉ 3 việc, vì đó là realistic trong 1 tháng.

### Việc 1 — Tạo 4 NPC scene còn lại (1 tuần)

Mục tiêu: `shopkeeper_father.tscn`, `farmer_mother.tscn`, `farmer_daughter.tscn`, `hermit.tscn` phải tồn tại trong `res://scenes/npc/` với cùng pattern `shopkeeper.tscn`.

**Cách làm:** Copy `shopkeeper.tscn`, đổi tên + texture + dialogue_id + sprite color. Không có gì fancy — chỉ cần file tồn tại, hiển thị sprite, mở dialogue khi player E.

### Việc 2 — Hợp nhất duplicate harvest `.tres` (2 ngày)

Mục tiêu: Một cây chỉ có 1 file `.tres`, không có duplicate harvest ID.

**Cách làm:** So sánh `<crop>_harvest.tres` với `<crop>.tres` để xác định file nào được dùng bởi `farm_manager.harvest_crop()`. Xóa file còn lại. Update `event_chain_engine` reference nếu cần.

### Việc 3 — Thêm Quest Tracker UI (2 tuần)

Mục tiêu: Player thấy 1 danh sách quest đang active + progress, không chỉ qua dialogue.

**Cách làm:** Tạo 1 CanvasLayer mới `scripts/ui/quest_tracker_ui.gd` listen `QuestSystem.quest_accepted` và `quest_completed`. Trong HUD `scripts/ui/hud.gd` có 1 toggle E để show/hide.

**Ba việc này:** scope cố ý giữ hẹp, impact lớn, không cần design mới. Chỉ là "lấp khoảng cách giữa spec và playable" — đó là kiểu intern contribution Falcon có thể cần ở 1 dòng puzzle level editor nào đó.

---

## Phụ đề — Lời cuối

Cảm ơn anh/chị đã dành thời gian đọc. Nếu có điểm nào chưa rõ, tôi sẵn sàng trả lời chi tiết hơn.

Tôi không muốn gửi portfolio với những câu "đã làm hết" mà rồi khi review code hoặc phỏng vấn kỹ thuật lộ ra là chưa. Bản này cố tình tách rõ những gì đã build khỏi những gì đang là design direction — nếu anh/chị thấy điểm nào chưa thuyết phục, xin chỉ trực tiếp, tôi sẽ giải thích cụ thể.

---

## Phụ đề 2 — Hạn chế của portfolio này (cuối cùng)

Để hoàn toàn trung thực, portfolio này có những hạn chế tôi muốn nói rõ:

1. **Không có screenshot / video.** Tôi chưa build được mức polish để showcase visual. Nếu reviewer cần, tôi sẵn sàng build 1 build screenshots-only trong vòng 2-3 ngày.
2. **Phần "Tại sao Falcon" dựa nhiều vào đoán.** Tôi đã truy cập `falcongamestudio.com` và chỉ thấy 4 tên game. Không có case study chi tiết từng game. Tôi ưu tiên viết các câu hỏi thay vì bịa số liệu về game của Falcon.
3. **Game Demo chưa có balance thực tế.** Tất cả % trong Risk Calculator / Event Chain là chưa qua playtest. Tôi nghĩ chúng hợp lý, nhưng chưa verify.
4. **Tôi không có sản phẩm shipped.** Game Demo là prototype, không phải game thương mại. Đây là điểm yếu tôi biết. Tôi đều đặn mỗi tuần dành 5-10 giờ polish để tăng level.
5. **Phần "Design Process" không đầy đủ.** Tôi chỉ liệt kê 3 quyết định cụ thể. Sẽ dài hơn nếu có nhiều time. Đây là điểm tôi cần cải thiện trong documentation skill.

**Tại sao vẫn gửi portfolio này:** vì tôi tin các hệ thống Risk Calculator, Event Chain Engine, NPC + Family + Schedule là đủ depth cho 1 intern GDD. Các hạn chế trên đều là thứ tôi có thể cải thiện, không phải blocker.

Nếu anh/chị có feedback hoặc muốn xem code, vui lòng phản hồi.
