# Old Town — GameDemo

Prototype game 2D góc nhìn từ trên xuống, kết hợp canh tác, quản lý thời gian và
năng lượng, đời sống thị trấn cùng một lớp bí ẩn nhẹ. Mục tiêu hiện tại là kiểm
chứng vòng lặp chơi, lịch NPC, tiến trình mở khóa khu vực và phản hồi UI.

> **Trạng thái:** Prototype v1.0.0, chưa phải bản phát hành thương mại<br>
> **Engine đã kiểm thử:** Godot 4.5.1 · Forward Plus<br>
> **Ngôn ngữ:** GDScript<br>
> **Scene khởi động:** `res://scenes/maps/inside_house_map.tscn`

![Ba nhân vật prototype: Player, Marcus và Vos](assets/characters/characters_prototype.png)

## Chạy project

### Yêu cầu

- Godot 4.5.1 stable; các bản Godot 4.5.x tương thích cũng có thể sử dụng.
- Git nếu clone repository thay vì tải source archive.
- Không có dependency runtime ngoài Godot.

### Khởi động trong editor

1. Clone repository hoặc tải source về máy.
2. Trong Godot Project Manager, chọn **Import** rồi mở `project.godot`.
3. Nhấn **F5** để chạy game từ scene chính. **F6** chỉ chạy scene đang mở.

Project dùng viewport 320×180, scale nguyên và phóng lên cửa sổ 1280×720. Scene
chính, autoload và Input Map đã được cấu hình sẵn; không cần chạy bước build asset.

## Điều khiển

| Hành động | Input mặc định |
|---|---|
| Di chuyển | `W` `A` `S` `D` |
| Tương tác với NPC, cổng, giường, quầy, vật phẩm | `E` |
| Chạy nước rút | `X` |
| Mở/đóng inventory | `Tab` |
| Chọn ô hotbar | `1`–`5` |
| Xem trạng thái/thu hoạch ô đất; thao tác UI | Chuột trái |
| Dùng công cụ, hạt giống hoặc vật phẩm tiêu thụ đang chọn | Chuột phải |
| Bật/tắt Capture Mode khi chạy từ editor | `Ctrl` + `F9` |

Chuột trái trên ô cây trưởng thành sẽ thu hoạch; trên cây đang lớn sẽ hiển thị
trạng thái. Chuột phải dùng cuốc, bình tưới, hạt giống hoặc vật phẩm tiêu thụ theo
ngữ cảnh. Tương tác ngoài tầm với không thực hiện hành động.

## Vòng lặp và cân bằng hiện tại

- Mỗi ngày bắt đầu lúc 06:00 và kết thúc do quá giờ lúc 01:00 hôm sau. Toàn bộ
  khoảng chơi 19 giờ trong game kéo dài khoảng 4 phút 40 giây thực.
- Người chơi bắt đầu với 20 năng lượng và 200 vàng.
- Ngủ trước 23:30 hồi đầy năng lượng. Ngủ từ 23:30 trở đi chỉ hồi tối thiểu tới
  75%, đồng thời không hạ năng lượng nếu đang cao hơn mức đó. Không ngủ đến 01:00
  hoặc cạn năng lượng sẽ kích hoạt penalty.
- Mọi cách sang ngày mới đều dùng hiệu ứng nhắm mắt 2 giây: đóng 0,75 giây, giữ
  màn hình đen 0,5 giây và mở 0,75 giây; input bị khóa trong suốt hiệu ứng.
- Bình tưới chứa tối đa 5 lượt. Khi đang chọn bình trên hotbar, nhấn `E` cạnh nguồn
  nước để hồi đầy và tốn 3 năng lượng. Nếu còn không quá 3 năng lượng, thao tác bị
  từ chối để tránh kích hoạt penalty sai.
- Khúc gỗ chắn đường cần rìu và 3 lần chặt; mỗi lần chặt tốn 1 năng lượng. Rìu được
  bán từ ngày 3 với giá 120 vàng.
