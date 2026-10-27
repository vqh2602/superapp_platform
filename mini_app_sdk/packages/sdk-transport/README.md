# @superapp/sdk-transport

Package hạ tầng cung cấp lớp trừu tượng hoá kết nối Bridge (`ITransport`) giữa Mini App và môi trường thực thi (Native Flutter WebView, Browser Simulator qua `postMessage`, hoặc Mock Engine cho Unit Tests).

## 🚀 Tính năng

- **Native Bridge Transport**: Kết nối trực tiếp với `window.FlutterBridge` trên Super App Flutter WebView.
- **PostMessage Transport**: Kết nối hai chiều với Browser Simulator khi Mini App chạy trong iframe.
- **Mock Transport**: Định tuyến trực tiếp đến `SDKMockEngine` cho môi trường kiểm thử hoặc dev độc lập.
- **Transport Resolver**: Tự động nhận diện ngữ cảnh thực thi (Native App vs. Simulator iframe vs. Standalone Browser).
- Hỗ trợ Request-Response Correlation (`req_id`), Timeout xử lý, Error Normalization và Push Event Listener.

## 📦 Cài đặt

```bash
npm install @superapp/sdk-transport
```

## 💡 Ví dụ sử dụng

```typescript
import { TransportResolver } from '@superapp/sdk-transport';

// Tự động nhận diện môi trường phù hợp
const transport = TransportResolver.resolve({
  appId: 'my_store',
  debug: true,
  timeoutMs: 8000,
});

// Gọi một bridge action
const user = await transport.invoke('auth.getUserProfile');

// Lắng nghe sự kiện native đẩy xuống
transport.on('appShow', (data) => {
  console.log('Mini App foregrounded:', data);
});
```
