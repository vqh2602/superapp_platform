// Mô hình phiên làm việc và đăng nhập (Auth Session) của người dùng trên SuperApp.
//
// Quản lý thông tin hồ sơ tài khoản [PlatformUser], cặp khóa token (AccessToken & RefreshToken)
// và thời điểm hết hạn để thực hiện tự động làm mới hoặc buộc đăng nhập lại.
import 'platform_user.dart';

/// Đại diện phiên xác thực của người dùng đang hoạt động
class AuthSession {
  /// Thông tin người dùng của phiên
  final PlatformUser user;

  /// Access Token JWT dùng để xác thực request API
  final String accessToken;

  /// Refresh Token dùng để cấp lại Access Token mới khi hết hạn
  final String refreshToken;

  /// Thời điểm hết hạn của Access Token
  final DateTime expiresAt;

  const AuthSession({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  /// Kiểm tra Access Token của phiên đã hết hạn hay chưa
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Khởi tạo [AuthSession] từ payload JSON phản hồi của máy chủ Backend
  factory AuthSession.fromBackendJson(Map<String, dynamic> json) {
    final userJson = (json['user'] as Map<String, dynamic>?) ?? {};
    final expiresIn = json['expiresIn'] as int? ?? 3600;
    return AuthSession(
      user: PlatformUser.fromBackendJson(userJson),
      accessToken: json['accessToken'] as String? ?? '',
      refreshToken: json['refreshToken'] as String? ?? '',
      expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
    );
  }

  /// Tạo bản sao với các thuộc tính được cập nhật
  AuthSession copyWith({
    PlatformUser? user,
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
  }) {
    return AuthSession(
      user: user ?? this.user,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  /// Chuyển đổi thông tin phiên làm việc thành Map JSON
  Map<String, dynamic> toJson() => {
    'userId': user.id,
    'userName': user.name,
    'accessToken': accessToken,
    'expiresAt': expiresAt.toIso8601String(),
    'isExpired': isExpired,
  };
}