- Ba điểm táo trong Forest có xác suất xuất hiện độc lập 25% mỗi ngày, không cộng
  dồn. Táo hồi 3 năng lượng; thuốc hồi phục hồi 15 năng lượng và có giá mua 20 vàng.
- Inventory có 21 ô, hotbar có 5 ô; mức nước còn lại hiển thị trên cả hai giao diện.

### Cây trồng

| Cây | Giá hạt | Giá bán | Ngày lớn | Nhu cầu nước | Sản lượng/hạt |
|---|---:|---:|---:|---:|---:|
| Củ cải | 10g | 20g | 4 | 2 | 1 |
| Lúa mì | 15g | 45g | 6 | 2 | 1 |
| Ngô | 20g | 75g | 8 | 1 | 1 |
| Cà chua | 12g | 30g | 5 | 1 | 1 |
| Khoai tây | 18g | 30g | 7 | 3 | 2 |

Giá trị trên được đọc từ `resources/config/crop_profiles.json`; đây là nguồn dữ
liệu chuẩn cho tăng trưởng, giá và sản lượng cây trồng.

## NPC, nhiệm vụ và tiến trình

- Marcus có lịch theo thời gian và scene. NPC bám theo đường `ColorRect` ở map có
  tuyến đường định nghĩa, đồng thời di chuyển trực tiếp ở map không có đường vẽ.
- Trong lịch ngày 1, Marcus rời Shop lúc 12:00, xuất hiện tại cửa rồi đi tới điểm
  chờ; lúc 14:30 bắt đầu quay về Marcus Farm và tiếp tục lịch buổi tối.
- Player và NPC không đẩy hoặc kéo nhau. Nếu một bên chặn đường bên kia liên tục
  khoảng 2 giây, đối tượng đang di chuyển có thể xuyên qua để tránh kẹt lịch trình.
- Quest trên bảng bắt đầu từ ngày 2, có xác suất cơ sở 50% và tăng 10 điểm phần trăm
  sau mỗi ngày không xuất hiện. Lời nhắc của Marcus chỉ phát một lần đầu tiên khi
  bảng có quest; hội thoại giao và hoàn thành nhiệm vụ vẫn hoạt động bình thường.
- Từ ngày 3, lần đầu nói chuyện với Vos hoặc mở Shop sẽ phát hội thoại thông báo có
  hàng mới. Sau khi hội thoại kết thúc, Shop hoạt động như thường lệ.
- Khi chuyển ngày sớm do ngủ hoặc cạn năng lượng, lịch còn lại của NPC được mô phỏng
  nhanh trong nền trước khi họ về trạng thái đầu ngày tiếp theo.

## Bản đồ

| Khu vực | Scene | Vai trò |
|---|---|---|
| Nhà người chơi | `scenes/maps/inside_house_map.tscn` | Scene khởi động, giường và chuyển ngày |
| Farm | `scenes/maps/farm_map.tscn` | Trồng trọt, nguồn nước và hàng rào |
| Forest | `scenes/maps/forest_map.tscn` | Táo ngẫu nhiên, tuyến dài và đường tắt bị chặn |
| Town | `scenes/maps/town_map.tscn` | Trung tâm kết nối, Shop và lịch NPC |
| Shop | `scenes/maps/inside_shop_map.tscn` | Mua/bán vật phẩm và Vos |
| Mountain | `scenes/maps/mountain_map.tscn` | Khu vực khám phá từ Town |
| Marcus Farm | `scenes/maps/marcus_farm_map.tscn` | Khu làm việc và tuyến về nhà của Marcus |
| Nhà Marcus | `scenes/maps/marcus_house_map.tscn` | Điểm ngủ trong lịch Marcus |

Portal không tự cộng thời gian di chuyển. Đường tắt Forest chỉ mở sau khi khúc gỗ
được phá; khi còn bị chắn, cổng liên quan hiển thị phản hồi thay vì chuyển scene.

## Capture Mode dành cho debug

`Ctrl` + `F9` chỉ hoạt động khi chạy game trực tiếp từ Godot Editor. Chế độ này bị
vô hiệu trong mọi bản export, kể cả debug export.

