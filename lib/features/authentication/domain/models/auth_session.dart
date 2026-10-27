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

  factory AuthSession.fromBackendJson(Map<String, dynamic> json) {
    final userJson = (json['user'] as Map<String, dynamic>?) ?? {};
    final expiresIn = json['expiresIn'] as int? ?? 3600;
    return AuthSession(
      user: MockUser.fromBackendJson(userJson),
      accessToken: json['accessToken'] as String? ?? '',
      refreshToken: json['refreshToken'] as String? ?? '',
      expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
    );
  }

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
