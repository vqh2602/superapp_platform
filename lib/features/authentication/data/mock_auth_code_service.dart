import 'dart:math';
import '../../../../core/config/app_config.dart';
import '../../../../core/errors/bridge_error.dart';
import '../domain/models/auth_code.dart';

class MockAuthCodeService {
  final Map<String, AuthCode> _codes = {};

  /// Generates a single-use authorization code with 60s TTL.
  String generateCode({
    required String userId,
    required String appId,
  }) {
    final randomPart = Random().nextInt(900000) + 100000;
    final code = 'AUTH_${appId.toUpperCase()}_$randomPart';
    final now = DateTime.now();

    _codes[code] = AuthCode(
      code: code,
      userId: userId,
      appId: appId,
      createdAt: now,
      expiresAt: now.add(const Duration(seconds: AppConfig.authCodeTtlSeconds)),
    );

    return code;
  }

  /// Validates and burns an auth code (single use).
  AuthCode validateAndBurn(String code, String appId) {
    final entry = _codes[code];
    if (entry == null) {
      throw BridgeError.invalidParams('Invalid authorization code');
    }

    if (entry.appId != appId) {
      throw BridgeError.invalidParams('Code was not issued to this mini app');
    }

    if (entry.isUsed) {
      throw BridgeError.invalidParams('Authorization code has already been used');
    }

    if (DateTime.now().isAfter(entry.expiresAt)) {
      throw BridgeError.invalidParams('Authorization code has expired (60s TTL)');
    }

    // Burn code
    entry.isUsed = true;
    return entry;
  }

  void reset() {
    _codes.clear();
  }
}
