# SuperApp Mini App Developer SDK Ecosystem

Hệ sinh thái bộ công cụ SDK, Bridge Transport, Mock Engine, CLI và Browser Simulator dành riêng cho các nhà phát triển thứ ba (3rd-party developers) xây dựng, kiểm thử và xuất bản Mini App trên nền tảng SuperApp.

---

## 🏗️ 1. Kiến Trúc Hợp Nhất (All-in-One Package: `@vqh2602/mini-app-sdk`)

Toàn bộ hệ thống SDK, Mock Engine, Bridge Transport, CLI và Browser Simulator đã được hợp nhất vào **1 gói npm duy nhất**:

| Khối chức năng | Thư mục source | Vai trò & Trách nhiệm |
| :--- | :--- | :--- |
| **Mini App Core SDK** | `src/core/` | Bộ API chính thức cho bên thứ ba (`npm install @vqh2602/mini-app-sdk`): `auth`, `payment`, `device`, `storage`, `ui`, `media`, `lifecycle`. |
| **Bridge Transport** | `src/transport/` | Lớp trừu tượng hoá Bridge: chuyển đổi linh hoạt giữa Flutter WebView Native (`FlutterBridge`), PostMessage trong iframe Simulator, hoặc Mock cục bộ. |
| **SDK Mock Engine** | `src/mock/` | Động cơ giả lập Native: sinh mã `authCode`, cấp `accessToken`, hồ sơ người dùng, quản lý số dư ví, trừ tiền thanh toán, giả lập pin, mạng, độ trễ và lưu trữ cách ly. |
| **Mini App CLI** | `src/cli/` & `bin/` | Công cụ dòng lệnh: `create` (tạo dự án mẫu), `dev` (khởi chạy dev server + simulator), `build` (biên dịch + checksum), `upload` (gửi lên Registry), `simulator`. |
| **Browser Simulator** | `simulator/` & `simulator-dist/` | Giao diện web giả lập điện thoại đã được build sẵn tĩnh, tích hợp trực tiếp vào lệnh `miniapp dev` và `miniapp simulator`. |

---

## ⚡ 2. Hướng Dẫn Vận Hành Cho Nhà Phát Triển (Quickstart)

### Bước 1: Khởi tạo Mini App mới bằng CLI
Lập trình viên bên thứ ba có thể chạy trực tiếp thông qua `npx`:
```bash
npx @vqh2602/mini-app-sdk create my_awesome_app
```
Hoặc nếu đã cài đặt toàn cục (`npm install -g @vqh2602/mini-app-sdk`):
```bash
miniapp create my_awesome_app
```
Lệnh này sẽ tự động sinh:
- `app.json`: Manifest khai báo `appId`, `name`, `version`, `permissions`, `themeColor`.
- `package.json`: Cài đặt sẵn `@vqh2602/mini-app-sdk`.
- `src/main.ts`: Code mẫu gọi các hàm đăng nhập, thanh toán, pin, toast.
- `index.html` & `vite.config.ts`.

### Bước 2: Chạy Dev Server & Browser Simulator đồng thời
```bash
cd my_awesome_app
npx miniapp dev
```
Lệnh `miniapp dev` sẽ khởi chạy cả:
* Vite dev server của Mini App (Port 3000)
* Browser Simulator tích hợp sẵn (Port 5175 tại `http://localhost:5175/?url=http://localhost:3000`)

### Bước 3: Đóng gói và xuất bản Mini App
```bash
# Đóng gói và kiểm tra checksum
npx miniapp build

# Tải lên SuperApp Dynamic Registry và gửi xét duyệt
npx miniapp upload --submit --notes "Phát hành phiên bản 1.0.0"
```

---

## 📖 3. Bảng Tra Cứu API Mini App SDK (`@vqh2602/mini-app-sdk`)

### 🔐 3.1. Xác thực & Người dùng (`superApp.auth`)
```typescript
import superApp from '@vqh2602/mini-app-sdk';

// Đăng nhập và xin cấp quyền profile + phone
const loginRes = await superApp.auth.login({
  scopes: ['user.profile', 'user.phone'],
});
console.log('User Name:', loginRes.user.name);
console.log('Access Token:', loginRes.accessToken);

// Lấy thông tin người dùng hiện tại
const profile = await superApp.auth.getUserProfile();

// Lấy Access Token
const token = await superApp.auth.getAccessToken();

// Đăng xuất
await superApp.auth.logout();
```

