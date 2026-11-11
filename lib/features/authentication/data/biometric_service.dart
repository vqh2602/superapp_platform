// Dịch vụ xác thực sinh trắc học cục bộ trên thiết bị (Biometric Service).
//
// Sử dụng thư viện `local_auth` để kiểm tra cảm biến sinh trắc học (vân tay, Face ID)
// và thực hiện prompt xác thực an toàn cục bộ theo yêu cầu của Mini App.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import '../../../core/errors/bridge_error.dart';

/// Đại diện trạng thái hỗ trợ và sẵn sàng của sinh trắc học trên thiết bị
class BiometricStatus {
  /// Phần cứng thiết bị có hỗ trợ cảm biến sinh trắc học hay không
  final bool supported;

  /// Danh sách các loại sinh trắc học khả dụng (vd: 'fingerprint', 'face')
  final List<String> availableBiometrics;

  const BiometricStatus({
    required this.supported,
    this.availableBiometrics = const [],
  });

  /// Đã cài đặt ít nhất một phương thức sinh trắc học trong hệ điều hành
  bool get enrolled => availableBiometrics.isNotEmpty;

  /// Có thể tiến hành xác thực ngay lập tức
  bool get canAuthenticate => supported && enrolled;

  /// Chuyển đổi dữ liệu trạng thái sang Map JSON
  Map<String, dynamic> toJson() => {
    'supported': supported,
    'enrolled': enrolled,
    'canAuthenticate': canAuthenticate,
    'availableBiometrics': availableBiometrics,
  };
}

/// Dịch vụ quản lý xác thực sinh trắc học (vân tay / khuôn mặt)
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

  /// Kiểm tra tính khả dụng của cảm biến sinh trắc học trên thiết bị
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

  /// Kích hoạt hộp thoại xác thực sinh trắc học hệ thống với lý do [reason]
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

  /// Chuyển đổi mã lỗi hệ thống LocalAuth sang đối tượng [BridgeError] chuẩn
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
