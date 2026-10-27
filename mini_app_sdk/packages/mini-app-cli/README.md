# @superapp/mini-app-cli

Công cụ dòng lệnh (CLI) chính thức hỗ trợ nhà phát triển thứ ba phát triển, chạy thử nghiệm, đóng gói và xuất bản Mini App lên nền tảng SuperApp.

## 🚀 Các lệnh hỗ trợ

### 1. Khởi tạo dự án mới (`create`)
```bash
miniapp create coffee_shop
```
Tạo một dự án đầy đủ với:
- `app.json`: Manifest định danh, quyền hạn (`permissions`), giao diện.
- `package.json`: Cài đặt sẵn `@superapp/mini-app-sdk`.
- `src/main.ts`: Code mẫu tích hợp đăng nhập, thanh toán, kiểm tra pin, haptic feedback.
- `vite.config.ts` & `tsconfig.json`.

### 2. Chạy thử nghiệm cục bộ (`dev`)
```bash
miniapp dev --port 3000
```
Khởi động máy chủ dev Vite và hiển thị liên kết mở Browser Simulator.

### 3. Đóng gói sản phẩm (`build`)
```bash
miniapp build
```
Biên dịch TypeScript, kiểm tra cấu hình `app.json`, xác thực tính toàn vẹn và tạo file `bundle-meta.json` kèm mã băm SHA-256.

### 4. Tải lên và gửi xét duyệt (`upload`)
```bash
# Tải lên bản nháp (Draft)
miniapp upload

# Hoặc tải lên và gửi xét duyệt ngay lên SuperApp Moderation Queue
miniapp upload --submit --notes "Phát hành tính năng thanh toán vé concert"
```

### 5. Kiểm tra môi trường (`doctor`)
```bash
miniapp doctor
```
Kiểm tra phiên bản Node.js, tính hợp lệ của manifest và tình trạng kết nối đến Backend Registry.