### 💳 3.2. Thanh toán SuperApp Pay (`superApp.payment`)
```typescript
try {
  const result = await superApp.payment.requestPayment({
    orderId: 'ORDER_2026_001',
    amount: 150000,
    description: 'Thanh toán Combo Cơm Trưa',
  });
  
  if (result.status === 'SUCCESS') {
    await superApp.ui.showToast('Thanh toán thành công qua Ví SuperApp!');
  }
} catch (error: any) {
  if (error.code === 'INSUFFICIENT_FUNDS') {
    await superApp.ui.showAlert({ title: 'Lỗi', message: 'Số dư ví không đủ' });
  } else if (error.code === 'USER_CANCELLED') {
    await superApp.ui.showToast('Bạn đã huỷ thanh toán');
  }
}
```

### 📱 3.3. Thiết bị & Phần cứng (`superApp.device`)
```typescript
// Mức pin và trạng thái sạc
const battery = await superApp.device.getBatteryInfo();
console.log(`Pin: ${battery.batteryLevel}%, Đang sạc: ${battery.isCharging}`);

// Trạng thái mạng
const network = await superApp.device.getNetworkInfo();
console.log(`Kết nối: ${network.networkType}, WiFi: ${network.isWifi}`);

// Rung xúc giác haptic feedback
await superApp.device.vibrate('light'); // 'light' | 'medium' | 'heavy'
```

### 💾 3.4. Lưu trữ cách ly (`superApp.storage`)
```typescript
// Ghi dữ liệu
await superApp.storage.setItem('user_cart', { items: [{ id: 1, name: 'Trà Sữa' }] });

// Đọc dữ liệu (Tự động deserialize JSON)
const cart = await superApp.storage.getItem('user_cart');

// Xoá key
await superApp.storage.removeItem('user_cart');
```

### 🔔 3.5. Giao diện & Điều hướng (`superApp.ui` / `superApp.navigation`)
```typescript
// Toast
await superApp.ui.showToast('Cập nhật thành công!');

// Alert Dialog
await superApp.ui.showAlert({ title: 'Chúc mừng', message: 'Nhận được voucher 50%' });

// Confirm Dialog
const agreed = await superApp.ui.showConfirm({
  title: 'Xoá giỏ hàng',
  message: 'Bạn có chắc chắn muốn làm trống giỏ hàng?',
});

// Đặt tiêu đề thanh điều hướng
await superApp.ui.setNavigationBarTitle('Menu Quán Cà Phê');

// Đóng Mini App về màn hình chính SuperApp
await superApp.closeApp();
```

### 🔄 3.6. Vòng đời ứng dụng (`superApp.lifecycle`)
```typescript
// Bắt sự kiện khi app ra màn hình (Foreground)
superApp.lifecycle.onAppShow(() => {
  console.log('Mini App hiển thị trở lại');
});

// Bắt sự kiện khi app bị ẩn xuống nền (Background)
superApp.lifecycle.onAppHide(() => {
  console.log('Mini App tạm dừng');
});
```

---

## 🧩 4. Sub-path Exports Nâng Cao

Ngoài entrypoint mặc định `superApp`, package cung cấp các sub-path để lập trình viên tùy biến sâu:

```typescript
// 1. Tầng Transport Bridge
import {
  TransportResolver,
  NativeBridgeTransport,
  PostMessageTransport,
  MockBridgeTransport,
} from '@vqh2602/mini-app-sdk/transport';

// 2. Động cơ Mock Engine & Dữ liệu mẫu
import {
  SDKMockEngine,
  MockStateStore,
  MOCK_USER_PRESETS,
} from '@vqh2602/mini-app-sdk/mock';
```

---

## 🛠️ 5. Dành Cho Quản Trị Viên (Maintainer Guide)

### Biên dịch & Kiểm tra gói đóng gói
```bash
cd mini_app_sdk

# Cài đặt dependencies
npm install

# Biên dịch Phone Simulator + TypeScript SDK
npm run build

# Chạy Phone Simulator cục bộ
npm run simulator

# Kiểm tra nội dung đóng gói trước khi xuất bản (Dry Run)
npm pack --dry-run
```

### Phát hành phiên bản mới lên npm Public Registry
```bash
# Xuất bản trực tiếp lên npm
npm publish --access public
```

### Kiểm tra transport và ví dụ

Chạy `npm test` trong `mini_app_sdk` để kiểm tra native callbacks, JS gọi trực tiếp dùng chung bridge, nhiều SDK instance, lifecycle events, simulator, browser mock, bridge được gắn muộn và timeout. SDK giữ nguyên callback registry `_callbacks` của host; không thay global bridge bằng dispatcher riêng. Playground sử dụng transport chính thức cho native và simulator.

Sau khi sửa SDK trong repository, chạy `npm run build:miniapps` từ thư mục gốc để build và đồng bộ SDK vào các ví dụ trước khi deploy backend. Lệnh này không phát hành package lên npm.
