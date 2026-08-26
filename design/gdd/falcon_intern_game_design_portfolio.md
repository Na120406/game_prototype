# GameDemo — Intern Game Designer Portfolio
## Tailored Application Version — Falcon Game Studio

**Ứng viên:** [Tên của bạn]  
**Vị trí:** Intern Game Designer  
**Dự án:** GameDemo — playable 2D farming / life-simulation RPG graybox  
**Engine:** Godot 4.5 / GDScript  
**Tài liệu nền:** `GameDemo_GDD_Portfolio_v1.md`

---

## 1. Portfolio Summary

GameDemo là prototype tập trung vào câu hỏi thiết kế:

> Làm thế nào để một game farming/life-sim tạo ra quyết định có ý nghĩa thay vì chỉ là chuỗi nhiệm vụ lặp lại?

Tôi xây dựng prototype theo hướng systems-first: mỗi ngày người chơi phải cân bằng thời gian, năng lượng, farming, trading, social interaction và thông tin từ thế giới. NPC có lịch trình, vị trí, trạng thái và hành vi thay đổi theo thời gian.

Dự án thể hiện chu trình **ý tưởng → đặc tả hệ thống → prototype có thể kiểm chứng**.

## 2. Core Loop

```text
Quan sát → Lập kế hoạch → Trồng/Thu hoạch → Mua/Bán
→ Tương tác NPC → Nhiệm vụ/Sự kiện → Quan sát hậu quả → Ngày tiếp theo
```

- **Time:** giới hạn cơ hội hành động.
- **Energy:** giới hạn số hoạt động trong ngày.
- **Economy:** biến sản phẩm thành gold và hạt giống.
- **NPC schedule:** tạo cơ hội social/exploration.
- **Quest/event:** tạo mục tiêu và thay đổi state.

## 3. Điểm nhấn thiết kế: NPC sống độc lập

Mỗi NPC được quản lý như một persistent runtime instance. Khi chuyển map, NPC:

1. Đi bằng velocity tới portal nguồn.
2. Handoff qua scene đích.
3. Xuất hiện tại portal đích được định nghĩa trong map.
4. Tiếp tục đi bằng velocity tới schedule target.
5. Khi Player vào map, Player quan sát state hiện tại thay vì NPC bị reset.

Schedule target, route source, portal arrival và post-arrival target là bốn khái niệm tách biệt.

## 4. Case Study: Marcus

### Day 1

```text
08:00  Town
12:00  Town → Marcus Farm
20:00  Marcus Farm → Marcus House
22:00  Đến vị trí ngủ → Sleeping
```

### Daily schedule từ Day 2

```text
Marcus House → Marcus Farm → Town → Inside Shop → Town
→ Marcus Farm → Marcus House
```

Case study này cho thấy cách tôi chuyển một lỗi gameplay cụ thể — NPC teleport hoặc dùng sai portal — thành nguyên tắc framework có thể tái sử dụng cho mọi NPC.

## 5. Hệ thống prototype

| Hệ thống | Trạng thái |
|---|---|
| Player movement | Có — top-down 4 hướng, sprint |
| Interaction | Có — NPC, portal, counter, bed, object |
| Farming | Có — plow, plant, water, grow, harvest; cần regression test |
| Time & day cycle | Có; cần runtime validation |
| Energy | Có; cần runtime validation |
| Inventory/hotbar | Đang ổn định hóa |
| Buy/sell | Có; cần playtest thêm |
| Dialogue | Có — JSON, typewriter, choices, relationship |
| NPC schedule | Có nền tảng; đang hoàn thiện |
| NPC route runtime | Có nền tảng; đang hoàn thiện |
| Quest board | Có — static và delivery quest |
| Event/consequence | Đang mở rộng |
| Localization | Đang triển khai bằng catalog JSON tiếng Việt |

## 6. Design rationale

### Vì sao giới hạn Time và Energy?

Để tạo opportunity cost. Người chơi không thể tối ưu farming, trading, socializing và exploration trong cùng một ngày.

### Vì sao NPC có schedule?

Để cộng đồng không chỉ tồn tại khi Player tương tác. Người chơi có thể quan sát pattern: NPC thường ở đâu, vào lúc nào và vì sao điều đó quan trọng.

### Vì sao mystery là lớp tùy chọn?

Người chơi thích farming/life-sim vẫn có thể hoàn thành loop chính. Người chơi tò mò có thể thu thập evidence, hình thành giả thuyết và theo đuổi narrative mystery.

## 7. Bài học iteration

Vấn đề ban đầu là NPC được xử lý như actor spawn theo scene. Điều đó gây teleport, sai cổng và route lặp.

Cách tiếp cận mới:

```text
Persistent instance
→ Runtime schedule state
→ Velocity movement
→ Source portal
→ Destination portal
→ Post-arrival movement
```

Tôi ghi nhận limitation rõ ràng: NPC route, navigation quanh obstacle, save/load giữa route và dynamic market vẫn cần tiếp tục kiểm chứng.

## 8. Kế hoạch phát triển tiếp

1. Viết route regression test cho mọi cặp map.
2. Kiểm tra save/load khi NPC đang ở giữa route.
3. Thay steering đơn giản bằng navigation/pathfinding đáng tin cậy.
4. Tạo công cụ data-driven để designer chỉnh schedule.
5. Hoàn thiện localization UI, quest, dialogue và item metadata.
6. Playtest theo hypothesis và đo xem người chơi có nhận ra pattern NPC hay không.

## 9. Năng lực thể hiện

- Chuyển fantasy thành core loop có thể chơi.
- Viết GDD và phân biệt implemented/planned scope.
- Thiết kế state machine và data-driven content.
- Phân tích opportunity cost của time/energy.
- Thiết kế NPC behavior gắn với world state.
- Iteration từ bug thực tế thành nguyên tắc hệ thống.
- Ghi nhận limitation trung thực.

## 10. Ghi chú ứng tuyển Falcon Game Studio

Trong phiên làm việc này, thông tin công khai về Falcon Game Studio chưa thể xác minh vì công cụ tìm kiếm web trả về lỗi xác thực API. Vì vậy tài liệu không gán cho Falcon sản phẩm, văn hóa hoặc yêu cầu tuyển dụng cụ thể nào chưa được kiểm chứng.

Trước khi gửi hồ sơ, hãy bổ sung:

- tên sản phẩm/genre cụ thể trong JD của Falcon;
- yêu cầu tuyển dụng phù hợp nhất với prototype;
- lý do cá nhân muốn học hỏi tại Falcon;
- link playable build và video playthrough;
- vai trò, thời lượng và phạm vi đóng góp.

## 11. Portfolio checklist

- [ ] Link playable build.
- [ ] Video 2–3 phút cho core loop.
- [ ] Video riêng cho NPC route Marcus.
- [ ] Screenshot map, quest board, inventory/shop.
- [ ] Link repository hoặc code sample nếu phù hợp.
- [ ] Một trang postmortem: vấn đề → giả thuyết → iteration → kết quả.
- [ ] CV ghi rõ vai trò: Game Designer / Systems Designer / Technical Designer cho prototype cá nhân.

---

**Bản này được xây dựng dựa trên `GameDemo_GDD_Portfolio_v1.md`, là bản rút gọn phục vụ hồ sơ ứng tuyển và không trình bày các hệ thống đang phát triển như đã hoàn thiện.**
