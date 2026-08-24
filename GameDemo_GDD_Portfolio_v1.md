# GameDemo — Game Design Document
### Portfolio / Recruitment Version

**Vị trí ứng tuyển:** Game Designer Intern  
**Prototype:** Playable Graybox Prototype  
**Engine:** Godot 4.5 / GDScript  
**Trạng thái:** Prototype đang phát triển  
**Phiên bản:** Portfolio v1

---

# 1. Game Overview

## 1.1 One-liner

**GameDemo** là một game **farming / life simulation RPG** top-down 2D, trong đó farming là hoạt động nền tảng, còn **trading, social interaction và những quyết định hằng ngày** là trung tâm của trải nghiệm.

Người chơi xây dựng cuộc sống của mình trong một cộng đồng nhỏ: sản xuất và trao đổi hàng hóa, quản lý thời gian và năng lượng, quan sát NPC, xây dựng quan hệ và phản ứng với những thay đổi của thế giới.

Một lớp **narrative mystery tùy chọn** tồn tại bên dưới đời sống thường ngày. Người chơi có thể hoàn toàn bỏ qua lớp này và vẫn trải nghiệm được farming/life-sim loop chính.

## 1.2 Player Fantasy

Người chơi không chỉ muốn "hoàn thành nhiệm vụ", mà muốn có cảm giác:

> **"Đây là một cộng đồng đang sống, và những quyết định của tôi tạo ra câu chuyện của riêng mình."**

Trải nghiệm mong muốn:

- Một ngày có giới hạn về thời gian và năng lượng, buộc player phải lựa chọn.
- Farming tạo ra tài nguyên và nền tảng kinh tế.
- NPC có lịch trình, nhu cầu và trạng thái riêng thay vì chỉ đứng chờ player.
- Thông tin từ thế giới giúp player đưa ra quyết định nhưng không cho họ biết chắc tương lai.
- Quyết định có thể tạo ra hậu quả và thay đổi trạng thái của thế giới.
- Mystery là lớp nội dung dành cho người chơi tò mò, không phải điều kiện để tiếp tục gameplay chính.

---

# 2. Design Goals

## 2.1 Meaningful Daily Decisions

Mỗi ngày player có một ngân sách giới hạn về **time + energy**.

Player phải cân nhắc:

> Farm ↔ Trade ↔ Socialize ↔ Explore ↔ Rest

Mục tiêu không phải khiến player luôn bận rộn, mà khiến mỗi lựa chọn có **opportunity cost**.

## 2.2 Living Community

NPC được định hướng có:

- lịch trình;
- nghề nghiệp;
- quan hệ;
- nhu cầu;
- trạng thái;
- ký ức / state flags liên quan đến những sự kiện quan trọng.

NPC không tồn tại chỉ để đứng chờ player hoặc giao quest.

## 2.3 Inference Over Information

Game không hiển thị toàn bộ hệ thống dưới dạng những con số trực tiếp.

Player tiếp cận thông tin qua:

- quan sát;
- dialogue;
- NPC behavior;
- market;
- weather / world events;
- knowledge cá nhân.

Mục tiêu:

> **Player không biết chắc điều gì sẽ xảy ra, nhưng có đủ evidence để đưa ra một quyết định có cơ sở.**

## 2.4 Consequence

Một quyết định có giá trị khi nó có thể làm thay đổi trạng thái tiếp theo của:

- player;
- NPC;
- economy;
- quest;
- world;
- narrative.

## 2.5 Optional Mystery

Mystery / strange events là một **narrative layer**.

Một player có thể tập trung vào farming, trading và social life mà không bị ép phải giải mystery.

---

# 3. Core Gameplay Loop

## 3.1 Design Loop

```text
OBSERVE
   ↓
PLAN
   ↓
FARM / BUY / PRODUCE
   ↓
TRADE / INTERACT
   ↓
OBSERVE CONSEQUENCES
   ↓
UPDATE PLAN
   ↓
NEXT DAY
```

Loop này tập trung vào **decision-making** thay vì chỉ liệt kê các hoạt động player thực hiện.

## 3.2 Current Prototype Loop

```text
Farm
 ↓
Harvest
 ↓
Inventory
 ↓
Buy / Sell
 ↓
Manage Energy & Time
 ↓
Interact with NPC
 ↓
Quest / Event
 ↓
Next Day
```

## 3.3 Future Design Direction

```text
Observe information
 ↓
Form hypothesis
 ↓
Choose action
 ↓
Market / NPC / World changes
 ↓
Evaluate result
 ↓
Update strategy
```

**Dynamic market, negotiation và information-driven economy là future systems, không được xem là đã hoàn thành trong prototype hiện tại.**

---

