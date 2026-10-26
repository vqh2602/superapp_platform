import 'action_context.dart';

abstract class NativeActionHandler {
  /// The action identifier, e.g. 'auth.requestCode'
  String get actionName;

  /// Required capability key in manifest/permission, or null if open
  String? get requiredCapability;

  /// Whether Master App authentication is strictly required
  bool get requiresAuth => true;

  /// Executes the action and returns serializable data or throws BridgeError
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context);
}
