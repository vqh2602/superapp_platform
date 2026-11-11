/// Định nghĩa danh mục các quyền hạn và năng lực hệ thống (App Capabilities).
///
/// Mỗi capability được gán một định danh chuỗi, tiêu đề và mô tả giải thích
/// để hiển thị cho người dùng khi Mini App yêu cầu cấp quyền.
enum AppCapability {
  authRequestCode('auth.requestCode', 'Yêu cầu mã xác thực đăng nhập', 'Cho phép Mini App nhận authCode để đăng nhập'),
  userGetProfile('user.getProfile', 'Truy cập thông tin cá nhân', 'Cho phép xem họ tên, số điện thoại, email'),
  userGetBasicInfo('user.getBasicInfo', 'Truy cập thông tin cơ bản', 'Cho phép xem tên hiển thị và ảnh đại diện'),
  navigationOpenPage('navigation.openNativePage', 'Điều hướng trang hệ thống', 'Cho phép mở màn hình Flutter'),
  deviceScanQr('device.scanQRCode', 'Quét mã QR', 'Cho phép truy cập camera để quét mã QR và mã vạch'),
  deviceGetLocation('device.getLocation', 'Truy cập vị trí GPS', 'Cho phép truy cập tọa độ thiết bị'),
  devicePickImage('device.pickImage', 'Chọn ảnh thư viện', 'Cho phép chọn ảnh từ thư viện thiết bị'),
  storageSecure('storage.secure', 'Lưu trữ bảo mật', 'Cho phép lưu và đọc khóa giá trị an toàn trong Keychain/Keystore'),
  permissionGetPermissions('permission.getPermissions', 'Lấy danh sách quyền', 'Lấy danh sách quyền đã được cấp cho Mini App'),
  microphone('microphone', 'Truy cập micro ghi âm', 'Cho phép chuyển giọng nói thành văn bản'),
  notification('notification', 'Gửi thông báo', 'Cho phép Mini App gửi thông báo và tin tức quan trọng'),
  authLogin('auth.login', 'Đăng nhập nhanh', 'Cho phép truy cập thông tin tài khoản đăng nhập SuperApp');

  /// Khóa định danh của quyền hạn
  final String key;
  /// Tiêu đề hiển thị thân thiện trên hộp thoại xin quyền
  final String title;
  /// Mô tả chi tiết mục đích sử dụng quyền
  final String description;

  const AppCapability(this.key, this.title, this.description);

  /// Tra cứu [AppCapability] theo chuỗi key (trả về null nếu không khớp)
  static AppCapability? fromKey(String key) {
    try {
      return AppCapability.values.firstWhere((c) => c.key == key);
    } catch (_) {
      return null;
    }
  }
}
