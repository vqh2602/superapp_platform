# Miniapps dùng để kiểm thử

Tên trong catalog backend, manifest `app.json` và giao diện miniapp được đồng bộ:

| App ID / thư mục | Tên trên backend | Nội dung test |
| --- | --- | --- |
| `sdk_playground` | SDK Playground (React) | React + TypeScript, gọi SDK và xem JSON native |
| `schema_runtime` | Schema Runtime (React + JSON) | Runtime React render schema JSON |
| `sample_store` | Sample Store (HTML + JS) | HTML/JavaScript, chuyển qua lại miniapp |
| `flutter_scanner` | Flutter Scanner (Flutter Web) | Flutter Web, quét QR/barcode và gọi bridge trực tiếp |

Chạy `npm run build:miniapps` từ thư mục gốc. Pipeline đóng gói toàn bộ `dist/`, gồm JS/WASM/font của Flutter Scanner, vào `backend/seed-bundles/` và ZIP. Release backend phải mang theo `seed-bundles/` và chạy seed để cập nhật catalog, manifest và package key.

Flutter dùng SDK ở `.fvm/flutter_sdk/bin/flutter` nếu có; CI dùng `flutter` trên PATH. Có thể chọn SDK bằng biến `FLUTTER_BIN`. Các asset Flutter dùng đường dẫn tương đối trong URL của package.

### Ví dụ sinh trắc học

SDK Playground có hai mục trong **A. Authentication Flow**: kiểm tra hỗ trợ/
thiết lập và xác thực vân tay / Face ID. Đăng nhập SuperApp, mở Playground,
kiểm tra trạng thái rồi chạy xác thực. Khi chưa thiết lập, ví dụ hiển thị hướng
dẫn kiểm tra Cài đặt thiết bị. Xem [API và xử lý lỗi](../docs/authentication.md#xác-thực-sinh-trắc-học-trong-mini-app).

Playground dùng SDK đã phát hành trên npm (`@vqh2602/mini-app-sdk@^2.0.0`).
Chạy `npm install` và `npm run build` tại `mini_apps/sdk_playground`.

SDK `2.0.0` sửa định danh native để lời gọi đến được bảng cấp quyền. Playground, Schema Runtime và Sample Store đã gỡ các ví dụ thanh toán.
