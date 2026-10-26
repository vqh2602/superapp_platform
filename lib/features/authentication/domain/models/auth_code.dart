/// Single-use temporary authorization code for Mini App token exchange.
class AuthCode {
  final String code;
  final String userId;
  final String appId;
  final DateTime createdAt;
  final DateTime expiresAt;
  bool isUsed;

  AuthCode({
    required this.code,
    required this.userId,
    required this.appId,
    required this.createdAt,
    required this.expiresAt,
    this.isUsed = false,
  });

  bool get isValid => !isUsed && DateTime.now().isBefore(expiresAt);
}
