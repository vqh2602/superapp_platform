# Hướng dẫn Deploy Backend lên Alwaysdata (https://admin.alwaysdata.com)

Hệ thống đã được thiết lập sẵn script tự động hóa deployment và quy trình CI/CD cho NestJS Backend lên Alwaysdata.

---

## 0. Môi trường Production Đang Hoạt Động (Live)

- **Địa chỉ Base API**: `https://superappplatfrom.alwaysdata.net/api/v1`
- **Catalog Endpoint**: `https://superappplatfrom.alwaysdata.net/api/v1/catalog/apps`
- **Tài khoản Alwaysdata**: `superappplatfrom`
- **SSH Host**: `superappplatfrom@ssh-superappplatfrom.alwaysdata.net` (Đã nạp SSH Public Key từ máy dev)
- **Thư mục ứng dụng**: `/home/superappplatfrom/superapp-backend`
- **PostgreSQL Database**: `superappplatfrom_superapp_registry` trên `postgresql-superappplatfrom.alwaysdata.net`
- **Command khởi chạy**: `node dist/main.js` (Node.js 24)

---

## 1. Chuẩn bị trên Alwaysdata Admin (Chỉ cần làm 1 lần)

Đăng nhập vào [admin.alwaysdata.com](https://admin.alwaysdata.com):

### Bước 1.1: Tạo Database PostgreSQL
1. Vào menu **Databases** > **PostgreSQL**.
2. Nhấn **Add a database**.
   - **Name**: Nhập tên database (ví dụ: `superapp_registry`).
   - Tạo hoặc gán **User** truy cập database với mật khẩu của bạn.
   - Ghi lại các thông số:
     - **Host**: `postgresql-[tên_account].alwaysdata.net`
     - **Database**: `[tên_account]_[tên_db]`
     - **Username**: `[tên_account]_[tên_user]` (hoặc `[tên_account]`)
     - **Password**: Mật khẩu đã đặt

### Bước 1.2: Tạo Site Node.js
1. Vào menu **Web** > **Sites** > **Add a site**.
2. Thiết lập:
   - **Name**: `SuperApp Backend API`
   - **Addresses**: Chọn domain mặc định `[tên_account].alwaysdata.net` hoặc subdomain tùy chọn.
   - **Type**: Chọn **Node.js**.
   - **Working directory**: `superapp_backend` (tương ứng `/home/[tên_account]/superapp_backend`).
   - **Command**: `node dist/main.js` (hoặc `npm run start:prod`).
   - **Node.js version**: `20.x` hoặc `22.x`.
   - **Hot restart**: Chọn `Restart on touch: tmp/restart.txt` hoặc `SIGHUP`.
3. Nhấn **Submit** để lưu. Lưu lại **Site ID** (hiển thị trên URL hoặc danh sách Sites).

### Bước 1.3: Kích hoạt quyền SSH
1. Vào menu **Remote access** > **SSH**.
2. Đảm bảo user của bạn đang ở trạng thái **Enabled**.
3. Bạn có thể đặt mật khẩu SSH hoặc thêm SSH Public Key máy của bạn (`~/.ssh/id_rsa.pub`) vào mục **Public keys**.
4. (Tùy chọn) Vào **Remote access** > **API keys** > **Add an API key** để lấy API token cho phép script tự động kích hoạt khởi động lại site qua REST API.

---

## 2. Deploy tự động từ máy local (CLI)

### Cách 1: Chạy lệnh trực tiếp với file cấu hình `.env.alwaysdata`

1. Tạo file cấu hình `backend/.env.alwaysdata` từ mẫu:
   ```sh
   cp backend/.env.alwaysdata.example backend/.env.alwaysdata
   ```
2. Điền thông tin tài khoản và database:
   ```env
   ALWAYSDATA_ACCOUNT=ten_account_cua_ban
   ALWAYSDATA_API_KEY=your_alwaysdata_api_key_neu_co
   ALWAYSDATA_SITE_ID=your_site_id_neu_co
   DB_HOST=postgresql-ten_account_cua_ban.alwaysdata.net
   DB_PORT=5432
   DB_USERNAME=ten_account_cua_ban_db_user
   DB_PASSWORD=mat_khau_db
   DB_DATABASE=ten_account_cua_ban_superapp_registry
   ```
3. Chạy lệnh deploy tự động:
   ```sh
   cd backend
   npm run deploy:alwaysdata
   ```

Script sẽ tự động:
- Build SDK và ba miniapp hệ thống (`sdk_playground`, `schema_runtime`, `sample_store`) vào `backend/seed-bundles/`, rồi build NestJS (`dist/`)
- Đóng gói file cần thiết (`dist`, `seed-bundles`, `package.json`, `package-lock.json`); không đóng gói storage upload của người dùng
- SCP lên máy chủ Alwaysdata
- Giải nén, thiết lập `.env` bảo mật và cài đặt `node_modules`
- Tự động restart site và kiểm tra HTTP Health check API.

---

## 3. Deploy tự động qua GitHub Actions (CI/CD)

Nếu dự án dùng Git repository trên GitHub, mỗi lần push lên nhánh `main` (hoặc kích hoạt thủ công qua tab **Actions**):

Cấu hình các Secrets trong GitHub Repository (**Settings** > **Secrets and variables** > **Actions**):
- `ALWAYSDATA_SSH_HOST`: `ssh-[account].alwaysdata.net`
- `ALWAYSDATA_SSH_USER`: `[account]`
- `ALWAYSDATA_SSH_KEY`: Nội dung SSH Private Key của bạn
- `ALWAYSDATA_API_KEY`: API key từ Alwaysdata
- `ALWAYSDATA_SITE_ID`: ID Site từ Alwaysdata

Workflow sẽ tự động build và deploy lên Alwaysdata.

### Kiểm tra bundle miniapp sau deploy

Release backend phải chứa `seed-bundles/<appId>/dist/index.html` và icon. Seed so sánh HTML đang lưu với bản build đi kèm và cập nhật package key khi khác nhau, kể cả các gói giữ chỗ cũ chỉ có dòng `sdk_playground loaded`. Thiếu bản build sẽ dừng bootstrap và báo lỗi thay vì tạo HTML giữ chỗ.

Kiểm tra `GET /api/v1/miniapps/sdk_playground/1.0.5/dist/index.html`: nội dung phải chứa bundle JavaScript của Playground, không chỉ dòng `loaded`. Tương tự với `schema_runtime` và `sample_store`.
