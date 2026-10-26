class MiniAppTokenResult {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn;
  final String userId;
  final String appId;

  const MiniAppTokenResult({
    required this.accessToken,
    required this.refreshToken,
    this.tokenType = 'Bearer',
    required this.expiresIn,
    required this.userId,
    required this.appId,
  });

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'tokenType': tokenType,
    'expiresIn': expiresIn,
    'userId': userId,
    'appId': appId,
  };
}

abstract class TokenService {
  Future<MiniAppTokenResult> exchangeCode({
    required String authCode,
    required String appId,
  });

  Future<MiniAppTokenResult> refreshToken({
    required String refreshToken,
    required String appId,
  });

  bool validateMiniAppAccessToken(String token);
  void revokeToken(String token);
}
