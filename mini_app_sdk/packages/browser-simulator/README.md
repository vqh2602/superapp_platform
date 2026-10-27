# @superapp/browser-simulator

Môi trường giả lập Browser Simulator và bộ công cụ DevTools dành cho nhà phát triển Mini App chạy trên React 18 + Vite.

## 🚀 Tính năng nổi bật

- **Khung thiết bị di động chuẩn xác (Device Frames)**:
  - Giả lập iPhone 15 Pro (Dynamic Island, góc bo 52px, thanh Home Indicator).
  - Giả lập Android Device (Camera Punch-hole, thanh điều hướng).
  - Tự động đồng bộ Status Bar: Đồng hồ, mức pin, trạng thái sạc, kiểu mạng (5G/WiFi/Offline).
  - Header Capsule Native: Nút Quay lại, Tiêu đề động, Tải lại (`⟳`), Menu (`...`), Đóng (`✕`).
- **DevTools Drawer thông minh**:
  - **Bridge Inspector**: Giám sát từng cuộc gọi bridge theo thời gian thực (Request payload, Response JSON, thời gian xử lý ms, trạng thái).
  - **Auth & Persona Manager**: Chuyển đổi nhanh giữa các tài khoản mẫu (VIP Diamond, Chuẩn, Thiếu tiền, Khách vãng lai), cấp lại token OAuth, kiểm tra hạn dùng.
  - **Payment & Wallet Controller**: Quản lý số dư ví thử nghiệm, nạp tiền 1 chạm (+100k, +500k, +2M), bật popup xác nhận thanh toán thủ công (Simulated Bottom Sheet).
  - **Device & Environment**: Thay đổi mức pin, cắm sạc, đổi profile mạng (WiFi, 5G, 4G, 2G, Offline), bơm độ trễ nhân tạo (Latency injection), phát sự kiện vòng đời (`appShow`, `appHide`).
  - **Storage Manager**: Trực quan hoá key-value bộ nhớ cục bộ của Mini App, thêm/sửa/xoá nhanh.

## 📦 Khởi chạy Simulator

```bash
# Khởi chạy trên cổng 5175
npm run simulator
```

Mở trình duyệt tại:
```
http://localhost:5175/?url=http://localhost:3000
```
(Có thể đổi `?url=` thành bất kỳ địa chỉ dev server hoặc Mini App nào đang chạy).
