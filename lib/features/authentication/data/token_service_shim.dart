// Lớp tương thích ngược (Compatibility Shim) cho TokenService.
//
// Các tác vụ đổi mã token (exchangeCode) và làm mới token (refreshToken)
// được ủy quyền trực tiếp cho máy chủ Backend để đảm bảo an toàn bảo mật.
import '../../../../core/errors/bridge_error.dart';
import '../domain/repositories/token_service.dart';
import 'auth_code_service_shim.dart';

/// Lớp Shim cài đặt [TokenService] ủy thác xác thực cho Backend
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
