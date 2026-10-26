# SuperApp Platform

Nền tảng **SuperApp Mobile Platform** xây dựng trên **Flutter** hỗ trợ nạp, khởi chạy và quản lý các **Mini Apps** (viết bằng Web/HTML/React/TypeScript) thông qua cơ chế **JavaScript Bridge 2 chiều** (Flutter WebViewController ↔ Web JavaScript SDK), kiểm soát quyền (Permission Gatekeeper), Navigation, Authentication & Payment mock.

---

## 📑 Mục Lục
- [Tổng quan kiến trúc](#-tổng-quan-kiến-trúc)
- [Cấu trúc thư mục dự án](#-cấu-trúc-thư-mục-dự-án)
- [Cơ chế Bridge Protocol](#-cơ-chế-bridge-protocol)
- [Các tính năng chính](#-các-tính-năng-chính)
- [Danh sách Mini Apps](#-danh-sách-mini-apps)
- [Yêu cầu môi trường & Cài đặt](#-yêu-cầu-môi-trường--cài-đặt)
- [Hướng dẫn build & chạy dự án](#-hướng-dẫn-build--chạy-dự-án)
  - [Chạy SuperApp Platform (Flutter)](#1-chạy-superapp-platform-flutter)
  - [Build Mini App Web Assets](#2-build-mini-app-web-assets)
- [Tạo mới Mini App hoặc mở rộng SDK](#-tạo-mới-mini-app-hoặc-mở-rộng-sdk)

---

## 🏛 Tổng quan kiến trúc

Hệ thống được tổ chức thành 2 tầng rõ ràng:

1. **Host App (Flutter SuperApp Shell)**:
   - **Framework**: Flutter (Dart ^3.11 / SDK 3.x), State Management: `flutter_riverpod`, Routing: `go_router`.
   - **Mini App Runtime**: Sử dụng `webview_flutter` kết hợp với `JavascriptChannel` để load local asset / remote URL.
   - **Bridge Dispatcher**: Tiếp nhận message JSON từ Webview, kiểm tra tính hợp lệ (`BridgeRequest`), kiểm tra quyền thực thi (Capabilities Gatekeeper), phân giải tới handler phù hợp và trả response (`BridgeResponse`).
   - **Native Handlers**: Xác thực (`AuthActionHandler`), Thiết bị (`DeviceActionHandler`), Điều hướng (`NavigationActionHandler`), Thanh toán (`PaymentActionHandler`), Quyền (`PermissionActionHandler`), User (`UserActionHandler`), Debug (`DebugActionHandler`).
   - **Debug Center**: Giao diện Native kiểm tra lịch sử logs gọi bridge (thời gian, status, payload sanitize).

2. **Mini App Environment (Web / React / TypeScript)**:
   - **Runtime**: Webview (HTML5, JS/TS).
   - **SDK Client (`superapp-sdk`)**: Thư viện client đóng gói `window.FlutterBridge`, hỗ trợ Promise-based APIs (`invokeBridge`), Event emitter/listener và TypeScript typings.
   - **UI Showcase**: React 18, Vite, Lucide Icons test bed trực quan các tính năng của SDK.

---

## 📂 Cấu trúc thư mục dự án

```text
superapp_platform/
├── assets/
│   └── mini_apps/               # Thư mục chứa bundle html/js sau khi build của mini apps
│       ├── sdk_playground/
│       └── sample_store/
├── lib/
│   ├── app/
│   │   ├── bootstrap/           # Khởi tạo App & Theme (app_bootstrap.dart)
│   │   └── router/              # Định tuyến GoRouter (app_router.dart)
│   ├── core/
│   │   ├── bridge_protocol/     # Chuẩn hóa Bridge Envelope, Request, Response, Event
│   │   ├── errors/              # Định nghĩa BridgeError & mã lỗi
│   │   └── config/              # Cấu hình chung
│   ├── features/
│   │   ├── authentication/      # Quản lý đăng nhập, cấp token & auth code cho Mini App
│   │   ├── debug_center/        # Native Debug Screen xem nhật ký Bridge logs
│   │   ├── device/              # Các hành động device (QR Code, Camera, Location)
│   │   ├── mini_app_bridge/     # BridgeChannel, BridgeDispatcher, BridgeEventEmitter
│   │   ├── mini_app_catalog/    # Danh sách Mini App, hiển thị Catalog/Store
│   │   ├── mini_app_runtime/    # Màn hình Webview chứa Mini App container
│   │   ├── native_actions/      # Action Dispatcher & các Action Handlers
│   │   ├── payment/             # Quản lý mock thanh toán, tạo đơn & checkout
│   │   ├── permissions/         # Kiểm soát phân quyền Mini App (Manifest capabilities)
│   │   └── user_profile/        # Màn hình Profile native & trả dữ liệu User
│   └── main.dart                # Điểm khởi chạy của ứng dụng Flutter
├── mini_apps/                   # Mã nguồn các Mini App (Web frontend)
│   ├── sdk_playground/          # Ứng dụng React 18 + Vite + TS làm sandbox test SDK
│   │   ├── src/
│   │   │   ├── sdk/             # Mã nguồn JavaScript Bridge SDK
│   │   │   └── components/      # UI tương tác các chức năng
│   │   ├── package.json
│   │   └── vite.config.ts
│   └── sample_store/            # Mini App mẫu minh họa
├── .vscode/
│   └── launch.json              # Cấu hình Run & Debug (Debug, Profile, Release)
└── pubspec.yaml                 # Quản lý dependencies & assets Flutter
```

---

## 🔌 Cơ chế Bridge Protocol

Giao thức truyền thông hai chiều giữa Mini App (Web) và Flutter Platform tuân thủ cấu trúc JSON:

### 1. Request từ Mini App tới Flutter
```json
{
  "id": "uuid-v4-request-id",
  "action": "user.getProfile",
  "payload": {},
  "origin": "assets/mini_apps/sdk_playground/index.html"
}
```

### 2. Response từ Flutter trả về Mini App
```json
{
  "id": "uuid-v4-request-id",
  "success": true,
  "data": {
    "userId": "usr_123456",
    "name": "Alex Mercer",
    "email": "alex@example.com"
  },
  "executionTimeMs": 12
}
```
*(Nếu thất bại, `success: false` và có object `error: { "code": "PERMISSION_DENIED", "message": "..." }`)*

### 3. Events từ Flutter gửi tới Mini App (Push)
Flutter có thể phát sự kiện native về cho Webview (như đổi theme, mạng thay đổi, lifecycle):
```json
{
  "event": "superapp:lifecycle",
  "payload": {
    "state": "resumed"
  }
}
```

---

## ⚡ Các tính năng chính

| Action Name | Handler | Mô tả |
| :--- | :--- | :--- |
| `auth.requestCode` | `AuthActionHandler` | Cấp mã Authorization Code cho Mini App theo session người dùng |
| `user.getProfile` | `UserActionHandler` | Trả về thông tin chi tiết người dùng (cần quyền `user.getProfile`) |
| `user.getBasicInfo` | `UserActionHandler` | Trả thông tin cơ bản công khai của người dùng |
| `device.scanQRCode` | `DeviceActionHandler` | Mở quét mã QR code (mock quét thành công mã kiểm thử) |
| `device.getLocation` | `DeviceActionHandler` | Lấy tọa độ GPS thiết bị hiện tại |
| `device.pickImage` | `DeviceActionHandler` | Chọn hình ảnh từ thư viện/camera thiết bị |
| `payment.createOrder` | `PaymentActionHandler` | Tạo đơn hàng thanh toán trên SuperApp |
| `payment.openCheckout` | `PaymentActionHandler` | Mở flow xác thực thanh toán tiền |
| `navigation.openNativePage` | `NavigationActionHandler` | Điều hướng từ Mini App ra màn hình Native (`/profile`, `/debug`, `/form`) |
| `navigation.openMiniApp` | `NavigationActionHandler` | Mở một Mini App khác trực tiếp từ Mini App hiện tại |
| `navigation.close` | `NavigationActionHandler` | Đóng Mini App runtime và quay về trang Home Catalog |
| `permission.request` | `PermissionActionHandler` | Yêu cầu cấp quyền người dùng động |
| `debug.echo` | `DebugActionHandler` | Phản hồi lại payload truyền lên (dùng để test latency) |
| `debug.simulateFailure` | `DebugActionHandler` | Giả lập lỗi để test luồng xử lý ngoại lệ trên Mini App |

---

## 📱 Danh sách Mini Apps

1. **SDK Playground (`sdk_playground`)**:
   - Giao diện React + TypeScript cho phép lập trình viên trực tiếp click gọi từng hàm của SDK, xem payload JSON trả về và test các kịch bản thực tế.
2. **Sample Store (`sample_store`)**:
   - Mini App bán hàng mẫu minh họa luồng giỏ hàng, thanh toán và chuyển đổi giữa các Mini App.

---

## 🛠 Yêu cầu môi trường & Cài đặt

- **Flutter**: Phiên bản `>= 3.24.0` (Khuyên dùng bản quản lý qua FVM: `3.41.9` như cấu hình trong `.fvmrc`).
- **Dart**: `>= 3.11.5`.
- **Node.js**: Phiên bản `>= 18.x` (để build code trong thư mục `mini_apps/`).

### Cài đặt dependencies:
```bash
# 1. Cài đặt thư viện Flutter
flutter pub get
# (hoặc với FVM: fvm flutter pub get)

# 2. Cài đặt thư viện Web Mini App
cd mini_apps/sdk_playground
npm install
cd ../..
```

---

## 🚀 Hướng dẫn build & chạy dự án

### 1. Chạy SuperApp Platform (Flutter)

#### Cách 1: Sử dụng VS Code (F5)
Mở tab **Run & Debug** (`Cmd + Shift + D` trên Mac hoặc `Ctrl + Shift + D` trên Windows) và chọn một trong các cấu hình trong file [launch.json](.vscode/launch.json):
- **SuperApp Platform (Debug)**: Chạy bản Debug.
- **SuperApp Platform (Profile mode)**: Chạy bản Profile để đo benchmark.
- **SuperApp Platform (Release mode)**: Chạy bản Release tối ưu.

#### Cách 2: Sử dụng dòng lệnh Terminal
```bash
# Chạy trên thiết bị mặc định
flutter run

# Chỉ định chạy trên macOS Desktop
flutter run -d macos

# Chỉ định chạy trên iOS Simulator
flutter run -d ios

# Chỉ định chạy trên Chrome
flutter run -d chrome
```

---

### 2. Build Mini App Web Assets

Mỗi khi bạn chỉnh sửa code bên trong thư mục `mini_apps/sdk_playground`:
```bash
cd mini_apps/sdk_playground

# Chạy test độc lập trên trình duyệt ở chế độ dev
npm run dev

# Build bundle để xuất ra assets nạp vào Flutter SuperApp
npm run build
```
*Lưu ý: Đảm bảo thư mục đầu ra của build được copy hoặc cấu hình vào đúng đường dẫn `assets/mini_apps/sdk_playground/` để Flutter load vào WebView.*

---

## ➕ Tạo mới Mini App hoặc mở rộng SDK

1. **Đăng ký Manifest**:
   - Khai báo Mini App mới trong [mini_app_repository.dart](lib/features/mini_app_catalog/data/mini_app_repository.dart) bao gồm `id`, `name`, `entryUrl`, và các `capabilities` được phép gọi.
2. **Thêm Handler Native**:
   - Tạo class Handler mới trong `lib/features/native_actions/handlers/` kế thừa `ActionHandler`.
   - Đăng ký handler mới vào `NativeActionDispatcher`.
3. **Mở rộng SDK**:
   - Thêm module tương ứng trong `mini_apps/sdk_playground/src/sdk/modules/`.
   - Cung cấp Typed Interface cho các Mini App khác dễ dàng tích hợp.
