# Miniapps dùng để kiểm thử

Tên trong catalog backend, manifest `app.json` và giao diện miniapp được đồng bộ:

| App ID / thư mục | Tên trên backend | Nội dung test |
| --- | --- | --- |
| `sdk_playground` | SDK Playground (React) | React + TypeScript, gọi SDK và xem JSON native |
| `schema_runtime` | Schema Runtime (React + JSON) | Runtime React render schema JSON |
| `sample_store` | Sample Store (HTML + JS) | HTML/JavaScript, chuyển qua lại miniapp |
| `flutter_scanner` | Flutter Scanner (Flutter Web) | Flutter Web, quét QR/barcode và gọi bridge trực tiếp |

Cài phụ thuộc rồi chạy pipeline từ thư mục gốc.

```sh
npm ci --prefix backend
npm ci --prefix mini_app_sdk
npm ci --prefix mini_apps/sdk_playground
npm ci --prefix mini_apps/schema_runtime
npm run build:miniapps
```

Playground và Schema Runtime liên kết trực tiếp với SDK trong repo qua `file:../../mini_app_sdk`. Pipeline build SDK trước khi build các ví dụ, sau đó đóng gói toàn bộ `dist/`, gồm JS/WASM/font của Flutter Scanner, vào `backend/seed-bundles/` và ZIP. Release backend mang theo `seed-bundles/` để cập nhật catalog, manifest và package key khi seed.

Flutter dùng SDK ở `.fvm/flutter_sdk/bin/flutter` nếu có; CI dùng `flutter` trên PATH. Có thể chọn SDK bằng biến `FLUTTER_BIN`. Các asset Flutter dùng đường dẫn tương đối trong URL của package.

### Ví dụ sinh trắc học

SDK Playground có hai mục trong **A. Authentication Flow**: kiểm tra hỗ trợ/
thiết lập và xác thực vân tay / Face ID. Đăng nhập SuperApp, mở Playground,
kiểm tra trạng thái rồi chạy xác thực. Khi chưa thiết lập, ví dụ hiển thị hướng
dẫn kiểm tra Cài đặt thiết bị. Xem [API và xử lý lỗi](../docs/authentication.md#xác-thực-sinh-trắc-học-trong-mini-app).

### Ví dụ lưu trữ hàng loạt

Trong Playground, mở **2.8. Keychain & Keystore** trên Flutter Host có hỗ trợ lưu trữ lô. Chạy `storage.setItems` rồi `storage.getItems` với cùng domain. Kết quả mặc định gồm `theme: "dark"`, `lang: "vi"` và `missing: null`. Xem [hợp đồng Bridge](../docs/superapp.md#storagegetitems--storagesetitems).

SDK `2.0.0` sửa định danh native để lời gọi đến được bảng cấp quyền. Playground, Schema Runtime và Sample Store đã gỡ các ví dụ thanh toán.