# 4. Time & Energy

## 4.1 Purpose

Time và energy tạo ra **decision budget** cho mỗi ngày.

Player không thể tối ưu mọi hoạt động cùng lúc.

Ví dụ:

> Player có thể farm thêm, đi town bán hàng hoặc dành thời gian cho NPC — nhưng mỗi lựa chọn đều làm giảm thời gian dành cho lựa chọn khác.

## 4.2 Current Prototype

- Max Energy: 20
- Low Energy Threshold: 5
- Energy thấp → movement speed giảm
- Energy = 0 → knockout / forced sleep flow
- Knockout penalty hiện tại: mất 25% gold
- Sleep reset energy vào ngày tiếp theo

## 4.3 Design Intention

Energy không chỉ là một thanh resource.

Nó giới hạn số lượng hành động player có thể thực hiện trong một ngày và tạo opportunity cost giữa các hoạt động.

**Current state: Implemented.**

---

# 5. Farming System

## 5.1 Farming State Machine

```text
EMPTY
  ↓
PLOWED
  ↓
SEEDED
  ↓
SPROUTED
  ↓
GROWING
  ↓
MATURE
  ↓
HARVEST
  ↓
EMPTY
```

Crop có thể chuyển sang:

```text
WILTED
```

nếu không được chăm sóc đủ lâu.

## 5.2 Current Crop Types

- Wheat
- Corn
- Tomato
- Potato
- Turnip
- Mystery Plant

## 5.3 Core Interaction

```text
Plow
 ↓
Plant
 ↓
Water
 ↓
Wait / Manage
 ↓
Harvest
```

Farm state được duy trì qua ngày và không phụ thuộc vào scene player đang đứng.

## 5.4 Design Purpose

Farming tạo:

- resource;
- daily activity;
- economic input;
- time pressure;
- reason để player quay lại farm mỗi ngày.

**Current state: Implemented.**

---

# 6. Economy & Trading

## 6.1 Current Prototype

Prototype hiện có:

- item database;
- inventory;
- buy;
- sell;
- gold;
- seed purchasing;
- farm produce selling.

Sell price hiện tại sử dụng:

```text
Sell Price = Buy Price × 0.5
```

### Current loop

```text
Farm
 ↓
Harvest
 ↓
Sell
 ↓
Earn Gold
 ↓
Buy Seeds
 ↓
Farm
```

**Current state: Implemented.**

## 6.2 Future Dynamic Market

Dynamic market là một phần quan trọng của design direction nhưng **chưa phải system hoàn chỉnh trong prototype hiện tại**.

Market dự kiến chịu ảnh hưởng bởi:

- supply;
- demand;
- player production;
- NPC production / consumption;
- season;
- weather;
- events;
- availability of alternative supply;
- product quality.

Giá không nên thay đổi như random number.

Một thay đổi giá nên có nguyên nhân mà player có khả năng quan sát hoặc suy luận.

## 6.3 Negotiation

Negotiation là future system.

Mục tiêu:

> Player không chỉ chọn "Sell", mà phải quyết định bán cho ai, mức giá nào và chấp nhận trade-off nào.

NPC dự kiến cân nhắc:

- nhu cầu;
- tiền;
- sở thích;
- relationship;
- lịch sử giao dịch;
- tình trạng thị trường.

---

# 7. Information System

Đây là một trong những nguyên tắc design quan trọng nhất của game.

## 7.1 Information Should Be Actionable

Thông tin nên giúp player đưa ra một quyết định.

Ví dụ:

> Weather forecast → Có nên gieo thêm crop?

> NPC/shop gần hết hàng → Có nên giữ hàng để bán sau?

## 7.2 Information Should Be Layered

Thông tin đến từ nhiều lớp:

```text
Observation
   ↓
Dialogue
   ↓
NPC Behavior
   ↓
News / Weather
   ↓
Market
   ↓
Player Knowledge
```

Không phải tất cả thông tin đều xuất hiện dưới dạng UI numbers.

## 7.3 Information Should Support Inference

Game không nói:

> "Supply sẽ giảm 40% vào ngày mai."

Thay vào đó player có thể thấy:

- một khu vực mất mùa;
- NPC bắt đầu thiếu hàng;
- weather forecast xấu;
- trader đang trên đường tới;
- shop inventory giảm.

Player hình thành một **hypothesis**.

Điểm quan trọng:

> **Uncertainty không đồng nghĩa với opacity.**

Player có thể sai, nhưng nếu họ có thể giải thích:

> "Tôi nghĩ chuyện này sẽ xảy ra vì..."

thì quyết định vẫn có cơ sở.

### Design Goal

Một player giỏi hơn player kém không phải vì họ nhớ nhiều con số hơn, mà vì họ:

