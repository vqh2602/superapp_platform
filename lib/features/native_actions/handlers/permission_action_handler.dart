import '../../../../core/errors/bridge_error.dart';
import '../../permissions/application/permission_service.dart';
import '../../permissions/data/permission_repository_impl.dart';
import '../domain/action_definition.dart';
import '../domain/action_context.dart';

class PermissionRequestHandler implements NativeActionHandler {
  final PermissionService permissionService;

  PermissionRequestHandler({
    PermissionService? permissionService,
    PermissionRepositoryImpl? permissionRepo,
  }) : permissionService = permissionService ??
            PermissionService(permissionRepo: permissionRepo ?? PermissionRepositoryImpl());

  @override
  String get actionName => 'permission.request';

  @override
  String? get requiredCapability => null;

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    context.checkCancelled();
    final capability = payload['capability'] as String?;
    if (capability == null || capability.trim().isEmpty) {
      throw BridgeError.invalidParams('capability is required');
    }

    final granted = await permissionService.requestPermission(
      context: context,
      capability: capability,
    );

    return {
      'capability': capability.trim(),
      'granted': granted,
    };
  }
}

class PermissionCheckHandler implements NativeActionHandler {
  final PermissionService permissionService;

  PermissionCheckHandler({
    PermissionService? permissionService,
    PermissionRepositoryImpl? permissionRepo,
  }) : permissionService = permissionService ??
            PermissionService(permissionRepo: permissionRepo ?? PermissionRepositoryImpl());

  @override
  String get actionName => 'permission.check';

  @override
  String? get requiredCapability => null;

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    context.checkCancelled();
    final capability = payload['capability'] as String?;
    if (capability == null || capability.trim().isEmpty) {
      throw BridgeError.invalidParams('capability is required');
    }

    final granted = permissionService.isGranted(context.appId, capability.trim());
    return {
      'capability': capability.trim(),
      'granted': granted,
    };
  }
}

class PermissionGetPermissionsHandler implements NativeActionHandler {
  final PermissionService permissionService;

  PermissionGetPermissionsHandler({
    PermissionService? permissionService,
    PermissionRepositoryImpl? permissionRepo,
  }) : permissionService = permissionService ??
            PermissionService(permissionRepo: permissionRepo ?? PermissionRepositoryImpl());

  @override
  String get actionName => 'permission.getPermissions';

  @override
  String? get requiredCapability => null;

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    context.checkCancelled();
    final permissions = permissionService.getPermissionsForApp(context.appId);
    return {
      'appId': context.appId,
      'permissions': permissions,
    };
  }
}
