# Super App Backend

NestJS + PostgreSQL: quản lý gói/phiên bản Mini App, catalog, user, đăng nhập/token và consent theo user/app.

- [API và kiến trúc backend](../docs/backend.md)
- [Đăng ký/đăng nhập, token và luồng Mini App](../docs/authentication.md)
- [Chuẩn ZIP Mini App v1](../docs/miniapp-package.md)
- [Hướng dẫn Manager](../docs/platform-guide.md)

```sh
createdb superapp_registry
npm install
npm run build
npm run start:prod
```

API: `http://localhost:3000/api/v1`. Đăng ký qua `POST /auth/register`; không có user/mật khẩu mặc định. `start:dev` chạy ts-node, cần khởi động lại sau khi sửa code.

```sh
npm test -- --runInBand
npm run build
npm run test:packages:db
npm run test:auth:db
```

Smoke test dùng database/thư mục tạm riêng, cần PostgreSQL với quyền tạo database. Flutter/SDK vẫn dùng auth/permission mock cho tới khi client được nối sang API; các endpoint backend đã sẵn sàng.
