# itch.io Page Copy — GameDemo

## Tên game

**GameDemo — A Day in a Living Community**

## Tagline

**Every day is a choice. Every choice changes tomorrow.**

## Mô tả ngắn

GameDemo là một prototype farming/life-sim 2D, nơi bạn xây dựng routine trong một cộng đồng nhỏ. Trồng trọt, quản lý thời gian và năng lượng, gặp gỡ NPC theo lịch trình riêng, nhận quest và quan sát thế giới thay đổi qua từng ngày.

## Short description (English)

GameDemo is a 2D farming/life-sim prototype about building a daily routine in a small living community. Farm, manage your time and energy, meet NPCs with their own schedules, complete delivery quests, and see the world change from day to day.

---

## Mô tả đầy đủ

### Một ngày của bạn sẽ ưu tiên điều gì?

GameDemo là một prototype farming/life-sim 2D top-down được xây dựng bằng Godot 4.5.

Bạn bắt đầu ngày mới với một lượng thời gian, năng lượng và vàng có hạn. Bạn có thể ở lại nông trại để chăm cây, đi đến thị trấn mua bán, nhận nhiệm vụ hoặc tìm một NPC đang di chuyển theo lịch trình riêng của họ.

Bạn không thể làm tất cả mọi việc trong cùng một ngày. Điều quan trọng không chỉ là hoàn thành nhiều hành động nhất, mà là quyết định điều gì đáng để ưu tiên.

### Các hoạt động chính

- Cày đất, gieo hạt, tưới cây và thu hoạch.
- Quản lý Time, Energy và Gold.
- Sắp xếp item trong Inventory và Toolbar.
- Mua seed/tool và bán nông sản.
- Nhận delivery quest từ Quest Board.
- Giao đúng item cho đúng NPC để nhận Gold và tăng relationship.
- Quan sát Marcus di chuyển giữa các khu vực theo schedule.
- Ngủ để chuyển ngày và cập nhật crop, quest cùng world state.

### Điểm tôi muốn thử nghiệm

Tôi muốn kiểm tra liệu những hệ thống quen thuộc của farming game có thể tạo ra các quyết định có ý nghĩa hay không.

Time và Energy tạo ra giới hạn. NPC schedule và quest tạo ra những time window. Farming cung cấp resource để người chơi chuẩn bị cho lựa chọn tiếp theo.

Đây vẫn là một graybox prototype. Một số hệ thống còn đang được phát triển và các con số hiện tại chưa được xem là final balance.

### Trạng thái prototype

- **Đã có:** farming framework, inventory, toolbar, shop, quest board, dynamic delivery quest, dialogue, Energy và NPC schedule framework.
- **Đang hoàn thiện:** balancing, NPC route regression, save/load validation, UX và playtest.
- **Chưa có:** final art, audio hoàn chỉnh, dynamic market và mystery arc đầy đủ.

Feedback về trải nghiệm, controls hoặc những điểm bạn không hiểu sẽ rất hữu ích.

---

## Full description (English)

### What will you prioritize today?

GameDemo is a 2D top-down farming/life-sim prototype built with Godot 4.5.

You start each day with limited time, energy, and gold. You can stay on the farm to care for your crops, travel to town to buy and sell items, accept a delivery quest, or look for an NPC following their own daily schedule.

You cannot do everything in one day. The core experiment is not about completing the most tasks possible, but about deciding what is worth prioritizing.

### Main activities

- Plow soil, plant seeds, water crops, and harvest.
- Manage Time, Energy, and Gold.
- Organize items in your Inventory and Toolbar.
- Buy seeds/tools and sell produce.
- Accept delivery quests from the Quest Board.
- Deliver the right item to the right NPC for Gold and relationship rewards.
- Observe Marcus moving between locations according to his schedule.
- Sleep to advance the day and update crops, quests, and world state.

### Design focus

This prototype explores whether familiar farming-game systems can create meaningful decisions.

Time and Energy create constraints. NPC schedules and quests create opportunity windows. Farming supplies the resources needed to prepare for the next decision.

This is still a graybox prototype. Some systems are in development, and current values should not be considered final balance.

### Prototype status

- **Implemented:** farming framework, inventory, toolbar, shop, quest board, dynamic delivery quests, dialogue, Energy, and NPC schedule framework.
- **In progress:** balancing, NPC route regression, save/load validation, UX, and playtesting.
- **Not included yet:** final art, complete audio, dynamic market, and a complete mystery arc.

Feedback about the experience, controls, or anything that feels unclear is welcome.

---

## Hướng dẫn chơi

### Controls

| Hành động | Phím |
|---|---|
| Di chuyển | WASD |
| Tương tác / nói chuyện / mở cửa | E |
| Mở Inventory | Tab |
| Chọn Toolbar slot | 1–5/cuộn |
| Dùng tool/seed trên farm | Chuột phải |
| Xem trạng thái hoặc thu hoạch crop | Chuột trái |

> Nếu đang mở dialogue hoặc UI, hãy đóng UI trước khi điều khiển nhân vật.

### Bắt đầu nhanh

1. Rời khỏi nhà và khám phá khu vực xung quanh.
2. Đi đến farm.
3. Chọn hoe hoặc seed trong Toolbar.
4. Đứng gần ô đất và dùng chuột phải để thực hiện hành động.
5. Tới town để mua/bán item.
6. Mở Quest Board, đọc objective, deadline và reward.
7. Nhận quest rồi giao item cho NPC phù hợp.
8. Quay về nhà và tương tác với giường để ngủ.
9. Sang ngày mới để quan sát crop, NPC và quest thay đổi.

### Mẹo nhỏ

- Đừng dùng hết Energy ngay từ đầu ngày.
- Hãy kiểm tra Quest Board trước khi gieo trồng.
- NPC không đứng yên một chỗ cả ngày; hãy để ý schedule của Marcus.
- Nếu không thể thực hiện một hành động, hãy kiểm tra item đang chọn, khoảng cách tới target và lượng Energy.

---

## Recruiter quick start

Nếu bạn chỉ có vài phút, hãy thử flow sau:

```text
Leave house
→ Visit farm
→ Perform one farming action
→ Visit town/shop
→ Open Quest Board
→ Accept a delivery quest
→ Return home and sleep
```

Mục tiêu của flow này là cho thấy cách farming, quest, economy và day transition liên kết với nhau.

---

## Credits

**Design / Programming / Documentation:** [Họ và tên]  
**Engine:** Godot 4.5  
**Genre:** Farming / Life Simulation  
**Status:** Personal graybox prototype  
**Portfolio:** [Link portfolio hoặc CV]
