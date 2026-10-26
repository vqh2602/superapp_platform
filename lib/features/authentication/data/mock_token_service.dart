import 'package:uuid/uuid.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/errors/bridge_error.dart';
import '../domain/repositories/token_service.dart';
import 'mock_auth_code_service.dart';

class MockTokenRecord {
  final String accessToken;
  final String refreshToken;
  final String userId;
  final String appId;
  final DateTime expiresAt;
  bool isRevoked;

  MockTokenRecord({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.appId,
    required this.expiresAt,
    this.isRevoked = false,
  });

  bool get isValid => !isRevoked && DateTime.now().isBefore(expiresAt);
}

class MockTokenService implements TokenService {
  final MockAuthCodeService authCodeService;
  final _uuid = const Uuid();
  final Map<String, MockTokenRecord> _tokens = {}; // keyed by accessToken
  final Map<String, String> _refreshIndex = {}; // refreshToken -> accessToken

  MockTokenService({required this.authCodeService});

  @override
  Future<MiniAppTokenResult> exchangeCode({
    required String authCode,
    required String appId,
  }) async {
    final validated = authCodeService.validateAndBurn(authCode, appId);

    final accessToken = 'mini_at_${_uuid.v4()}';
    final refreshToken = 'mini_rt_${_uuid.v4()}';
    final expiresIn = AppConfig.miniAppTokenTtlSeconds;

    final record = MockTokenRecord(
      accessToken: accessToken,
      refreshToken: refreshToken,
      userId: validated.userId,
      appId: appId,
      expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
    );

    _tokens[accessToken] = record;
    _refreshIndex[refreshToken] = accessToken;

    return MiniAppTokenResult(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresIn: expiresIn,
      userId: validated.userId,
      appId: appId,
    );
  }

  @override
  Future<MiniAppTokenResult> refreshToken({
    required String refreshToken,
    required String appId,
  }) async {
    final oldAccessToken = _refreshIndex[refreshToken];
    if (oldAccessToken == null) {
      throw BridgeError.invalidParams('Invalid or unknown refresh token');
    }

    final oldRecord = _tokens[oldAccessToken];
    if (oldRecord == null || oldRecord.isRevoked) {
      throw BridgeError.invalidParams('Refresh token revoked or expired');
    }

    // Invalidate old token record
    oldRecord.isRevoked = true;
    _refreshIndex.remove(refreshToken);

    // Issue new pair
    final newAccessToken = 'mini_at_${_uuid.v4()}';
    final newRefreshToken = 'mini_rt_${_uuid.v4()}';
    final expiresIn = AppConfig.miniAppTokenTtlSeconds;

    final newRecord = MockTokenRecord(
      accessToken: newAccessToken,
      refreshToken: newRefreshToken,
      userId: oldRecord.userId,
      appId: appId,
      expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
    );

    _tokens[newAccessToken] = newRecord;
    _refreshIndex[newRefreshToken] = newAccessToken;

    return MiniAppTokenResult(
      accessToken: newAccessToken,
      refreshToken: newRefreshToken,
      expiresIn: expiresIn,
      userId: oldRecord.userId,
      appId: appId,
    );
  }

  @override
  bool validateMiniAppAccessToken(String token) {
    final record = _tokens[token];
    return record != null && record.isValid;
  }

  @override
  void revokeToken(String token) {
    final record = _tokens[token];
    if (record != null) {
      record.isRevoked = true;
      _refreshIndex.remove(record.refreshToken);
    }
  }

  /// Helper to force-expire a token for testing
  void forceExpireToken(String token) {
    final record = _tokens[token];
    if (record != null) {
      record.isRevoked = true;
    }
  }

  void reset() {
    _tokens.clear();
    _refreshIndex.clear();
  }
}
