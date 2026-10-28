# Flutter Web Mini App Sample

Mẫu ứng dụng Mini App được xây dựng bằng **Flutter Web** và tích hợp trực tiếp vào **SuperApp Platform** thông qua cơ chế Dart JS Interop.

## 📁 Cấu trúc thư mục

```text
flutter-web-demo/
├── app.json                    # Manifest SuperApp v1 (runtimeType: "web")
├── icon.png                    # Icon hiển thị trên SuperApp Catalog
├── lib/
│   ├── main.dart               # UI Flutter (Material 3)
│   └── superapp_bridge_client.dart # Thư viện cầu nối Dart 3 ↔ JS Bridge
├── web/
│   └── index.html              # HTML template với base href="./"
└── dist/                       # Thư mục chứa gói web sau khi build
    └── index.html
```

## 🚀 Các bước xây dựng và đóng gói

1. **Khởi tạo và chạy thử cục bộ:**
   ```bash
   flutter run -d chrome
   ```

2. **Biên dịch Flutter Web:**
   > **Lưu ý quan trọng**: Phải luôn có `--base-href="./"` để nạp tài nguyên đường dẫn tương đối trong WebView:
   ```bash
   flutter build web --release --base-href="./" --web-renderer html
   ```

3. **Sao chép sản phẩm build vào `dist/`:**
   ```bash
   cp -R build/web/* dist/
   ```

4. **Đóng gói thành tệp ZIP chuẩn SuperApp v1:**
   ```bash
   cd ../../../backend
   npm run package:miniapp -- ../examples/miniapps/flutter-web-demo ../flutter_web_demo-1.0.0.zip
   ```

5. **Upload lên SuperApp:**
   - Đăng nhập vào trang Quản lý SuperApp Manager (`http://localhost:5174`).
   - Tạo Mini App với App ID: `flutter_web_demo`, runtime: `web`.
   - Chọn tệp ZIP vừa đóng gói để upload và kích hoạt các quyền `permissions`.
