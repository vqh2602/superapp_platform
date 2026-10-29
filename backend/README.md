# Super App Backend

NestJS + PostgreSQL: quản lý gói/phiên bản Mini App, catalog, user, đăng nhập/token, consent theo user/app và đơn hàng/thanh toán.

- **API Cục bộ (Local)**: `http://localhost:3000/api/v1`
- **API Cloud (Alwaysdata Live)**: `https://superappplatfrom.alwaysdata.net/api/v1`
- [Chi tiết API và kiến trúc backend](../docs/backend.md)
- [Hướng dẫn Deploy lên Alwaysdata](../docs/alwaysdata-deployment.md)
- [Đăng ký/đăng nhập, token và luồng Mini App](../docs/authentication.md)
- [Chuẩn ZIP Mini App v1](../docs/miniapp-package.md)
- [Hướng dẫn Manager / Builder](../docs/platform-guide.md)

---

## 1. Chạy cục bộ (Local Development)

```sh
createdb superapp_registry
npm install
npm run build
npm run start:dev     # Chạy môi trường phát triển (ts-node)
# hoặc
npm run start:prod    # Chạy sản xuất từ bản build dist/
```

- Ứng dụng tự động nạp cấu hình từ file `.env` (thông qua `dotenv` với `override: true`).
- TypeORM tự động khởi tạo bảng dữ liệu (`synchronize: true`).
- Dữ liệu mẫu (Shopee, TikTok, Messenger, ...) và **Tài khoản test** (`test_demo@example.com` / `demo-password-123`) được tự động seed khi backend khởi động lần đầu.
- Đăng ký thêm tài khoản qua `POST /api/v1/auth/register` (body: `{ "email", "password", "displayName" }`).

---

## 2. Deploy tự động lên Alwaysdata (1-Click)

Backend hỗ trợ script tự động build và upload lên máy chủ Alwaysdata:

```sh
npm run deploy:alwaysdata
```

Script này thực hiện:
1. Build TypeScript sang `dist/`
2. Đóng gói release bundle
3. Đẩy lên Alwaysdata qua SSH/SCP
4. Cài đặt production packages và cấu hình `.env` bảo mật trên server
5. Khởi động lại service và tự động kiểm tra Health check endpoint

Xem chi tiết cấu hình tài khoản và database trong [docs/alwaysdata-deployment.md](../docs/alwaysdata-deployment.md).

---

## 3. Kiểm thử (Testing)

```sh
npm test -- --runInBand
npm run build
npm run test:packages:db
npm run test:auth:db
```

Smoke test dùng database/thư mục tạm riêng, cần PostgreSQL với quyền tạo database.
