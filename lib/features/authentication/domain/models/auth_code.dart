/// Mô hình mã xác thực tạm thời dùng một lần (Authorization Code) cho Mini App.
///
/// Hoạt động theo mô hình OAuth2 / PKCE: Mini App xin cấp mã xác thực từ Native Shell,
/// sau đó đổi mã này lấy Access Token để gọi các API an toàn từ Backend.
class AuthCode {
  /// Chuỗi mã xác thực (vd: 'auth_code_...')
  final String code;

  /// Định danh người dùng cấp quyền
  final String userId;

  /// Định danh Mini App được cấp mã
  final String appId;

  /// Thời điểm tạo mã
  final DateTime createdAt;

  /// Thời điểm mã hết hiệu lực
  final DateTime expiresAt;

  /// Trạng thái mã đã qua sử dụng hay chưa (chống replay attack)
  bool isUsed;

  AuthCode({
    required this.code,
    required this.userId,
    required this.appId,
    required this.createdAt,
    required this.expiresAt,
    this.isUsed = false,
  });

  /// Kiểm tra mã xác thực còn hiệu lực (chưa bị dùng và chưa hết hạn)
  bool get isValid => !isUsed && DateTime.now().isBefore(expiresAt);
}