- nhận ra pattern tốt hơn;
- đánh giá reliability của information tốt hơn;
- suy luận consequence tốt hơn;
- quản lý risk tốt hơn.

---

# 8. NPC & Social Simulation

## 8.1 NPC Model

NPC được định hướng có:

- personality;
- profession;
- schedule;
- needs;
- relationship;
- assets;
- memory / state flags.

## 8.2 Current Prototype

Prototype có nền tảng cho:

- NPC interaction;
- relationship tracking;
- dialogue;
- NPC schedule data;
- NPC state;
- family / succession logic.

NPC schedule và movement/pathfinding đang được hoàn thiện trong prototype.

## 8.3 Target Behavior

Ví dụ:

```text
Morning
   ↓
Work

Afternoon
   ↓
Town / Farm

Evening
   ↓
Home

Night
   ↓
Sleep
```

Player có thể gặp cùng một NPC ở những địa điểm khác nhau tùy thời gian.

### Design Purpose

NPC cần có cuộc sống của riêng họ thay vì tồn tại chỉ khi player tương tác.

---

# 9. Dialogue System

Dialogue system hỗ trợ:

- JSON dialogue;
- typewriter effect;
- choices;
- skip;
- input blocking;
- relationship tracking;
- conditional dialogue direction.

Dialogue có thể thay đổi dựa trên:

- day;
- quest state;
- relationship;
- world state;
- event consequence.

## Design Purpose

Dialogue không chỉ truyền lore.

Nó cũng là một **information source** giúp player hiểu NPC và thế giới.

---

# 10. Quest System

Prototype có:

- Quest Board;
- static quest structure;
- dynamic delivery quest;
- reward;
- quest state;
- NPC-linked delivery dialogue.

## Design Goal

Quest nên tạo mục tiêu ngắn hạn nhưng không thay thế core gameplay.

Ví dụ:

```text
NPC needs Wheat
 ↓
Player decides whether to produce / buy / deliver
 ↓
Reward / relationship / state change
```

Quest nên bổ trợ cho:

- farming;
- trading;
- social interaction;
- exploration.

Thay vì trở thành một chuỗi nhiệm vụ tách biệt khỏi simulation.

---

# 11. Event & Consequence System

## 11.1 Event Structure

```text
TRIGGER
 ↓
INFORMATION
 ↓
PLAYER DECISION
 ↓
OUTCOME
 ↓
CONSEQUENCE
 ↓
WORLD / NPC STATE CHANGE
```

Event có thể chịu ảnh hưởng bởi:

- weather;
- time;
- NPC personality;
- player intervention;
- world state.

## 11.2 Core Rule

Outcome có thể không chắc chắn.

Nhưng uncertainty phải đến từ những yếu tố có thể được player quan sát hoặc suy luận ở mức phù hợp.

Không nên có:

```text
Random Event
 ↓
Random Result
 ↓
Player has no way to understand why
```

Thay vào đó:

```text
World information
 ↓
Player observation
 ↓
Hypothesis
 ↓
Decision
 ↓
Risk
 ↓
Outcome
 ↓
Consequence
```

Mục tiêu là khiến player cảm thấy:

> **"Tôi đánh giá sai rủi ro."**

thay vì:

> **"Game lừa tôi."**

---

# 12. Example Event — Old Voss

Một event mẫu dùng để minh họa design direction:

```text
Old Voss plans a mountain trip
        ↓
Player observes weather / schedule / NPC behavior
        ↓
Player may intervene / escort / ignore
        ↓
Risk is resolved
        ↓
Outcome
        ↓
World consequences
```

Possible outcomes:

- Safe
- Delayed
- Injured
- Dead

Possible consequences:

- shop opens late;
- shop closes temporarily;
- dialogue changes;
- family state changes;
- another NPC takes over responsibilities;
- related event / quest is triggered.

### Important Design Constraint

Probability values trong prototype chỉ là **tuning values**.

Chúng chưa phải final balance.

Quan trọng hơn probability là:

> Player có thể thu thập evidence và đưa ra quyết định trước khi outcome xảy ra.

---

# 13. Consequence Design

Consequence là cầu nối giữa event và world state.

Ví dụ:

```text
NPC injured
 ↓
Shop closes for several days
 ↓
Alternative seller becomes relevant
 ↓
Dialogue changes
 ↓
Player adapts
```

Hoặc:

```text
NPC dies
 ↓
Family state changes
 ↓
Successor takes over
 ↓
Shop / dialogue / schedule changes
```

Mục tiêu là để player nhận thấy:

> **"Quyết định này đã làm thế giới thay đổi."**

Consequence không nhất thiết phải lớn.

