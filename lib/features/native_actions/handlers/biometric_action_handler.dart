// Xử lý các hành động xác thực sinh trắc học Bridge (Biometric Action Handlers).
//
// Bao gồm kiểm tra khả dụng `auth.checkBiometrics` và gọi prompt xác thực `auth.authenticateBiometric`.
import '../../../../core/errors/bridge_error.dart';
import '../../authentication/data/biometric_service.dart';
import '../domain/action_context.dart';
import '../domain/action_definition.dart';

/// Xử lý action `auth.checkBiometrics`: Kiểm tra cảm biến vân tay/Face ID trên thiết bị
class AuthCheckBiometricsHandler implements NativeActionHandler {
  final BiometricService service;
  AuthCheckBiometricsHandler({required this.service});

  @override
  String get actionName => 'auth.checkBiometrics';
  @override
  String? get requiredCapability => null;
  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(
    Map<String, dynamic> payload,
    ActionContext context,
  ) async {
    context.checkCancelled();
    final status = await service.checkAvailability();
    context.checkCancelled();
    return status.toJson();
  }
}

/// Xử lý action `auth.authenticateBiometric`: Hiển thị prompt xác thực sinh trắc học
class AuthAuthenticateBiometricHandler implements NativeActionHandler {
  final BiometricService service;
  AuthAuthenticateBiometricHandler({required this.service});

  @override
  String get actionName => 'auth.authenticateBiometric';
  @override
  String? get requiredCapability => null;
  @override
  bool get requiresAuth => true;

  @override
  Future<dynamic> handle(
    Map<String, dynamic> payload,
    ActionContext context,
  ) async {
    final reason = payload['reason'] ?? 'Xác thực sinh trắc học để tiếp tục';
    if (reason is! String || reason.trim().isEmpty || reason.length > 200) {
      throw BridgeError.invalidParams(
        'reason phải là chuỗi từ 1 đến 200 ký tự',
      );
    }
    return context.runInteractive(() async {
      context.checkCancelled();
      final authenticated = await service.authenticate(
        reason.trim(),
        checkCancelled: context.checkCancelled,
      );
      context.checkCancelled();
      return {'authenticated': authenticated};
    });
  }
}
