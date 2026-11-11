// Giao diện dịch vụ quản lý token cho Mini App (Token Service Interface).
//
// Quản lý việc trao đổi authorization code lấy token và làm mới token cho Mini App.

/// Kết quả trả về sau khi đổi authorization code hoặc làm mới token cho Mini App
class MiniAppTokenResult {
  /// Access Token cấp riêng cho Mini App
  final String accessToken;

  /// Refresh Token dùng để cấp mới access token
  final String refreshToken;

  /// Loại token (mặc định 'Bearer')
  final String tokenType;

  /// Thời gian sống của token tính bằng giây
  final int expiresIn;

  /// Định danh người dùng sở hữu token
  final String userId;

  /// Định danh Mini App được cấp token
  final String appId;

  const MiniAppTokenResult({
    required this.accessToken,
    required this.refreshToken,
    this.tokenType = 'Bearer',
    required this.expiresIn,
    required this.userId,
    required this.appId,
  });

  /// Chuyển đổi kết quả thành Map JSON
  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'tokenType': tokenType,
    'expiresIn': expiresIn,
    'userId': userId,
    'appId': appId,
  };
}

/// Hợp đồng dịch vụ quản lý cấp phát và kiểm tra token của Mini App
abstract class TokenService {
  /// Đổi authorization code lấy cặp token AccessToken/RefreshToken
  Future<MiniAppTokenResult> exchangeCode({
    required String authCode,
    required String appId,
  });

  /// Làm mới access token bằng refresh token
  Future<MiniAppTokenResult> refreshToken({
    required String refreshToken,
    required String appId,
  });

  /// Kiểm tra tính hợp lệ của Mini App access token
  bool validateMiniAppAccessToken(String token);

  /// Thu hồi token đã cấp
  void revokeToken(String token);
}
