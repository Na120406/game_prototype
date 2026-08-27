# itch.io Page Layout & Asset Checklist — GameDemo

## 1. Bố cục đề xuất

### Khu vực đầu trang

**Title:**

> GameDemo — A Day in a Living Community

**Tagline:**

> Every day is a choice. Every choice changes tomorrow.

**Cover image:**

- Tỷ lệ đề xuất: 3:1 hoặc 4:1.
- Kích thước: 1500 × 500 px hoặc 1600 × 600 px.
- Nội dung: player ở foreground, farm và NPC ở background.
- Logo đặt ở vùng trung tâm hoặc bên trái.
- Không đặt text quá sát mép ảnh.
- Tránh đưa quá nhiều UI nhỏ vào cover.

### Khu vực description

Thứ tự nên dùng:

1. Một câu hỏi/hook ngắn.
2. Mô tả game trong 2–3 câu.
3. GIF hoặc video gameplay ngắn.
4. Các hoạt động chính.
5. Design focus.
6. Prototype status.
7. Hướng dẫn chơi.
8. Feedback/contact.

### Khu vực screenshots

Nên có 4–6 ảnh:

1. Farming: plow/plant/water.
2. Quest Board: objective, deadline, reward.
3. Marcus ở một khu vực trong schedule.
4. Town/shop và economy.
5. Inventory/Toolbar.
6. Sleep/day transition hoặc world-state change.

Mỗi screenshot nên có caption một câu, ví dụ:

> Quest Board connects crop production with social rewards and short-term planning.

---

## 2. Thumbnail / cover concept

### Concept A — Recommended: “One Day, Many Choices”

**Bố cục:**

- Bên trái: player đứng cạnh farm plot.
- Chính giữa: đường đi hướng về town.
- Bên phải: Marcus gần town hoặc shop.
- Background: màu nâu tối của game, thêm ánh sáng vàng quanh player.
- Góc trên: logo GameDemo.
- Dòng phụ: `Farming • NPC Schedules • Daily Decisions`.

**Thông điệp:**

Người xem nhìn vào là hiểu game có farming, NPC và lựa chọn theo ngày.

### Concept B — “The Living Route”

- Marcus ở giữa ảnh.
- Một đường route nối farm → town → shop.
- Player đứng lệch sang một bên.
- Dùng mũi tên hoặc line mảnh để minh họa route.
- Phù hợp nếu muốn nhấn mạnh Systems/Technical Design.

### Concept C — “Quiet Mystery”

- Player ở farm lúc chiều tối.
- Một crop hoặc item bất thường ở foreground.
- Một vùng tối/mờ ở background.
- Không dùng hình ảnh horror quá mạnh.
- Phù hợp nếu muốn nhấn mạnh mystery layer.

**Khuyến nghị:** Dùng Concept A làm thumbnail chính. Dùng Concept B cho screenshot hoặc portfolio case study. Không nên dùng Concept C làm ảnh chính vì có thể khiến người xem hiểu nhầm đây là horror game thay vì farming/life-sim prototype.

---

## 3. Text nên đặt trên thumbnail

### Bản tối giản

```text
GameDemo
A Day in a Living Community
```

### Bản có thông tin genre

```text
GameDemo
Farming • NPC Schedules • Daily Decisions
```

Không nên đặt toàn bộ câu mô tả dài lên thumbnail vì chữ sẽ khó đọc ở kích thước nhỏ.

---

## 4. itch.io settings checklist

### Upload

- [ ] Upload Web export dưới dạng `.zip`.
- [ ] Chọn **This file will be played in the browser**.
- [ ] Chọn platform **HTML5**.
- [ ] Kiểm tra file `.html` nằm ở root của zip.
- [ ] Không nén thêm một thư mục cha bên ngoài nếu itch.io không nhận file HTML.
- [ ] Test bằng link preview trước khi public.

### Embed

- [ ] Dùng kích thước khoảng 960 × 540 hoặc 1280 × 720.
- [ ] Bật fullscreen nếu build hỗ trợ.
- [ ] Nếu game dùng viewport pixel-art 320 × 180, dùng scaling integer.
- [ ] Đảm bảo UI không bị cắt ở browser nhỏ.

### Page presentation

- [ ] Thumbnail dễ đọc ở kích thước nhỏ.
- [ ] Có screenshot đầu tiên thể hiện gameplay, không chỉ là menu.
- [ ] Mô tả ngắn đặt ở đầu page.
- [ ] Controls nằm gần khu vực playable embed.
- [ ] Ghi rõ đây là graybox prototype.
- [ ] Ghi rõ engine và vai trò cá nhân.
- [ ] Thêm link portfolio/GitHub nếu muốn.
- [ ] Không đặt checklist nội bộ hoặc known bugs dài trên public page.

### Recruiter experience

- [ ] Người chơi hiểu cách bắt đầu trong vòng 30 giây.
- [ ] Controls có thể nhìn thấy mà không cần đọc GDD.
- [ ] Không cần tải thêm font hoặc plugin.
- [ ] Không dùng emoji trong UI WebGL.
- [ ] Có video dự phòng nếu Web build gặp lỗi.
- [ ] Kiểm tra bằng Chrome/Edge ở chế độ ẩn danh.

---

## 5. Recommended public page order

```text
Title + Cover
↓
One-line hook
↓
Playable embed
↓
Controls
↓
Quick Start
↓
Core design focus
↓
Screenshots / GIF
↓
Prototype status
↓
Credits + Portfolio link
```

## 6. Recruiter-friendly quick start

Đặt ngay bên dưới playable embed:

> **Quick start:** Press `E` to interact, walk with `WASD`, choose a slot with `1–5`, and use the selected tool on the farm. Try accepting a delivery quest before sleeping to see how the daily loop connects farming, economy, and NPC interaction.
