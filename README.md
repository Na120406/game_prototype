# Old Town

**Old Town** là một prototype game 2D góc nhìn từ trên xuống, kết hợp vòng lặp
canh tác, khám phá và mô phỏng đời sống trong một thị trấn nhỏ. Dự án được xây dựng
bằng **Godot 4.5** và **GDScript**.

Người chơi bắt đầu trong căn nhà, chăm sóc nông trại, quản lý năng lượng, tương tác
với NPC, hoàn thành nhiệm vụ và khám phá các sự kiện thay đổi theo thời gian, thời tiết
và lựa chọn của người chơi.

> **Trạng thái:** Prototype đang phát triển  
> **Engine:** Godot 4.5 (Forward Plus)  
> **Ngôn ngữ:** GDScript  
> **Scene khởi động:** `res://scenes/maps/inside_house_map.tscn`

## Chạy dự án

### Yêu cầu

- Godot **4.5** hoặc mới hơn trong nhánh Godot 4
- Git (khuyến nghị khi làm việc theo nhóm)

### Khởi động

1. Clone hoặc tải repository về máy.
2. Mở Godot Project Manager.
3. Chọn **Import** và mở file `project.godot`.
4. Mở project bằng Godot 4.5.
5. Nhấn **F6** để chạy scene hiện tại hoặc **F5** để chạy game từ scene chính.

Không cần cài thêm dependency bên ngoài. Các thiết lập input, autoload và scene chính
đã được cấu hình trong `project.godot`.

## Điều khiển

| Hành động | Phím mặc định |
|---|---|
| Di chuyển lên / xuống / trái / phải | `W` / `S` / `A` / `D` |
| Tương tác | `E` |
| Mở / đóng túi đồ | `Tab` |
| Chọn ô công cụ trên thanh nhanh | `1`–`5` |
| Tương tác bằng chuột | Chuột trái / phải tùy đối tượng |

Các phím có thể được điều chỉnh trong Input Map của Godot hoặc trong mục `[input]`
của `project.godot`.

## Cấu trúc dự án

```text
game-demo/
├── scenes/                 # Scene Godot: bản đồ, NPC, UI, vật thể
├── scripts/
│   ├── autoload/           # Hệ thống toàn cục trong project.godot
│   ├── player/             # Điều khiển người chơi
│   ├── npc/                # NPC, lịch trình và tương tác
│   ├── world/              # Nông trại, chuyển scene và môi trường
│   ├── ui/                 # HUD, inventory, dialogue và input UI
│   ├── tools/              # Công cụ phát triển
│   └── utils/              # Lưu game và tiện ích
├── resources/
│   ├── config/             # Cấu hình gameplay và dữ liệu NPC
│   ├── dialogue/           # Dữ liệu hội thoại
│   ├── items/              # Item database và ItemData
│   ├── quest/              # Dữ liệu nhiệm vụ
│   └── tilesets/           # Tài nguyên tileset
├── tilesets/               # Texture tileset và asset môi trường
├── design/                 # GDD và tài liệu thiết kế
├── docs/                   # Template và tài liệu NPC
├── project.godot           # Cấu hình project Godot
└── README.md               # Tài liệu này
```

## Các hệ thống chính

- **Farming:** ô đất, gieo trồng, tưới nước, sinh trưởng và thu hoạch.
- **World simulation:** ngày/giờ, thời tiết, mùa và cập nhật thế giới.
- **NPC & family:** nhân vật, lịch sinh hoạt, gia đình và tiến trình.
- **Items & tools:** database vật phẩm, inventory và công cụ.
- **Quests & events:** nhiệm vụ, chuỗi sự kiện phân nhánh và hệ quả.
- **Dialogue & audio:** hội thoại theo trạng thái và quản lý âm thanh.
- **Save/load:** lưu tiến trình bằng `SaveManager`.

Các hệ thống dùng autoload singleton và signal của Godot. Danh sách cấu hình đầy đủ
nằm trong phần `[autoload]` của `project.godot`.

## Tài liệu dự án

- `design/gdd/` — Game Design Document và định hướng thiết kế
- `docs/characters/` — Thiết kế nhân vật/NPC
- `docs/templates/` — Template viết tài liệu
- `TODO.md` — Danh sách công việc còn lại (nếu có)

## Quy tắc Git

Không commit các file cache, file import và công cụ local. `.gitignore` đã loại trừ
`.godot/`, `*.import`, `tools/`, file build/export, log và cấu hình IDE cá nhân.

Không xóa asset được scene hoặc script tham chiếu. Asset mới cần đặt đúng thư mục và
kiểm tra project chạy được bằng F5 trước khi commit.

## Quy trình phát triển

1. Tạo branch cho thay đổi mới.
2. Chỉnh sửa scene, script hoặc resource liên quan.
3. Chạy F5 trong Godot để kiểm tra.
4. Kiểm tra Output/Debugger.
5. Chỉ commit file nguồn và asset cần thiết cho game.

## Định hướng thiết kế

- **Playable > Beautiful** — ưu tiên trải nghiệm chơi được.
- **Finished > Perfect** — hoàn thiện vòng lặp cốt lõi trước.
- **Simple > Scalable** — giữ hệ thống rõ ràng, dễ bảo trì.

Nông trại và thế giới tiếp tục vận hành theo thời gian. Các lớp bí ẩn và sự kiện là
chiều sâu bổ sung, không cản trở vòng lặp canh tác cơ bản.
