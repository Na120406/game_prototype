# Quy Tắc Documentation Tiếng Việt

> **Rule chung cho tất cả agents** trong project này. Áp dụng bắt buộc cho mọi code và tài liệu.

## Mục Đích

Đảm bảo 100% comments trong code và file tài liệu Markdown (`.md`) được viết bằng **tiếng Việt** để:
- Toàn bộ team (kể cả người mới) hiểu được logic code
- Tăng tốc độ onboarding thành viên mới
- Giảm phụ thuộc vào tiếng Anh khi đọc code
- Duy trì tính nhất quán trong toàn project

## Quy Tắc Chung

### 1. Comments trong Code

**BẮT BUỘC**: Mọi comment giải thích logic, thuật toán, hoặc ý định phải viết bằng tiếng Việt.

#### GDScript
```gdscript
# Tính toán sát thương dựa trên giáp và cấp độ kẻ địch
func tinh_sat_thuong(sat_thuong_goc: int, giap: int, cap_do: int) -> int:
    # Trừ giáp trước, sau đó áp dụng hệ số cấp độ
    var sat_thuong_thuc = max(sat_thuong_goc - giap, 0)
    var he_so_cap_do = 1.0 + (cap_do - 1) * 0.1  # Mỗi cấp tăng 10% sát thương
    return int(sat_thuong_thuc * he_so_cap_do)

## Kiểm tra xem người chơi còn đủ máu để tiếp tục chiến đấu
func con_du_mau() -> bool:
    return _mau_hien_tai > 0  # Ngưỡng tối thiểu là 1 HP
```

#### Python
```python
# Tính khoảng cách giữa hai điểm trên bản đồ
def tinh_khoang_cach(diem_a, diem_b):
    """Tính khoảng cách Euclidean giữa hai điểm 2D."""
    # Sử dụng công thức Pythagore
    return math.sqrt((diem_b.x - diem_a.x) ** 2 + (diem_b.y - diem_a.y) ** 2)

# Kiểm tra va chạm với vật thể tĩnh
def kiem_tra_va_cham(vi_tri, kich_thuoc, vat_the):
    """Trả về True nếu có va chạm xảy ra."""
    pass
```

#### TypeScript/JavaScript
```typescript
// Lấy token xác thực từ localStorage
function layToken(): string | null {
    // Token được lưu khi đăng nhập thành công
    return localStorage.getItem('auth_token');
}

// Gửi yêu cầu API với retry logic
async function guiYeuCau(url: string): Promise<any> {
    // Thử tối đa 3 lần nếu thất bại
    for (let i = 0; i < 3; i++) {
        // ... xử lý logic
    }
}
```

### 2. Quy Ưu Tiên Comment

| Loại | Bắt buộc Tiếng Việt | Ví dụ |
|------|---------------------|-------|
| Block comment giải thích logic | ✅ Có | `# Tính sát thương theo công thức X` |
| Comment mô tả class/function | ✅ Có | `## Lớp quản lý kho đồ` |
| Docstring (`"""doc"""`) | ✅ Có | `"""Tính tổng tiền đơn hàng."""` |
| TODO/FIXME | ✅ Có | `# TODO: Thêm validation input` |
| Comment debug tạm thời | ✅ Có | `# DEBUG: In log để kiểm tra` |
| Comment vô nghĩa (redundant) | ❌ Không cần | Xóa luôn |

### 3. File Tài Liệu Markdown (`.md`)

Mọi file `.md` trong project phải được viết bằng tiếng Việt, bao gồm:
- README.md
- ARCHITECTURE.md
- API.md
- CHANGELOG.md
- CONTRIBUTING.md
- File giải thích module/feature (`docs/*.md`)

#### Cấu trúc file MD chuẩn

```markdown
# Tên Tính Năng / Module

## Mô Tả
Giải thích ngắn gọn tính năng/module này làm gì.

## Cách Sử Dụng
Hướng dẫn cách tích hợp/sử dụng với code ví dụ.

## Cấu Hình
Liệt kê các tham số cấu hình (nếu có).

## Ví Dụ
Code minh họa bằng ngôn ngữ tương ứng.

## Lưu Ý
Các điểm cần chú ý, hạn chế, hoặc edge cases.
```

## Quy Tắc Riêng Cho Từng Ngôn Ngữ

### GDScript (Godot)

- Sử dụng `##` cho docstring (xuất hiện trong editor Godot)
- Dùng `#` cho comment thường
- Tên biến/hàm vẫn giữ tiếng Anh (để tuân thủ convention của Godot)

```gdscript
## Quản lý máu và sát thương của nhân vật
class_name HeThongMau
extends Node

# Ngưỡng cảnh báo máu thấp (25% tổng máu)
const NGUONG_CANH_BAO: float = 0.25

# Máu hiện tại của nhân vật
var _mau_hien_tai: int = 0

## Gây sát thương cho nhân vật
## [param luong_sat_thuong]: Lượng sát thương nhận vào (phải dương)
func gay_sat_thuong(luong_sat_thuong: int) -> void:
    # Không cho phép sát thương âm
    var sat_thuong_thuc = max(luong_sat_thuong, 0)
    _mau_hien_tai = max(0, _mau_hien_tai - sat_thuong_thuc)
    
    # Phát tín hiệu để UI cập nhật
    mau_thay_doi.emit(_mau_hien_tai)
```

