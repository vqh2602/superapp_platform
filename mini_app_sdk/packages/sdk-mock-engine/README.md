# @superapp/sdk-mock-engine

Động cơ giả lập môi trường native dành cho nhà phát triển Mini App SuperApp: giả lập người dùng, đăng nhập, token OAuth, số dư ví, thanh toán, lưu trữ cục bộ, thiết bị phần cứng và giao diện.

## 🚀 Tính năng

- **Auth & Token Mock**: Đăng nhập, cấp quyền OAuth scopes (`user.phone`, `user.email`), cấp mã `authCode`, `accessToken`, tự động hết hạn và làm mới token.
- **Payment & Wallet Mock**: Giả lập ví SuperApp, kiểm tra số dư, trừ tiền, tạo mã giao dịch (`transactionId`), hỗ trợ chế độ xác nhận thanh toán thủ công (Manual Decision Resolver) trên Simulator.
- **Device & Hardware Mock**: Giả lập mức pin, sạc, mạng (WiFi/4G/5G/Offline), rung haptic, thông tin hệ điều hành.
- **Storage Isolation Mock**: Giả lập kho lưu trữ theo `appId` bảo mật và cách ly.
- **Mock Personas**: Cung cấp sẵn các tài khoản mẫu: VIP Diamond, Khách hàng chuẩn, Tài khoản số dư thấp, Khách vãng lai.
- **Realtime Tracing & Log History**: Theo dõi toàn bộ luồng gọi bridge với thời gian thực thi (latency ms), trạng thái thành công/thất bại và payload chi tiết.

## 📦 Cài đặt & Sử dụng

```typescript
import { SDKMockEngine } from '@superapp/sdk-mock-engine';

const engine = new SDKMockEngine({
  autoApprovePayment: true,
  simulatedLatencyMs: 50,
});

// Chuyển đổi persona
engine.store.setUserPreset('vip');

// Giả lập cuộc gọi bridge
const response = await engine.dispatch({
  id: 'req_1',
  action: 'auth.getUserProfile',
  payload: {},
  appId: 'my_app',
  timestamp: Date.now(),
});

console.log(response.data);
```
