# Mini App demo backend

Backend NestJS + PostgreSQL và trang quản lý React dùng chung một luồng đơn giản: thêm Mini App, lưu thông tin/quyền, upload phiên bản, bật hoặc tắt hiển thị. Không còn bước gửi xét duyệt, duyệt, rollback, suspend hay trang audit.

## Chạy demo

Cần Node.js, npm và PostgreSQL đang chạy. Tạo database `superapp_registry` nếu chưa có:

```sh
createdb superapp_registry
cd backend
npm install
npm run start:dev
```

Backend chạy ở cổng `3000`, tự tạo bảng và thêm các Mini App mẫu nếu chưa tồn tại. Cấu hình kết nối qua `DB_HOST`, `DB_PORT`, `DB_USERNAME`, `DB_PASSWORD`, `DB_DATABASE`; mặc định dùng localhost:5432, user hệ điều hành và password rỗng.

Mở terminal khác:

```sh
cd builder
npm install
npm run dev
```

Mở http://localhost:5174. Trang **Quản lý Mini App** là màn hình mặc định. Tab **Thiết kế Schema** vẫn hỗ trợ chỉnh giao diện trực quan, lưu nháp và upload trực tiếp.

## Thao tác

1. Chọn **Thêm Mini App**, nhập ID, tên, loại schema/web và các quyền được cấp. Mini App mới luôn ẩn.
2. Với schema: chọn file JSON hoặc nhập nội dung trực tiếp, có `schemaVersion` và mảng `pages`; mỗi trang có `id` và `components`. Runtime mặc định là `assets/mini_apps/schema_runtime/index.html` đã có trong Super App. File JSON tối đa 1 MB.
3. Với web: nhập URL HTTP(S) đã host. Backend đăng ký URL, không nhận/gỡ nén gói ZIP hoặc host bundle web. Tùy chọn assets chỉ trỏ tới tài nguyên đã đóng gói trong bản Flutter hiện tại.
4. Nhập version dạng `X.Y.Z` và upload. Backend lưu snapshot, chuyển version đang dùng trong cùng transaction; version trùng bị từ chối. Trạng thái ẩn/hiện được giữ nguyên.
5. Nhấn **Hiện Mini App** để đưa vào catalog, **Ẩn Mini App** để gỡ khỏi catalog và chặn mở trực tiếp. Trên Flutter, kéo làm mới danh sách, mở lại app để lấy phiên bản/quyền mới.
6. Sửa danh sách quyền rồi lưu để cập nhật quyền hiện hành, không cần upload lại version. Quyền trong snapshot cũ chỉ là lịch sử; catalog trả quyền hiện hành. Phiên đang mở cần mở lại để nhận thay đổi.

Đây là trang quản trị demo, không có đăng nhập hay phân vai/tenant. Giữ nguyên database hiện có và các cột lịch sử để tương thích dữ liệu cũ; các trạng thái cũ khác `PUBLISHED` được coi là đang ẩn.

## API

Base path: `/api/v1`.

| Method | Path | Nội dung |
| --- | --- | --- |
| GET | `/registry/apps` | Tất cả Mini App và phiên bản |
| POST | `/registry/apps` | Tạo Mini App: `id`, `name`, tùy chọn `runtimeType`, `description`, `category`, `icon`, `capabilities`, `draftSchema` |
| GET | `/registry/apps/:id` | Chi tiết và lịch sử phiên bản |
| PUT | `/registry/apps/:id` | Lưu `name`, `description`, `category`, `icon`, `capabilities`, `draftSchema` |
| POST | `/registry/apps/:id/versions` | Upload JSON: `version`, tùy chọn `schema`, `entryUrl`, `isAsset`, `notes` |
| PATCH | `/registry/apps/:id/visibility` | `{ "visible": true }` hoặc `false` |
| GET | `/catalog/apps` | Mini App đang hiện; hỗ trợ `category`, `search`, `page`, `limit` |
| GET | `/catalog/apps/:id` | Manifest, schema phiên bản đang dùng và quyền hiện hành; app ẩn trả 403 |
| GET | `/catalog/categories` | Danh mục có Mini App đang hiện |

`POST .../versions` dùng schema từ request hoặc bản nháp đã lưu. URL/runtime cũng có thể kế thừa từ app. Upload không thay đổi quyền: quản lý quyền qua `PUT .../:id`.

Các API cũ `/submit`, `/review`, `/publish`, `/unpublish`, `/rollback`, `/suspend` và `/registry/apps/audits` đã được bỏ. Client quản trị cũ cần chuyển sang `/versions` và `/visibility`. API catalog cho Flutter giữ nguyên định dạng.

## Kiểm tra

```sh
cd backend
npm test -- --runInBand
npm run build
```

```sh
cd builder
npm run build
```

Tại thư mục gốc, chạy `fvm flutter test test/unit/catalog_test.dart` để kiểm tra catalog, offline fallback và việc app ẩn không xuất hiện lại từ dữ liệu mẫu.