Khi bật, sprite Player, HUD, prompt và con trỏ được ẩn; đồng hồ thời gian thực vẫn
hiển thị ở góc trên bên phải. Capture Mode không thay đổi gameplay state, collision,
tương tác, mô phỏng NPC, clock hay camera.

## Save và export

- Game có 3 save slot cục bộ, lưu dạng JSON tại `user://save_game_<slot>.dat`.
- Save bao gồm trạng thái game, inventory, farm, quest, world flag, NPC và scene.
- Repository có preset export **Web** trong `export_presets.cfg`; output mặc định là
  `../Old_Town_WebGL/index.html`.
- File nguồn Illustrator/Photoshop, cache import, log, screenshot debug và output
  export không thuộc runtime repository. Asset nhân vật chạy game chỉ dùng PNG.

## Cấu trúc repository

```text
game-demo/
├── project.godot                 # Project, Input Map, autoload và scene chính
├── export_presets.cfg            # Preset Web
├── assets/                       # Asset runtime
├── scenes/                       # Map, NPC, UI và world object
├── scripts/
│   ├── autoload/                 # State, time, scene, NPC, dialogue, quest...
│   ├── data/                     # Resource route, waypoint và portal
│   ├── npc/                      # Hành vi, lịch và di chuyển NPC
│   ├── player/                   # Điều khiển và tương tác Player
│   ├── tests/                    # Regression contract nằm trong runtime source
│   ├── ui/                       # HUD, inventory, hotbar, shop, dialogue
│   ├── utils/                    # Save manager và tiện ích
│   └── world/                    # Farm, portal, gathering, blocker...
├── resources/
│   ├── config/                   # Cấu hình cân bằng, NPC và UI text
│   ├── dialogue/                 # Hội thoại theo ngày/trạng thái
│   ├── items/                    # ItemData và định nghĩa item
│   ├── localization/             # Chuỗi hiển thị tiếng Việt
│   └── quest/                    # Dữ liệu nhiệm vụ
├── tilesets/                     # Texture tileset được runtime tham chiếu
├── docs/ARCHITECTURE.md          # Bản đồ kiến trúc và nguồn dữ liệu chuẩn
└── README.md
```

Tài liệu thiết kế dài, test harness phát triển, source art và công cụ build được giữ
ở thư mục sibling local `game-demo-elements` để không làm nặng project hoặc bản
export. Chúng không phải dependency để chạy game sau khi clone repository này.

## Kiểm tra project

Kiểm tra project có import và parse được trong Godot:

```powershell
godot --headless --editor --path . --quit
```

Nếu executable không có trong `PATH`, thay `godot` bằng đường dẫn tới
`Godot_v4.5.1-stable_win64_console.exe`. Regression harness đầy đủ nằm ngoài runtime
repository tại `../game-demo-elements/tests`; script contract dùng chung vẫn nằm ở
`scripts/tests/runtime_data_consolidation_regression.gd`.

Trước khi sửa logic, đọc [bản đồ kiến trúc](docs/ARCHITECTURE.md). Các nguồn dữ liệu
quan trọng nhất gồm:

- `resources/config/game_config.json`: thời gian, năng lượng, inventory và mở khóa.
- `resources/config/crop_profiles.json`: cây trồng, giá, nước và sản lượng.
- `resources/config/npc_config.json` và `npc_schedule_config.json`: NPC và lịch.
- `scripts/autoload/game_state.gd`: trạng thái runtime trung tâm.
- `scripts/autoload/scene_manager.gd`: chuyển scene và điểm spawn.
- `scripts/autoload/npc_manager.gd`: mô phỏng, chuyển map và catch-up NPC.

## Phạm vi prototype

Bản prototype tập trung vào farming, economy, lịch NPC, quest, chuyển map, save và
feedback UI. Âm thanh hoàn chỉnh, save cloud, localization đa ngôn ngữ, nội dung
cuối game và art production chưa nằm trong phạm vi v1.0.0.
