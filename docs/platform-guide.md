# Mini App demo backend

Ứng dụng quản trị chỉ có **Quản lý Mini App**, không còn màn thiết kế hay luồng xét duyệt.

Quản lý App ID, loại runtime, tên, mô tả, icon, danh mục, nhà phát triển, email, website, màu thương hiệu, phiên bản, quyền yêu cầu/quyền được cấp và trạng thái ẩn/hiện.

## Chạy

Cần Node.js, npm, PostgreSQL đang chạy và database `superapp_registry`:

```sh
createdb superapp_registry
cd backend
npm install
npm run build
npm run start:prod
```

Terminal khác:

```sh
cd builder
npm install
npm run dev
```

Mở http://localhost:5174. Backend chạy cổng 3000; cấu hình PostgreSQL qua `DB_HOST`, `DB_PORT`, `DB_USERNAME`, `DB_PASSWORD`, `DB_DATABASE`. Mặc định localhost:5432, user hệ điều hành, password rỗng. Backend tự tạo bảng và thêm mẫu chưa tồn tại. `start:dev` dùng ts-node; khởi động lại sau khi sửa backend.

Trang quản lý không có đăng nhập/phân vai vì phục vụ demo. Có thể đặt `MINIAPP_API_TARGET` khi chạy builder để proxy tới backend khác, mặc định `http://localhost:3000`.

## User, đăng nhập và quyền theo từng app

Backend có bảng user, đăng ký/đăng nhập email/password, access/refresh token, code Mini App một lần và consent theo từng user/app. Xem [API và ví dụ tích hợp](authentication.md). Đây là nhóm API riêng; Manager vẫn là công cụ demo và Flutter/SDK hiện còn dùng auth/permission mock.

## Phiên bản mới

Mọi bản upload mới là **ZIP theo chuẩn Super App v1**, có `app.json`, icon và `dist/index.html` (web) hoặc `schema.json` (schema). Backend đọc App ID, version và quyền từ manifest, kiểm tra gói và tự host tài nguyên web. Không nhận upload JSON/URL tùy ý.

Xem [đặc tả gói, ví dụ và lệnh đóng gói](miniapp-package.md). Có gói mẫu web/schema ngay trong mục Upload của Manager. Đăng ký app với App ID `web_demo` hoặc `schema_demo` để thử nguyên gói mẫu.

Luồng demo: tạo app → chọn ZIP/xem manifest → upload → cấp quyền yêu cầu → bật hiển thị → kéo làm mới Flutter/mở app. Cập nhật: tăng version trong manifest, build và upload gói mới. Upload giữ trạng thái ẩn/hiện và không tự cấp quyền mới.

## API quản lý

Base path `/api/v1`:

| Method | Path | Công dụng |
| --- | --- | --- |
| GET | `/registry/apps` | Danh sách, metadata và lịch sử phiên bản |
| POST | `/registry/apps` | Tạo app: `id`, `name`, `runtimeType`, metadata mô tả |
| GET | `/registry/apps/:id` | Chi tiết app |
| PUT | `/registry/apps/:id` | Sửa metadata hoặc `capabilities` được cấp |
| POST | `/registry/apps/:id/packages/inspect` | Kiểm tra ZIP trước khi upload |
| POST | `/registry/apps/:id/versions` | Upload ZIP qua multipart field `file`, tùy chọn `notes` |
| PATCH | `/registry/apps/:id/visibility` | `{ "visible": true }` hoặc `false` |
| GET | `/catalog/apps` | Danh sách đang hiện, hỗ trợ category/search/page/limit |
| GET | `/catalog/apps/:id` | Manifest runtime, quyền được cấp và schema nếu có |
| GET | `/catalog/categories` | Các danh mục đang hiện |
| GET | `/miniapps/:id/:version/*` | HTML/JS/CSS/ảnh của gói đang dùng |

Ẩn app chặn cả catalog chi tiết và tải tài nguyên chạy app. Icon vẫn dùng được trong Manager. Dữ liệu mẫu/phiên bản cũ được giữ nguyên.

## Kiểm tra

```sh
cd backend
npm test -- --runInBand
npm run build
npm run test:packages:db
npm run test:auth:db
```

`test:packages:db` cần quyền tạo database PostgreSQL; tự tạo database và thư mục tạm, kiểm tra ZIP web/schema rồi dọn toàn bộ dữ liệu thử.

```sh
cd builder
npm run build
```

Tại thư mục gốc: `fvm flutter test test/unit/catalog_test.dart test/unit/nocode_schema_e2e_test.dart`.
