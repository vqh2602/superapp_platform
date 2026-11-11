// Xử lý các hành động kiểm thử và gỡ lỗi (Debug Action Handlers).
//
// Cung cấp action `debug.echo` để kiểm tra kết nối hai chiều và `debug.simulateFailure`
// để giả lập các lỗi ngoại lệ (timeout, auth required, rate limit, permission denied).
import '../../../../core/errors/bridge_error.dart';
import '../domain/action_definition.dart';
import '../domain/action_context.dart';

/// Xử lý action `debug.echo`: Trả về nguyên vẹn payload kèm thông tin appId và timestamp
class DebugEchoHandler implements NativeActionHandler {
  @override
  String get actionName => 'debug.echo';

  @override
  String? get requiredCapability => null;

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    return {
      'echo': payload,
      'appId': context.appId,
      'serverTimestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }
}

/// Xử lý action `debug.simulateFailure`: Giả lập các loại lỗi Bridge để kiểm thử khả năng chịu lỗi của Mini App
class DebugSimulateFailureHandler implements NativeActionHandler {
  @override
  String get actionName => 'debug.simulateFailure';

  @override
  String? get requiredCapability => null;

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    context.checkCancelled();
    final type = (payload['type'] as String?)?.toLowerCase() ?? 'internal_error';
    switch (type) {
      case 'unsupported':
        throw BridgeError.unsupported('Simulated unsupported action');
      case 'permission_denied':
        throw BridgeError.permissionDenied('debug.simulateFailure');
      case 'auth_required':
        throw BridgeError.authRequired();
      case 'invalid_params':
        throw BridgeError.invalidParams('Simulated invalid params');
      case 'rate_limit':
      case 'rate_limit_exceeded':
        throw BridgeError.rateLimitExceeded();
      case 'payload_too_large':
        throw BridgeError.payloadTooLarge();
      case 'timeout':
        throw BridgeError.timeout('Simulated timeout error');
      default:
        throw BridgeError(
          code: BridgeErrorCode.internalError,
          message: 'Simulated native error ($type)',
        );
    }
  }
}


