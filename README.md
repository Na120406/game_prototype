# Old Town — GameDemo

Prototype game 2D góc nhìn từ trên xuống về canh tác, đời sống thị trấn và một lớp
bí ẩn nhẹ. Người chơi quản lý một ngày có giới hạn thời gian/năng lượng, chăm sóc
nông trại, đi qua các khu vực, gặp NPC và mở dần các lựa chọn khám phá.

> **Trạng thái:** Prototype v1.0.0 · chưa phải bản phát hành thương mại<br>
> **Engine:** Godot 4.5 · Forward Plus<br>
> **Ngôn ngữ:** GDScript  
> **Scene khởi động:** `res://scenes/maps/inside_house_map.tscn`

![Character prototype](assets/characters/characters_prototype.png)

## Chạy prototype

### Yêu cầu

- Godot 4.5.x (hoặc bản Godot 4 tương thích).
- Git nếu muốn clone và theo dõi lịch sử thay đổi.
- Không có dependency ngoài Godot.

### Khởi động

1. Clone repository hoặc tải source về máy.
2. Mở Godot Project Manager → **Import** → chọn `project.godot`.
3. Mở project bằng Godot 4.5.
4. Nhấn **F6** để chạy scene đang mở hoặc **F5** để chạy scene chính.

Scene chính đã được cấu hình sẵn; không cần chạy script build hay copy asset thủ công.

## Điều khiển

| Hành động | Phím mặc định |
|---|---|
| Di chuyển | `W` `A` `S` `D` |
| Tương tác, nhặt, dùng công cụ | `E` |
| Chạy nước rút | `X` |
| Mở/đóng inventory | `Tab` |
| Chọn ô hotbar | `1`–`5` |
| Dùng vật phẩm trên ô đất | Chuột trái/phải tùy ngữ cảnh |

Input Map có thể xem và chỉnh trong `project.godot`.

## Vòng lặp chơi hiện có

- Bắt đầu ngày lúc 06:00 với 20 năng lượng; ngủ để chuyển sang ngày mới.
- Cuốc, gieo hạt, tưới, chờ cây lớn và thu hoạch trên farm.
- Bình tưới có sức chứa 5; lấy nước ở WaterSource hồi đầy và tiêu hao 3 năng lượng.
- Khai thác TreeBlocker bằng rìu: cần 3 lần chặt, mỗi lần tốn 1 năng lượng.
- Rìu mở bán từ ngày 3 với giá 120 vàng.
- Táo tại các điểm gathering có xác suất xuất hiện 25% mỗi điểm, reset theo ngày.
- Inventory 21 ô và hotbar 5 ô; tooltip dùng chung độ trễ 0,3 giây.
- Portal town/forest có tuyến dài và đường tắt; đường tắt bị chặn cho đến khi phá khúc gỗ.
- Marcus có lịch theo ngày, đi theo road ColorRect khi route có đường vẽ; Voss mở thoại hàng mới từ ngày 3.

## Bản đồ và scene chính

| Khu vực | Scene | Vai trò |
|---|---|---|
| Nhà người chơi | `scenes/maps/inside_house_map.tscn` | Scene khởi động, ngủ và vào ngày mới |
| Farm | `scenes/maps/farm_map.tscn` | Trồng trọt, hàng rào, WaterSource |
| Forest | `scenes/maps/forest_map.tscn` | Gathering táo, đường dài/đường tắt, TreeBlocker |
| Town | `scenes/maps/town_map.tscn` | Shop, NPC và hai cổng đi forest |
| Shop | `scenes/maps/inside_shop_map.tscn` | Mua/bán vật phẩm, Voss |
| Marcus farm/house | `scenes/maps/marcus_farm_map.tscn`, `marcus_house_map.tscn` | Route và điểm nghỉ của Marcus |

## Cấu trúc repository

