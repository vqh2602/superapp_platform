/// Mô hình người dùng nền tảng SuperApp (Platform User).
///
/// Chứa thông tin hồ sơ tài khoản (id, họ tên, số điện thoại, vai trò, email và avatar),
/// cung cấp các phương thức trích xuất dữ liệu cơ bản (Basic Info) hoặc đầy đủ (Full Profile)
/// để trả về cho Mini App tùy theo quyền hạn được cấp.
class PlatformUser {
  /// Mã định danh duy nhất của người dùng
  final String id;

  /// Họ tên hiển thị của người dùng
  final String name;

  /// Số điện thoại đã xác minh
  final String phone;

  /// Vai trò tài khoản (vd: 'admin', 'developer', 'customer')
  final String role;

  /// Địa chỉ email
  final String email;

  /// Đường dẫn ảnh đại diện (avatar)
  final String? avatarUrl;

  const PlatformUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    required this.email,
    this.avatarUrl,
  });

  /// Khởi tạo [PlatformUser] từ dữ liệu JSON của máy chủ Backend
  factory PlatformUser.fromBackendJson(Map<String, dynamic> json) {
    return PlatformUser(
      id: json['id'] as String? ?? '',
      name: (json['displayName'] ?? json['name'] ?? '') as String,
      phone: (json['phone'] ?? '') as String,
      role: (json['role'] ?? 'customer') as String,
      email: (json['email'] ?? '') as String,
      avatarUrl: (json['avatarUrl'] as String?)?.isNotEmpty == true
          ? json['avatarUrl'] as String
          : null,
    );
  }

  /// Trích xuất thông tin cơ bản công khai (dành cho action `user.getBasicInfo`)
  Map<String, dynamic> toBasicInfoJson() => {
    'id': id,
    'name': name,
    'avatarUrl': avatarUrl,
  };

  /// Trích xuất toàn bộ hồ sơ chi tiết (dành cho action `user.getProfile`)
  Map<String, dynamic> toFullProfileJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'role': role,
    'email': email,
    'avatarUrl': avatarUrl,
  };
}
