# Chuẩn gói Mini App v1

Super App dùng gói phát hành ZIP có manifest ở thư mục gốc, theo cách tổ chức dự án có file cấu hình như [Zalo Mini App](https://docs.zaloplatforms.com/docs/MA/intro/getting-started/app-config). Đây là định dạng riêng của Super App, không phải gói tương thích Zalo hay SDK Zalo.

## Cấu trúc

Web Mini App:

```text
web_demo-1.0.0.zip
├── app.json
├── icon.png
└── dist/
    ├── index.html
    └── assets/
        ├── app.js
        └── style.css
```

Schema Mini App:

```text
schema_demo-1.0.0.zip
├── app.json
├── icon.png
└── schema.json
```

ZIP phải chứa trực tiếp các file này, không bọc thêm một thư mục cha. Chỉ đóng gói tài nguyên phát hành; không gửi source, `.env`, `node_modules` hoặc symlink.

## app.json

```json
{
  "manifestVersion": 1,
  "appId": "web_demo",
  "name": "Web Demo",
  "description": "Mini App mẫu chạy trong Super App",
  "category": "Demo",
  "version": "1.0.0",
  "runtimeType": "web",
  "entry": "dist/index.html",
  "icon": "icon.png",
  "permissions": ["navigation.close"],
  "developerName": "Demo Team",
  "supportEmail": "support@example.com",
  "website": "https://example.com",
  "themeColor": "#6366F1"
}
```

| Trường | Quy định |
| --- | --- |
| `manifestVersion` | Bắt buộc là số `1`, xác định định dạng gói |
| `appId` | Bắt buộc, 3–64 ký tự chữ thường/số/`_`/`-`, bắt đầu bằng chữ hoặc số; khớp App ID đã đăng ký |
| `name` | Bắt buộc, tối đa 128 ký tự |
| `description` | Bắt buộc là chuỗi, có thể rỗng, tối đa 4.000 ký tự |
| `category` | Bắt buộc, tối đa 64 ký tự |
| `version` | Bắt buộc dạng `X.Y.Z`, không có số 0 thừa ở đầu; tối đa 32 ký tự, không trùng phiên bản đã upload của app |
| `runtimeType` | Bắt buộc là `web` hoặc `schema`, khớp loại đã đăng ký |
| `entry` | `dist/index.html` cho web; `schema.json` cho schema; file phải có trong ZIP |
| `icon` | Đường dẫn tương đối tới file PNG/JPEG/WebP trong ZIP, tối đa 2 MB |
| `permissions` | Bắt buộc là mảng capability duy nhất, có thể `[]`. Ví dụ `navigation.close`, `user.getProfile`, `payment.createOrder` |
| `developerName` | Tùy chọn, tối đa 128 ký tự |
| `supportEmail` | Tùy chọn, email hợp lệ |
| `website` | Tùy chọn, URL HTTP(S) |
| `themeColor` | Tùy chọn, màu dạng `#RRGGBB` |

Các trường ngoài hợp đồng bị từ chối. Backend không tin tên ZIP: App ID, version và runtime được đọc và kiểm tra từ `app.json`. Backend tự tính SHA256 của toàn bộ file ZIP nhận được để nhận diện gói; không dùng checksum do client khai báo.

`schema.json` có `schemaVersion` nguyên dương và `pages` không rỗng. Mỗi trang có `id` duy nhất và `components` dạng mảng. `manifestVersion` mô tả gói, `schemaVersion` mô tả nội dung schema, còn `version` là phiên bản phát hành của miniapp.

## Đóng gói

Hai bộ mẫu đầy đủ nằm ở `examples/miniapps/web-demo` và `examples/miniapps/schema-demo`. Trang quản lý cũng có link tải ZIP mẫu.

Với web, build trước rồi đặt kết quả trong `dist/` của thư mục gói. Vite dùng `base: './'` để JS/CSS/ảnh tải đúng từ URL từng phiên bản. Dùng hash routing nếu cần điều hướng SPA; máy chủ không có history fallback. Tham chiếu ảnh trong schema hiện dùng URL HTTP(S) đầy đủ như runtime schema sẵn có.

Từ thư mục `backend`:

```sh
npm install
npm run build
npm run package:miniapp -- ../examples/miniapps/web-demo ../web_demo-1.0.0.zip
```

Lệnh đóng gói kiểm tra bằng cùng bộ validator với backend. Khi làm bản mới, sửa `version` trong `app.json`, build lại nội dung rồi đóng gói lại. Tên file ZIP có thể tùy chọn. Thay `appId` và metadata của gói mẫu nếu upload cho ứng dụng khác.

## Upload và chạy

1. Tạo bản ghi Mini App trong Manager với đúng App ID và loại runtime.
2. Chọn ZIP. Manager gọi API kiểm tra, hiển thị App ID, tên, version, entry, quyền, số file và SHA256. Bước này không ghi dữ liệu.
3. Chọn **Upload và dùng phiên bản này**. Backend giải nén vào thư mục riêng, lưu manifest/checksum/lịch sử và chuyển version trong transaction. Nếu lưu database thất bại, file vừa ghi được dọn dẹp. Upload không đổi trạng thái ẩn/hiện.
4. Metadata hiển thị (tên, mô tả, icon, danh mục, nhà phát triển, liên hệ, màu) được cập nhật từ gói. Có thể sửa lại trong Manager sau upload. Version và quyền yêu cầu thuộc manifest, không nhập tay để thay nội dung gói.
5. Trong **Quyền yêu cầu và quyền được cấp**, chọn các quyền muốn cấp rồi lưu. Quyền mới luôn chưa được cấp; quyền đã cấp chỉ được giữ nếu gói mới vẫn yêu cầu. Quyền bị bỏ khỏi manifest sẽ bị thu hồi. Manifest trong lịch sử ghi quyền yêu cầu, catalog trả `capabilities` là quyền được cấp hiện hành.
6. Bật hiển thị, kéo làm mới Flutter và mở app. Web tải HTML/JS/CSS từ backend; schema dùng engine schema đã đóng gói trong Flutter. Mở lại miniapp để lấy quyền/phiên bản mới.

Dữ liệu mẫu cũ vẫn chạy. Các bản mới đều phải upload ZIP; API upload JSON/URL tự do trước đây đã được bỏ. Với app chưa có gói chuẩn, Manager giữ phần sửa quyền cũ để tiếp tục demo.

## API

| Method | Path | Nội dung |
| --- | --- | --- |
| POST | `/api/v1/registry/apps/:id/packages/inspect` | `multipart/form-data`, trường `file`: ZIP; trả manifest, checksum, size, fileCount |
| POST | `/api/v1/registry/apps/:id/versions` | `multipart/form-data`, trường `file`: ZIP; tùy chọn `notes` |
| GET | `/api/v1/miniapps/:id/:version/*` | Tài nguyên của phiên bản đang hiện; icon vẫn truy cập được để hiển thị trong Manager khi app ẩn |

Ví dụ:

```sh
curl -F 'file=@web_demo-1.0.0.zip' -F 'notes=Demo release' \
  http://localhost:3000/api/v1/registry/apps/web_demo/versions
```

ZIP tối đa 20 MB, 500 entry, 10 MB/file, tổng giải nén 50 MB; JSON tối đa 1 MB. Backend từ chối đường dẫn traversal, file trùng, symlink và ZIP mã hóa. Đường dẫn nội bộ chỉ dùng chữ/số/`_`/`-`/`.`/`/`.

File nằm trong `backend/storage/miniapps/` khi chạy từ `backend`, hoặc cấu hình đường dẫn tuyệt đối qua `MINIAPP_STORAGE_DIR`. Khi chuyển máy, cần sao lưu cả PostgreSQL lẫn thư mục này. Dữ liệu upload không đưa vào Git.

Catalog trả đường dẫn tương đối `/api/v1/miniapps/...`; Flutter resolve theo host của `catalogApiUrl`, nên không bị cố định localhost trong gói. Cấu hình địa chỉ backend phù hợp với thiết bị chạy Flutter.
