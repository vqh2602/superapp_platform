# Mini App release samples

- `web-demo/`: App ID `web_demo`, runtime `web`, entry `dist/index.html` (Mẫu SPA / React / Vanilla).
- `flutter-web-demo/`: App ID `flutter_web_demo`, runtime `web`, entry `dist/index.html` (Mẫu ứng dụng biên dịch từ Flutter Web với Dart 3 JS Interop).
- `schema-demo/`: App ID `schema_demo`, runtime `schema`, entry `schema.json` (Mẫu No-Code thuần JSON).

Xem [chuẩn gói Super App v1](../../docs/miniapp-package.md) và [Hướng dẫn chi tiết SDK & Tích hợp](../../docs/sdk.md). Đổi App ID/version/metadata trong app.json nếu dùng mẫu cho ứng dụng khác.

Từ backend, sau `npm install` và `npm run build`:

```sh
npm run package:miniapp -- ../examples/miniapps/web-demo ../builder/public/examples/web-demo.zip
npm run package:miniapp -- ../examples/miniapps/flutter-web-demo ../builder/public/examples/flutter-web-demo.zip
npm run package:miniapp -- ../examples/miniapps/schema-demo ../builder/public/examples/schema-demo.zip
```

ZIP mẫu tải được trong Manager. Các file trong `web-demo/dist` là ví dụ release đã build, dùng đường dẫn tương đối; backend nhận và phục vụ nguyên nội dung đó.
