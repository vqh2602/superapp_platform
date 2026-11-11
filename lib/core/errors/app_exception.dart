// Định nghĩa các ngoại lệ nghiệp vụ và tầng ứng dụng (Application Exceptions).
//
// Cung cấp cây phân cấp ngoại lệ chuẩn xác cho lỗi xác thực, hết hạn phiên đăng nhập,
// và thiếu quyền truy cập hệ thống.

/// Lớp ngoại lệ cơ sở của toàn bộ ứng dụng SuperApp
class AppException implements Exception {
  /// Thông điệp mô tả lỗi
  final String message;
  /// Mã lỗi nghiệp vụ (nếu có)
  final String? code;
  /// Nguyên nhân gốc gây ra lỗi (nested exception)
  final dynamic cause;

  const AppException(this.message, {this.code, this.cause});

  @override
  String toString() => 'AppException: $message (code: $code)';
}

/// Ngoại lệ liên quan đến xác thực người dùng (đăng nhập thất bại, sai mật khẩu, v.v.)
class AuthException extends AppException {
  const AuthException(super.message, {super.code, super.cause});
}

/// Ngoại lệ khi phiên làm việc của người dùng đã hết hạn (Access Token hết hạn và không thể refresh)
class SessionExpiredException extends AuthException {
  const SessionExpiredException([super.message = 'Session has expired'])
      : super(code: 'SESSION_EXPIRED');
}

/// Ngoại lệ khi quyền hạn hệ thống hoặc capability bị từ chối
class PermissionException extends AppException {
  const PermissionException(super.message, {super.code, super.cause});
}