Một thay đổi nhỏ nhưng có continuity cũng có thể tạo cảm giác world đang phản ứng.

---

# 14. Design Rationale

## 14.1 Why Limited Energy?

Để tạo opportunity cost.

Nếu player có thể làm mọi thứ trong một ngày, schedule, social interaction và planning sẽ mất một phần ý nghĩa.

## 14.2 Why NPC Schedules?

Để NPC tồn tại độc lập với player.

Player phải quan sát:

> "NPC này thường ở đâu vào thời điểm nào?"

thay vì mọi NPC luôn đứng cố định ở một vị trí.

## 14.3 Why Information Instead of Explicit Prediction?

Để biến market/world state thành bài toán:

> observation + information gathering + inference + risk management

thay vì spreadsheet optimization.

## 14.4 Why Uncertain Outcomes?

Để player không thể kiểm soát tuyệt đối thế giới.

Nhưng uncertainty phải đi kèm agency:

```text
Collect evidence
 ↓
Evaluate risk
 ↓
Act
 ↓
Accept consequence
```

## 14.5 Why Optional Mystery?

Mystery phục vụ những player muốn đào sâu vào lore.

Nó không được phép trở thành điều kiện để trải nghiệm farming/life-sim loop chính.

---

# 15. Current Prototype Status

| System | Status | Notes |
|---|---|---|
| Player movement | Implemented | 4-direction movement + sprint |
| Interaction | Implemented | Raycast priority + proximity fallback |
| Farming | Implemented | Full basic crop cycle |
| Energy | Implemented | Threshold + knockout |
| Time / Day cycle | Implemented | Day progression |
| Weather | Implemented | Basic weather states |
| Inventory / Hotbar | Implemented | Stack, drag/drop, use |
| Basic Buy / Sell | Implemented | Fixed-price prototype economy |
| Dialogue | Implemented | JSON + choices + relationship |
| NPC relationship | Implemented | Basic tracking |
| NPC schedule | In progress | Being completed |
| NPC movement / pathfinding | In progress | Being completed |
| Quest | Implemented / expanding | Delivery and board structure |
| Event chain | In progress | Expanding consequence logic |
| Dynamic market | Planned | Supply / demand simulation |
| Negotiation | Planned | NPC-specific bargaining |
| Information inference | Design direction | Future implementation |
| Optional mystery | Partial / planned | Narrative layer |
| Audio | Not part of current prototype | Future |
| Romance | Future | Not core prototype scope |

---

# 16. Prototype Scope

## The prototype is intended to demonstrate

1. Player movement and interaction.
2. A complete farming loop.
3. Time and energy as decision constraints.
4. Inventory and basic economy.
5. NPC interaction and dialogue.
6. NPC schedule / social simulation direction.
7. Quest and event structure.
8. State changes and consequences.
9. A playable graybox implementation of the design.

## It is not intended to demonstrate

- final art;
- final audio;
- production-ready content volume;
- complete dynamic market;
- complete negotiation;
- complete narrative;
- final balance.

Visuals are intentionally kept as **graybox / placeholder assets** because the prototype is intended to validate gameplay and systems rather than final art production.

---

# 17. Known Limitations

Current prototype limitations:

- NPC movement/pathfinding is still being completed.
- Some NPC scenes/content are incomplete.
- Dynamic market is not yet implemented.
- Negotiation is not yet implemented.
- Advanced social simulation is not yet complete.
- Event / quest content is still being expanded.
- Audio is not part of the current prototype evidence.
- Visual assets remain placeholders.
- Balance values are prototype tuning values and have not been treated as final.

These limitations are explicitly separated from the design direction so the document does not present planned systems as completed features.

---

# 18. Design Hypothesis

The prototype is primarily testing one design hypothesis:

> **Can a farming/life-sim game create meaningful player decisions by combining limited daily resources, NPC behavior, trading, information and consequences?**

The intended decision structure is:

```text
System State
      ↓
Information
      ↓
Player Interpretation
      ↓
Decision
      ↓
Consequence
      ↓
Changed System State
      ↓
Next Decision
```

The prototype therefore prioritizes:

- system interaction;
- player decision-making;
- consequence;
- world-state continuity;

over visual polish and content quantity.

---

# 19. Portfolio Note

This document is a **design overview accompanying a playable graybox prototype**.

It focuses on:

- design intent;
- player experience;
- system relationships;
- implemented vs planned scope;
- design rationale.

Detailed source-code architecture, autoload lists, file indexes and implementation-specific debugging notes are intentionally excluded from this version because they are not required to understand the design.

The purpose of the accompanying prototype is to let the reviewer verify which parts of the design are already playable rather than relying on the GDD alone.
