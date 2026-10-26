import 'mock_user.dart';

/// Simulated authentication session for Master App.
class AuthSession {
  final MockUser user;
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;

  const AuthSession({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  AuthSession copyWith({
    MockUser? user,
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

  Map<String, dynamic> toJson() => {
    'userId': user.id,
    'userName': user.name,
    'accessToken': accessToken,
    'expiresAt': expiresAt.toIso8601String(),
    'isExpired': isExpired,
  };
}
