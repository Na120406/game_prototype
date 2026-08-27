# Fix lỗi Shop và Item không hiển thị trên itch.io

## Nguyên nhân

Khi export WebGL lên itch.io, Godot không tự động include các resource `.tres` được load động bằng `DirAccess` hoặc `load()` từ đường dẫn string.

Desktop: `DirAccess.open("res://resources/items/definitions/")` hoạt động.  
Web/itch.io: folder listing trả về rỗng hoặc không có file nào.

Kết quả:

- Shop mở nhưng không có item nào để mua.
- Toolbar hiển thị `?` thay vì icon item.
- Inventory không nhận diện được item.

## Đã sửa

File `resources/items/item_database.gd` giờ dùng `preload()` constant để bắt buộc Godot đưa tất cả item vào Web export:

```gdscript
const ITEM_RESOURCES: Array[ItemData] = [
	preload("res://resources/items/definitions/apple.tres"),
	preload("res://resources/items/definitions/health_potion.tres"),
	preload("res://resources/items/definitions/lore_fragment.tres"),
	# ... 22 items total
]
```

Trong `_load_all_items()`:

1. Load từ `ITEM_RESOURCES` constant trước (chắc chắn có trong Web build).
2. Scan lại `DirAccess` để tự động nhận item mới khi chạy Editor (không bắt buộc).
3. Dùng guard `not _db.has(item.item_id)` để tránh duplicate.

## Kết quả

- Shop bây giờ sẽ hiển thị đầy đủ 9 item có `buy_price > 0`.
- Toolbar và Inventory nhận diện được item icon và màu sắc.
- Web export có đầy đủ 22 item resources.

## Export tiếp theo

Khi export WebGL:

1. Đảm bảo "Export Mode" là **Export all resources in the project**.
2. Nếu dùng "Export selected resources," hãy thêm `resources/items/definitions/*.tres` vào list.
3. Test bằng cách mở build WebGL local trước khi upload lên itch.io.

## Checklist trước khi upload lên itch.io

- [ ] Export WebGL từ Godot.
- [ ] Mở `index.html` local trong trình duyệt và test shop.
- [ ] Xác nhận item hiển thị đúng trong shop tab "MUA".
- [ ] Xác nhận toolbar hiển thị icon đúng khi cầm item.
- [ ] Compress thành `.zip` (đảm bảo `index.html` nằm ở root của zip).
- [ ] Upload lên itch.io và chọn "This file will be played in the browser."
- [ ] Chọn platform HTML5 và viewport phù hợp.
- [ ] Test bằng link preview trước khi public.
