import '../../../../core/errors/bridge_error.dart';
import '../domain/models/auth_code.dart';

/// Compatibility shim. Authorization codes must come from the backend via PKCE.
class AuthCodeServiceShim {
  String generateCode({required String userId, required String appId}) =>
      throw BridgeError.unsupported('Use backend PKCE authorization');
  AuthCode validateAndBurn(String code, String appId) =>
      throw BridgeError.unsupported('Codes are validated by the backend');
  void reset() {}
}
