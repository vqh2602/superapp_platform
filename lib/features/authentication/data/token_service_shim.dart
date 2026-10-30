import '../../../../core/errors/bridge_error.dart';
import '../domain/repositories/token_service.dart';
import 'auth_code_service_shim.dart';

/// Compatibility shim. This class never generates or validates local tokens.
class TokenServiceShim implements TokenService {
  final AuthCodeServiceShim authCodeService;
  TokenServiceShim({required this.authCodeService});
  @override
  Future<MiniAppTokenResult> exchangeCode({
    required String authCode,
    required String appId,
  }) async => throw BridgeError.unsupported('Use backend token exchange');
  @override
  Future<MiniAppTokenResult> refreshToken({
    required String refreshToken,
    required String appId,
  }) async => throw BridgeError.unsupported('Use backend token refresh');
  @override
  bool validateMiniAppAccessToken(String token) => false;
  @override
  void revokeToken(String token) {}
  void reset() {}
}

typedef MockTokenService = TokenServiceShim;