```text
game-demo/
├── project.godot              # Cấu hình project, input, autoload, scene chính
├── scenes/                    # Scene Godot: map, NPC, UI, world object
├── scripts/
│   ├── autoload/              # GameState, time, scene, NPC, dialogue, save...
│   ├── player/                # Điều khiển player và tương tác
│   ├── npc/                   # NPC, schedule, route/pathfinding
│   ├── world/                 # Farm, portal, tree blocker, gathering...
│   ├── ui/                    # HUD, hotbar, inventory, shop, dialogue
│   ├── data/                  # Resource route/waypoint/portal
│   └── utils/                 # Tiện ích và save manager
├── resources/
│   ├── config/                # JSON cân bằng game, text, NPC
│   ├── dialogue/              # Hội thoại theo ngày/trạng thái
│   ├── items/                # ItemData và định nghĩa item (.tres)
│   └── quest/                 # Dữ liệu nhiệm vụ
├── assets/characters/         # Chỉ asset runtime PNG của player/NPC
├── tilesets/                  # Chỉ texture tileset còn được runtime tham chiếu
├── docs/ARCHITECTURE.md       # Bản đồ kiến trúc để bảo trì project
└── README.md
```

`docs/ARCHITECTURE.md` là bản đồ mã nguồn chi tiết và phải được đọc trước khi sửa
logic. Tài liệu thiết kế, regression tests, công cụ build, map thử nghiệm, tileset
nguồn và metadata editor nằm ngoài project runtime tại thư mục sibling
`D:\Project_Game\game-demo-elements`; chúng không được đưa vào bản export.

## Kiểm thử nhanh

Kiểm tra import project:

```powershell
& "E:\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64.exe" --headless --editor --path . --quit
```

Regression scenes và harness phát triển được lưu trong
`D:\Project_Game\game-demo-elements\tests`. Chúng không thuộc project runtime; khi
cần chạy test, dùng một working copy phát triển có gắn lại thư mục này trước khi mở
Godot. Giữ output trong thư mục tạm/local; không commit log hoặc screenshot debug vào
repository runtime.

## Dữ liệu và kiến trúc

- Trạng thái trung tâm: `scripts/autoload/game_state.gd`.
- Cấu hình gameplay: `resources/config/game_config.json`.
- Lịch/NPC: `resources/config/npc_config.json`, `scripts/autoload/npc_schedules.gd`.
- Chuyển scene và portal: `scripts/autoload/scene_manager.gd`.
- Farming: `scripts/autoload/farm_tick_manager.gd` và `scripts/world/farm/`.
- Dialogue/UI: `scripts/autoload/dialogue_manager.gd`, `scripts/ui/`.
- Lưu game: `scripts/utils/save_manager.gd`.

Các hệ thống giao tiếp chủ yếu qua autoload singleton và signal; dữ liệu cân bằng được
tách khỏi scene để dễ kiểm thử và chỉnh sửa.

## Chính sách asset và repository

Asset nhân vật runtime chỉ giữ định dạng PNG: `player.png`, `marcus.png`, `vos.png` và
ảnh preview `characters_prototype.png`. File nguồn thiết kế Illustrator/Photoshop
(`.ai`, `.psd`) không thuộc build prototype và không được giữ trong repository.
Log, file tạm, cache `.godot/`, export và công cụ local cũng không được commit.

## Tài liệu phát triển

- [Bản đồ kiến trúc](docs/ARCHITECTURE.md)
- [Thư mục tài liệu/test/tool bên ngoài](../game-demo-elements/)

## Phạm vi prototype

Mục tiêu của bản này là chứng minh vòng lặp chơi, tiến trình không gian, lịch NPC và
feedback UI. Âm thanh hoàn chỉnh, save cloud, localization đa ngôn ngữ, content cuối
game và art production chưa nằm trong phạm vi v1.0.0.

Khi phát triển tiếp: tạo branch riêng, thay đổi tối thiểu theo feature, chạy regression
liên quan, xem diff trước khi commit và ghi rõ thay đổi trong tài liệu.
