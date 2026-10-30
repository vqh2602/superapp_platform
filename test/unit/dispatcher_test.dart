import '../support/auth_fixtures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superapp_platform/core/errors/bridge_error.dart';
import 'package:superapp_platform/features/authentication/data/auth_code_service_shim.dart';
import 'package:superapp_platform/features/authentication/data/auth_repository_impl.dart';
import 'package:superapp_platform/features/authentication/data/token_service_shim.dart';
import 'package:superapp_platform/features/debug_center/data/debug_log_repository.dart';
import 'package:superapp_platform/features/device/data/device_adapter_impl.dart';
import 'package:superapp_platform/features/mini_app_catalog/domain/mini_app_manifest.dart';
import 'package:superapp_platform/features/native_actions/application/native_action_dispatcher.dart';
import 'package:superapp_platform/features/native_actions/domain/action_context.dart';
import 'package:superapp_platform/features/permissions/data/permission_repository_impl.dart';
import 'package:superapp_platform/features/user_profile/data/user_repository_impl.dart';

void main() {
  group('NativeActionDispatcher Tests', () {
    late AuthRepositoryImpl authRepo;
    late AuthCodeServiceShim authCodeService;
    late TokenServiceShim tokenService;
    late UserRepositoryImpl userRepo;
    late DeviceAdapterImpl deviceAdapter;
    late PermissionRepositoryImpl permissionRepo;
    late DebugLogRepository debugLogRepo;
    late NativeActionDispatcher dispatcher;

    const manifest = MiniAppManifest(
      id: 'sdk_playground',
      name: 'SDK Playground',
      description: 'Test',
      version: '1.0.5',
      icon: 'code',
      entryUrl: 'http://localhost:3000/api/v1/miniapps/sdk_playground/1.0.5/dist/index.html',
      capabilities: ['auth.requestCode', 'user.getProfile', 'device.scanQRCode', 'device.getLocation'],
    );

    setUp(() {
      authRepo = TestAuthRepository();
      authCodeService = AuthCodeServiceShim();
      tokenService = TokenServiceShim(authCodeService: authCodeService);
      userRepo = UserRepositoryImpl(authRepository: authRepo);
      deviceAdapter = DeviceAdapterImpl();
      permissionRepo = PermissionRepositoryImpl();
      debugLogRepo = DebugLogRepository();

      dispatcher = NativeActionDispatcher(
        authRepo: authRepo,
        authCodeService: authCodeService,
        tokenService: tokenService,
        userRepo: userRepo,
        deviceAdapter: deviceAdapter,
        permissionRepo: permissionRepo,
        debugLogRepo: debugLogRepo,
      );
    });

    tearDown(() {
      authRepo.dispose();
      debugLogRepo.dispose();
    });

    test('Rejects unknown action with ACTION_NOT_FOUND', () async {
      final context = ActionContext(appId: 'sdk_playground', manifest: manifest);
      expect(
        () => dispatcher.dispatch('unknown.fakeAction', {}, context),
        throwsA(isA<BridgeError>().having((e) => e.code, 'code', BridgeErrorCode.actionNotFound)),
      );
    });

    test('Requires login for protected action', () async {
      permissionRepo.setPermission('sdk_playground', 'user.getProfile', true);
      final context = ActionContext(appId: 'sdk_playground', manifest: manifest);

      expect(
        () => dispatcher.dispatch('user.getProfile', {}, context),
        throwsA(isA<BridgeError>().having((e) => e.code, 'code', BridgeErrorCode.authRequired)),
      );
    });

    test('Requires permission for capability', () async {
      await authRepo.login(TestUsers.userA.id);
      final context = ActionContext(appId: 'sdk_playground', manifest: manifest);

      // Permission not yet granted
      expect(
        () => dispatcher.dispatch('user.getProfile', {}, context),
        throwsA(isA<BridgeError>().having((e) => e.code, 'code', BridgeErrorCode.permissionDenied)),
      );
    });

    test('Succeeds when authenticated and permission granted', () async {
      await authRepo.login(TestUsers.userA.id);
      permissionRepo.setPermission('sdk_playground', 'user.getProfile', true);
      final context = ActionContext(appId: 'sdk_playground', manifest: manifest);

      final result = await dispatcher.dispatch('user.getProfile', {}, context);
      expect(result['id'], equals(TestUsers.userA.id));
      expect(result['name'], equals('Nguyễn Văn A'));
      expect(result['role'], equals('customer'));
    });

    test('Real device mode returns UNSUPPORTED when no real hardware attached', () async {
      permissionRepo.setPermission('sdk_playground', 'device.scanQRCode', true);
      final context = ActionContext(appId: 'sdk_playground', manifest: manifest);

      expect(
        () => dispatcher.dispatch('device.scanQRCode', {}, context),
        throwsA(isA<BridgeError>().having((e) => e.code, 'code', BridgeErrorCode.unsupported)),
      );
    });
    test('navigation.openNativePage does not require capability permission', () async {
      // Should not throw PERMISSION_DENIED even without capability granted
      final context = ActionContext(appId: 'sdk_playground', manifest: manifest);

      // Throws internal error because buildContext is null, which proves permission check passed
      expect(
        () => dispatcher.dispatch('navigation.openNativePage', {'page': 'profile'}, context),
        throwsA(isA<BridgeError>().having((e) => e.code, 'code', BridgeErrorCode.internalError)),
      );
    });
  });
}
