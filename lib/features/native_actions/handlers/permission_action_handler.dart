import '../../../../core/errors/bridge_error.dart';
import '../../permissions/data/permission_repository_impl.dart';
import '../../permissions/presentation/permission_prompt_dialog.dart';
import '../domain/action_definition.dart';
import '../domain/action_context.dart';

class PermissionRequestHandler implements NativeActionHandler {
  final PermissionRepositoryImpl permissionRepo;

  PermissionRequestHandler({required this.permissionRepo});

  @override
  String get actionName => 'permission.request';

  @override
  String? get requiredCapability => null;

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    final capability = payload['capability'] as String?;
    if (capability == null || capability.isEmpty) {
      throw BridgeError.invalidParams('capability is required');
    }

    // If already granted, return true
    if (permissionRepo.isGranted(context.appId, capability)) {
      return {'capability': capability, 'granted': true};
    }

    if (context.buildContext == null) {
      throw BridgeError.internal('BuildContext is null for permission dialog');
    }

    final granted = await PermissionPromptDialog.show(
      context.buildContext!,
      appName: context.manifest?.name ?? context.appId,
      capabilityKey: capability,
    );

    permissionRepo.setPermission(context.appId, capability, granted);

    return {
      'capability': capability,
      'granted': granted,
    };
  }
}

class PermissionCheckHandler implements NativeActionHandler {
  final PermissionRepositoryImpl permissionRepo;

  PermissionCheckHandler({required this.permissionRepo});

  @override
  String get actionName => 'permission.check';

  @override
  String? get requiredCapability => null;

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    final capability = payload['capability'] as String?;
    if (capability == null || capability.isEmpty) {
      throw BridgeError.invalidParams('capability is required');
    }

    final granted = permissionRepo.isGranted(context.appId, capability);
    return {
      'capability': capability,
      'granted': granted,
    };
  }
}

class PermissionGetPermissionsHandler implements NativeActionHandler {
  final PermissionRepositoryImpl permissionRepo;

  PermissionGetPermissionsHandler({required this.permissionRepo});

  @override
  String get actionName => 'permission.getPermissions';

  @override
  String? get requiredCapability => null;

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    final permissions = permissionRepo.getPermissionsForApp(context.appId);
    return {
      'appId': context.appId,
      'permissions': permissions,
    };
  }
}
