import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import '../../../core/errors/bridge_error.dart';

class BiometricStatus {
  final bool supported;
  final List<String> availableBiometrics;

  const BiometricStatus({
    required this.supported,
    this.availableBiometrics = const [],
  });

  bool get enrolled => availableBiometrics.isNotEmpty;
  bool get canAuthenticate => supported && enrolled;

  Map<String, dynamic> toJson() => {
    'supported': supported,
    'enrolled': enrolled,
    'canAuthenticate': canAuthenticate,
    'availableBiometrics': availableBiometrics,
  };
}

/// Local device verification only; does not create or refresh a backend session.
class BiometricService {
  final LocalAuthentication _auth;

  BiometricService({LocalAuthentication? auth})
    : _auth = auth ?? LocalAuthentication();

  bool get _platformSupported =>
      !kIsWeb &&
      const [
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
      ].contains(defaultTargetPlatform);

  Future<BiometricStatus> checkAvailability() async {
    if (!_platformSupported) return const BiometricStatus(supported: false);
    try {
      final supported = await _auth.canCheckBiometrics;
      final available = supported
          ? await _auth.getAvailableBiometrics()
          : <BiometricType>[];
      return BiometricStatus(
        supported: supported,
        availableBiometrics: available.map((type) => type.name).toList(),
      );
    } on LocalAuthException catch (error) {
      if (error.code == LocalAuthExceptionCode.noBiometricHardware) {
        return const BiometricStatus(supported: false);
      }
      if (error.code == LocalAuthExceptionCode.noBiometricsEnrolled ||
          error.code == LocalAuthExceptionCode.noCredentialsSet) {
        return const BiometricStatus(supported: true);
      }
      throw _bridgeError(error);
    } on MissingPluginException {
      return const BiometricStatus(supported: false);
    } on PlatformException {
      throw BridgeError.internal(
        'Không thể kiểm tra sinh trắc học trên thiết bị',
      );
    }
  }

  Future<bool> authenticate(
    String reason, {
    void Function()? checkCancelled,
  }) async {
    final status = await checkAvailability();
    checkCancelled?.call();
    if (!status.canAuthenticate) {
      throw BridgeError.unsupported(
        status.supported
            ? 'Chưa thiết lập hoặc chưa cho phép sinh trắc học. Vui lòng kiểm tra Cài đặt thiết bị.'
            : 'Thiết bị không hỗ trợ sinh trắc học',
      );
    }
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
      );
    } on LocalAuthException catch (error) {
      throw _bridgeError(error);
    } on MissingPluginException {
      throw BridgeError.unsupported('Sinh trắc học');
    } on PlatformException {
      throw BridgeError.internal('Không thể mở xác thực sinh trắc học');
    }
  }

  BridgeError _bridgeError(LocalAuthException error) {
    switch (error.code) {
      case LocalAuthExceptionCode.userCanceled:
      case LocalAuthExceptionCode.systemCanceled:
      case LocalAuthExceptionCode.userRequestedFallback:
        return BridgeError.cancelled('Xác thực sinh trắc học đã bị hủy');
      case LocalAuthExceptionCode.timeout:
        return BridgeError.timeout('Xác thực sinh trắc học hết thời gian');
      case LocalAuthExceptionCode.authInProgress:
      case LocalAuthExceptionCode.temporaryLockout:
      case LocalAuthExceptionCode.biometricLockout:
        return BridgeError.rateLimitExceeded(
          'Sinh trắc học đang bận hoặc bị khóa. Vui lòng thử lại sau.',
        );
      case LocalAuthExceptionCode.noBiometricHardware:
      case LocalAuthExceptionCode.noBiometricsEnrolled:
      case LocalAuthExceptionCode.noCredentialsSet:
      case LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable:
        return BridgeError.unsupported(
          'Sinh trắc học chưa sẵn sàng trên thiết bị',
        );
      default:
        return BridgeError.internal('Xác thực sinh trắc học thất bại', {
          'reason': error.code.name,
        });
    }
  }
}
