// Giao diện trừu tượng kho dữ liệu xác thực người dùng (Auth Repository Interface).
//
// Định nghĩa các hợp đồng nghiệp vụ cho đăng nhập, đăng ký, đăng xuất,
// lấy phiên làm việc hiện tại và theo dõi luồng thay đổi phiên.
import '../models/platform_user.dart';
import '../models/auth_session.dart';

/// Hợp đồng Repository quản lý xác thực người dùng SuperApp
abstract class AuthRepository {
  /// Phiên làm việc hiện tại của người dùng (null nếu chưa đăng nhập)
  AuthSession? get currentSession;

  /// Thông tin người dùng hiện tại
  PlatformUser? get currentUser;

  /// Kiểm tra trạng thái đã đăng nhập và phiên còn hiệu lực hay không
  bool get isAuthenticated;

  /// Đăng nhập tài khoản bằng email/số điện thoại và mật khẩu
  Future<AuthSession> login(String emailOrUserId, [String? password]);

  /// Đăng ký tài khoản mới trên hệ thống
  Future<AuthSession> register({
    required String email,
    required String password,
    required String displayName,
  });

  /// Đăng xuất khỏi hệ thống và xóa dữ liệu phiên làm việc
  Future<void> logout();

  /// Luồng Stream phát ra các thay đổi về phiên làm việc
  Stream<AuthSession?> get sessionStream;
}
