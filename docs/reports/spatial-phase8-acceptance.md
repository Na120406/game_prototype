# Báo cáo nghiệm thu Spatial Phase 8

Ngày kiểm tra: 2026-09-04  
Trạng thái: **Cổng tự động đạt; chờ user playtest trực quan**

## Phạm vi hoàn thành

- Sửa lifecycle Hotbar khi scene cũ đã rời `SceneTree`.
- Chuẩn hóa Axe ownership cho cả inventory và toolbar.
- Giữ Forest/Farm blocker đúng persistence, kể cả migration save thử nghiệm cũ.
- Scope blocker theo active scene để background NPC map không chặn Farm của player.
- Watering chỉ consume sau action thành công; WaterSource cập nhật khi item đổi ở inventory hoặc toolbar.
- Serialize/deserialize farm trực tiếp qua `FarmTickManager`, không phụ thuộc scene hiện tại.
- Kiểm tra traversal cost chỉ áp dụng một lần cho mỗi portal instance.
- Khóa portal shortcut bằng canonical flag, nên không thể lách hình học của blocker để đi tắt.
- Áp traversal time qua `TimeManager`, giữ nguyên ngày và năng lượng khi đi qua mốc nửa đêm.
- Cho travel đi qua cùng clock-boundary pipeline: 01:00 kích hoạt AFK, 06:00 kích hoạt ngày mới/farm tick.
- Thêm harness được version-control trong `tests/`.

## Ma trận acceptance

| Tiêu chí | Bằng chứng tự động | Trạng thái |
|---|---|---|
| Forest có long route và shortcut | `spatial_phase8_acceptance` kiểm tra portal + cost ordering | Đạt tự động |
| Shortcut không clear nếu chỉ giả equip Axe | Ownership regression | Đạt tự động |
| Axe mở bán theo ngày config | Day gate regression | Đạt tự động |
| Forest blocker giữ trạng thái sau reload | Persistence + migration regression | Đạt tự động |
| Farm blocker chặn trước clear | Farm full-chain regression | Đạt tự động |
| Ô mở rộng plow → water → plant → mature → harvest | Farm full-chain regression | Đạt tự động |
| Watering consume đúng một lần | Capacity regression | Đạt tự động |
| WaterSource nhận bình trong toolbar và refill max | Toolbar/refill regression | Đạt tự động |
| Gathering không mất khi túi đầy | Full-inventory regression | Đạt tự động |
| Gathering thêm item và dùng sell flow hiện tại | Inventory/ItemDB regression | Đạt tự động |
| Save ngoài Farm giữ farm cells và spatial flags | CatchUp round-trip regression | Đạt tự động |
| Portal bị gọi lặp không cộng cost hai lần | `portal_cost_once_regression` | Đạt tự động |
| Shortcut portal không hoạt động trước khi clear blocker | `forest_shortcut_gate_regression` | Đạt tự động |
| Đi từ 23:00 qua nửa đêm không đổi ngày/hồi năng lượng | `portal_cost_once_regression` | Đạt tự động |
| Travel qua 01:00/06:00 không bỏ sót AFK/farm tick và giữ đủ phần dư thời gian | `portal_cost_once_regression` | Đạt tự động |
| Hotbar không phát `data.tree is null` khi đổi scene | Mountain ↔ Town runtime harness | Đạt tự động |
| Cảm nhận route, vị trí blocker/source/gathering và UX mua Axe | Cần chơi trực tiếp | Chờ user kiểm tra |

## Kết quả lệnh kiểm tra

- Godot import: exit `0`, không parse/resource error.
- Boot headless 3 lần: exit `0`, không script/parse error.
- Smoke test: `0` critical failure.
- Spatial Phase 8 acceptance: toàn bộ assertion pass.
- Portal cost once + midnight/AFK/dawn semantics: pass.
- Forest shortcut portal gate: pass.
- Farm expansion full chain: pass.
- Forest route cost: pass.
- Mountain ↔ Town transition: pass, không còn lỗi lifecycle Hotbar.

Godot trên máy kiểm tra vẫn in cảnh báo môi trường về Windows root certificate.
Một số harness thoát ngay sau assertion còn in `ObjectDB instances leaked at exit`;
ba lần boot game chính không có cảnh báo leak này, nên hiện được phân loại là
test-runner cleanup gap, không phải runtime leak đã tái hiện trong game chính.

## Phần user cần kiểm tra trực quan

1. Day 1–2: Farm → Forest → Town bằng long route.
2. Shortcut hiển thị rõ là bị chặn trước khi có Axe.
3. Day 3: Axe xuất hiện trong shop, mua trừ đúng vàng.
4. Equip Axe và clear Forest/Farm blocker; reload vẫn giữ trạng thái.
5. Dùng hết bình, tưới bị chặn; giếng refill đúng UX.
6. Gathering nằm trên long route và đủ hấp dẫn để cân nhắc đường đi.
7. Hotbar/HUD vẫn đúng layout sau nhiều lần chuyển scene.

Không commit hoặc push trong phase này.
