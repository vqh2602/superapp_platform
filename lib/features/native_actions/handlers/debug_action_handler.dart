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

