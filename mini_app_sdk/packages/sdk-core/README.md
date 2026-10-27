# @superapp/mini-app-sdk

Bộ TypeScript SDK chính thức dành cho các nhà phát triển thứ ba xây dựng ứng dụng nhỏ (Mini App) trên nền tảng SuperApp.

## 🚀 Tính năng nổi bật

- **100% TypeScript**: Định kiểu rõ ràng, tự động gợi ý code (IntelliSense) cho mọi hàm và tham số.
- **Tự động chuyển đổi môi trường**: Chạy mượt mà trên cả Flutter WebView thật, trong iframe Browser Simulator, hay độc lập (Mock Engine tự động).
- **Hỗ trợ đầy đủ nghiệp vụ SuperApp**:
  - `auth`: Đăng nhập, cấp quyền OAuth, lấy User Profile, quản lý token.
  - `payment`: Tích hợp thanh toán trực tiếp qua ví SuperApp.
  - `device`: Pin, thông tin mạng, rung xúc giác haptic feedback, thông số màn hình.
  - `storage`: Lưu trữ key-value cách ly và an toàn theo từng Mini App.
  - `ui`: Toast thông báo, Alert, Confirm, đổi tiêu đề thanh điều hướng.
  - `media`: Quét QR code camera, chọn ảnh.
  - `lifecycle`: Bắt sự kiện app vào nền (Background) hoặc ra màn hình (Foreground).

## 📦 Cài đặt

```bash
npm install @superapp/mini-app-sdk
```

## 💡 Hướng dẫn nhanh (Quickstart)

```typescript
import superApp from '@superapp/mini-app-sdk';

// 1. Đăng nhập người dùng
const authData = await superApp.auth.login({
  scopes: ['user.profile', 'user.phone'],
});
console.log('Xin chào:', authData.user.name);

// 2. Gọi thanh toán đơn hàng
try {
  const result = await superApp.payment.requestPayment({
    orderId: 'ORDER_12345',
    amount: 50000,
    description: 'Thanh toán cà phê sữa đá',
  });
  
  if (result.status === 'SUCCESS') {
    await superApp.ui.showToast('Thanh toán thành công!');
  }
} catch (error) {
  await superApp.ui.showToast('Giao dịch thất bại');
}

// 3. Đọc ghi bộ nhớ cục bộ
await superApp.storage.setItem('user_cart', { items: 2, total: 50000 });
const cart = await superApp.storage.getItem('user_cart');

// 4. Lắng nghe trạng thái ứng dụng
superApp.lifecycle.onAppShow(() => {
  console.log('Mini App hiển thị trở lại');
});
```
