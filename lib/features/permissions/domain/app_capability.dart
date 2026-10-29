enum AppCapability {
  authRequestCode('auth.requestCode', 'Yêu cầu mã xác thực đăng nhập', 'Cho phép Mini App nhận authCode để đăng nhập'),
  userGetProfile('user.getProfile', 'Truy cập thông tin cá nhân', 'Cho phép xem họ tên, số điện thoại, email'),
  userGetBasicInfo('user.getBasicInfo', 'Truy cập thông tin cơ bản', 'Cho phép xem tên hiển thị và ảnh đại diện'),
  navigationOpenPage('navigation.openNativePage', 'Điều hướng trang hệ thống', 'Cho phép mở màn hình Flutter'),
  deviceScanQr('device.scanQRCode', 'Quét mã QR', 'Cho phép dùng camera/mô phỏng quét mã QR'),
  deviceGetLocation('device.getLocation', 'Truy cập vị trí GPS', 'Cho phép truy cập tọa độ thiết bị'),
  devicePickImage('device.pickImage', 'Chọn ảnh thư viện', 'Cho phép chọn ảnh từ thư viện thiết bị'),
  storageSecure('storage.secure', 'Lưu trữ bảo mật', 'Cho phép lưu và đọc khóa giá trị an toàn trong Keychain/Keystore'),
  permissionGetPermissions('permission.getPermissions', 'Lấy danh sách quyền', 'Lấy danh sách quyền đã được cấp cho Mini App'),
  microphone('microphone', 'Truy cập micro ghi âm', 'Cho phép chuyển giọng nói thành văn bản'),
  notification('notification', 'Gửi thông báo', 'Cho phép Mini App gửi thông báo và tin tức quan trọng');

  final String key;
  final String title;
  final String description;

  const AppCapability(this.key, this.title, this.description);

  static AppCapability? fromKey(String key) {
    try {
      return AppCapability.values.firstWhere((c) => c.key == key);
    } catch (_) {
      return null;
    }
  }
}