### Python

- Docstring `"""..."""` viết tiếng Việt
- Comment `#` viết tiếng Việt
- Tên biến/hàm có thể giữ tiếng Anh hoặc dùng snake_case tiếng Việt không dấu

```python
class QuanLyKho:
    """Quản lý vật phẩm trong kho đồ của người chơi."""
    
    def __init__(self, suc_chua_toi_da: int = 100):
        """Khởi tạo kho đồ với sức chứa tối đa."""
        # Sức chứa mặc định là 100 ô
        self._suc_chua_toi_da = suc_chua_toi_da
        self._vat_pham = {}
    
    def them_vat_pham(self, vat_pham, so_luong: int = 1) -> bool:
        """Thêm vật phẩm vào kho. Trả về False nếu kho đầy."""
        # Kiểm tra kho còn chỗ trống
        if len(self._vat_pham) >= self._suc_chua_toi_da:
            return False
        
        # Cộng dồn số lượng nếu vật phẩm đã tồn tại
        if vat_pham in self._vat_pham:
            self._vat_pham[vat_pham] += so_luong
        else:
            self._vat_pham[vat_pham] = so_luong
        return True
```

### TypeScript/JavaScript

- JSDoc `/** ... */` viết tiếng Việt
- Comment `//` viết tiếng Việt
- Tên biến/hàm giữ camelCase tiếng Anh

```typescript
/**
 * Hook quản lý xác thực người dùng
 * @returns Thông tin user hiện tại và các hàm đăng nhập/đăng xuất
 */
export function useAuth() {
    // State lưu thông tin user
    const [nguoiDung, setNguoiDung] = useState<User | null>(null);
    
    /** Hàm đăng nhập với email và mật khẩu */
    const dangNhap = async (email: string, matKhau: string) => {
        // Gọi API đăng nhập
        const response = await authApi.dangNhap(email, matKhau);
        setNguoiDung(response.user);
    };
    
    return { nguoiDung, dangNhap };
}
```

## Ngoại Lệ (Được Phép Giữ Tiếng Anh)

1. **Tên biến/hàm/class**: Luôn giữ tiếng Anh (theo convention ngôn ngữ)
2. **String literals hiển thị cho user**: Giữ ngôn ngữ phù hợp với UI
3. **Tên thư viện/API bên ngoài**: Giữ nguyên tên gốc
4. **URL/paths**: Giữ nguyên
5. **Magic numbers có ý nghĩa kỹ thuật**: OK kèm comment tiếng Việt giải thích

```gdscript
# Ví dụ: magic number được giải thích bằng tiếng Việt
const TOC_DO_CHAY_TOI_DA = 300.0  # Pixels/giây - tốc độ chạy của nhân vật

# Tên biến tiếng Anh (theo convention) nhưng comment giải thích tiếng Việt
var player_speed: float = 300.0  # Tốc độ di chuyển của người chơi
```

## Checklist Cho Agent Khi Review Code

Khi review hoặc viết code, agents PHẢI kiểm tra:

- [ ] Tất cả comment logic giải thích đều bằng tiếng Việt
- [ ] Docstring (nếu có) bằng tiếng Việt
- [ ] File `.md` mới tạo đều bằng tiếng Việt
- [ ] TODO/FIXME có giải thích tiếng Việt
- [ ] Không có comment thừa/redundant
- [ ] Tên biến/hàm vẫn theo convention tiếng Anh

## Quy Trình Cập Nhật Documentation

Khi hoàn thành một feature/fix bug:

1. **Cập nhật comment trong code** nếu thay đổi logic
2. **Cập nhật file MD liên quan** trong `docs/` hoặc root
3. **Cập nhật CHANGELOG.md** với mô tả tiếng Việt
4. **Commit message** có thể viết tiếng Anh hoặc tiếng Việt (khuyến nghị tiếng Việt)

## Ví Dụ File MD Hoàn Chỉnh

```markdown
# Module Quản Lý Kho Đồ

## Mô Tả
Module này chịu trách nhiệm quản lý tất cả vật phẩm trong kho đồ của người chơi, bao gồm thêm, xóa, sắp xếp và lưu trữ.

## Cách Sử Dụng

\`\`\`gdscript
var kho = KhoDo.new()
kho.them_vat_pham(KiemGay.new(), 1)
print(kho.dem_vat_pham())  # In ra: 1
\`\`\`

## Cấu Hình

| Thuộc tính | Kiểu | Mặc định | Mô tả |
|------------|------|----------|-------|
| `suc_chua_toi_da` | int | 100 | Số ô tối đa trong kho |
| `cho_phep_trung` | bool | false | Cho phép các vật phẩm trùng stack |

## Lưu Ý
- Kho đồ được lưu tự động khi game save
- Giới hạn sức chứa có thể tăng qua nâng cấp
```

## Tổng Kết

**Rule bắt buộc**: Toàn bộ comments code và file `.md` documentation trong project này phải được viết bằng **tiếng Việt** để đảm bảo tính dễ hiểu và nhất quán. Agents không được tạo code hoặc tài liệu bằng tiếng Anh nếu không có lý do kỹ thuật cụ thể.