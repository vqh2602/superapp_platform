# Đồng bộ tài liệu khi cập nhật SuperApp

Áp dụng cho toàn bộ repository. Với mỗi thay đổi, xem diff và đối chiếu các phần tài liệu, ví dụ liên quan với mã nguồn, hợp đồng API, cấu hình và test hiện hành. Sửa thông tin bị ảnh hưởng trong cùng thay đổi. Nếu phần liên quan vẫn chính xác, giữ nguyên nội dung.

- Giữ `README.md` ở mức tổng quan, hướng dẫn bắt đầu và liên kết tới tài liệu chi tiết.
- Cập nhật `docs/superapp.md` cho Flutter Host, hành vi native, cấu hình nền tảng và các action Bridge.
- Cập nhật `docs/sdk.md` cho API mà Mini App gọi. Đối chiếu thêm `mini_app_sdk/README.md` và ví dụ trong `mini_apps/` nếu cách tích hợp thay đổi.
- Cập nhật tài liệu tương ứng trong `docs/` cho Backend, xác thực, đóng gói Mini App và triển khai. Giữ hướng dẫn và lệnh khớp với cấu hình thực tế.

Khi thêm, đổi hoặc gỡ API, kiểm tra tên action, tham số, kết quả, mã lỗi, quyền, nền tảng hỗ trợ và phiên bản yêu cầu ở các phần tài liệu liên quan. Trước khi hoàn tất, đọc lại diff tài liệu, kiểm tra liên kết nội bộ và xác minh ví dụ theo hành vi đã triển khai.
