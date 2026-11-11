/// Mô hình thông tin hồ sơ người dùng (User Profile Model).
///
/// Chứa các thuộc tính cá nhân của người dùng bao gồm mã ID, họ tên, số điện thoại,
/// vai trò, email và ảnh đại diện phục vụ hiển thị trên Native Profile và cung cấp qua Bridge.
class UserProfileModel {
  /// Mã định danh người dùng
  final String id;
  /// Họ tên hiển thị
  final String name;
  /// Số điện thoại
  final String phone;
  /// Vai trò tài khoản
  final String role;
  /// Địa chỉ email
  final String email;
  /// Đường dẫn URL ảnh đại diện
  final String? avatarUrl;

  const UserProfileModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    required this.email,
    this.avatarUrl,
  });

  /// Chuyển đổi thành Map JSON
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'role': role,
    'email': email,
    'avatarUrl': avatarUrl,
  };
}
