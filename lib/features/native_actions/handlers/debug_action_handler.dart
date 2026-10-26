import '../../../../core/errors/bridge_error.dart';
import '../domain/action_definition.dart';
import '../domain/action_context.dart';

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

class DebugSimulateFailureHandler implements NativeActionHandler {
  @override
  String get actionName => 'debug.simulateFailure';

  @override
  String? get requiredCapability => null;

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    final type = payload['type'] as String? ?? 'internal';

    switch (type) {
      case 'timeout':
        await Future.delayed(const Duration(milliseconds: 3500));
        throw BridgeError.timeout('Simulated 3.5s timeout occurred');
      case 'unauthorized':
        throw BridgeError.authRequired('Simulated unauthorized access');
      case 'permission_denied':
        throw BridgeError.permissionDenied('mock.denied_capability');
      case 'unsupported':
        throw BridgeError.unsupported('simulated_hardware_sensor');
      default:
        throw BridgeError.internal('Simulated native execution failure');
    }
  }
}
