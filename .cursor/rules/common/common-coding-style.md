---
description: "ECC coding style: immutability, file organization, error handling, validation"
alwaysApply: true
language: vi
---
# Quy Tắc Phong Cách Code

> ⚠️ **Lưu ý quan trọng**: Toàn bộ comments code và file documentation (`.md`) trong project này phải được viết bằng **tiếng Việt**. Xem chi tiết tại `common-vietnamese-documentation.md`.

## Tính Bất Biến (QUAN TRỌNG)

LUÔN tạo object mới, KHÔNG BAO GIỜ thay đổi object đã có:

```
// Mã giả
SAI:     sua(ban_goc, truong, gia_tri)  // thay đổi trực tiếp ban_goc
ĐÚNG:    cap_nhat(ban_goc, truong, gia_tri)  // trả về bản sao mới với thay đổi
```

Lý do: Dữ liệu bất biến giúp tránh side effect ẩn, dễ debug, và hỗ trợ concurrency an toàn.

## Tổ Chức File

NHIỀU FILE NHỎ > ÍT FILE LỚN:
- Liên kết chặt (high cohesion), ít phụ thuộc (low coupling)
- 200-400 dòng điển hình, tối đa 800 dòng
- Tách utility từ module lớn
- Tổ chức theo feature/domain, không theo loại

## Xử Lý Lỗi

LUÔN xử lý lỗi toàn diện:
- Xử lý lỗi rõ ràng ở mọi tầng
- Hiển thị thông báo lỗi thân thiện ở code UI
- Log chi tiết context lỗi ở server
- Không bao giờ nuốt lỗi âm thầm

## Validate Input

LUÔN validate ở system boundaries:
- Validate toàn bộ input người dùng trước khi xử lý
- Dùng schema-based validation khi có thể
- Fail fast với thông báo lỗi rõ ràng
- Không tin tưởng dữ liệu ngoài (API response, user input, file content)

## Checklist Chất Lượng Code

Trước khi hoàn thành:
- [ ] Code dễ đọc, tên biến rõ nghĩa
- [ ] Hàm ngắn gọn (<50 dòng)
- [ ] File tập trung (<800 dòng)
- [ ] Không lồng quá sâu (>4 cấp)
- [ ] Xử lý lỗi đầy đủ
- [ ] Không hardcode (dùng const hoặc config)
- [ ] Không mutate (dùng pattern bất biến)
- [ ] Comments giải thích bằng tiếng Việt
