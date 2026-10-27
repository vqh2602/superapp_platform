# SuperApp Backend Registry & Catalog Service

Dịch vụ Backend quản lý danh mục Mini App tập trung, xác thực phân quyền, quản lý phiên bản và cung cấp Catalog API cho **SuperApp Platform**.

> 📖 **Xem toàn bộ tài liệu chi tiết**: [Tài liệu Kiến trúc & Hướng dẫn Triển khai Production đầy đủ](../docs/backend.md)

---

## 🚀 Khởi chạy nhanh (Quick Start)

### 1. Khởi động môi trường phát triển cục bộ
Yêu cầu Node.js 18/20 và PostgreSQL đang chạy ở cổng `5432`:

```bash
# Tạo cơ sở dữ liệu
createdb superapp_registry

# Cài đặt thư viện
npm install

# Khởi chạy ở chế độ dev (Hot-reload)
npm run start:dev
```
- API Base URL: `http://localhost:3000/api/v1`
- Database mặc định: `superapp_registry`
- Tự động nạp dữ liệu mẫu (`SeedService`) khi khởi chạy lần đầu.

### 2. Khởi chạy bằng Docker Compose (Đầy đủ Database + API)
```bash
docker compose up -d --build
```

---

## 📌 Nhóm API chính (`/api/v1`)

| Nhóm API | Phương thức | Endpoint | Chức năng |
| :--- | :---: | :--- | :--- |
| **Catalog** | `GET` | `/catalog/apps` | Danh sách Mini App đang hiển thị cho Flutter Client |
| | `GET` | `/catalog/apps/:id` | Tải Manifest & Schema phiên bản hiện hành |
| | `GET` | `/catalog/categories` | Danh sách các danh mục có chứa Mini App |
| **Registry** | `GET` | `/registry/apps` | Toàn bộ Mini App (cả đang hiện và ẩn) |
| | `POST` | `/registry/apps` | Đăng ký Mini App mới |
| | `GET` | `/registry/apps/:id` | Xem chi tiết, bản nháp Schema & lịch sử phiên bản |
| | `PUT` | `/registry/apps/:id` | Cập nhật thông tin và cập nhật quyền (`capabilities`) |
| | `POST` | `/registry/apps/:id/versions` | Phát hành phiên bản mới (`X.Y.Z`) |
| | `PATCH`| `/registry/apps/:id/visibility` | Bật/Tắt hiển thị trong Catalog (`visible`) |

---

## 🧪 Kiểm thử & Build

```bash
# Chạy Unit Tests
npm test

# Build TypeScript bản Production
npm run build
```

---

## 📚 Tài liệu liên quan
- [Tài liệu Kiến trúc & Triển khai Chi tiết](../docs/backend.md)
- [Tài liệu SuperApp Flutter Shell](../docs/superapp.md)
- [Tài liệu Mini App Developer SDK](../docs/sdk.md)
