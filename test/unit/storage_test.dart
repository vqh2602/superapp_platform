import 'package:flutter_test/flutter_test.dart';
import 'package:superapp_platform/core/errors/bridge_error.dart';
import 'package:superapp_platform/features/storage/data/mock_secure_storage_repository.dart';
import 'package:superapp_platform/features/native_actions/application/native_action_dispatcher.dart';
import 'package:superapp_platform/features/native_actions/domain/action_context.dart';
import 'package:superapp_platform/features/mini_app_catalog/domain/mini_app_manifest.dart';
import 'package:superapp_platform/features/authentication/data/mock_auth_repository.dart';
import 'package:superapp_platform/features/authentication/data/mock_auth_code_service.dart';
import 'package:superapp_platform/features/authentication/data/mock_token_service.dart';
import 'package:superapp_platform/features/user_profile/data/mock_user_repository.dart';
import 'package:superapp_platform/features/device/data/mock_device_adapter.dart';
import 'package:superapp_platform/features/payment/data/mock_order_repository.dart';
import 'package:superapp_platform/features/permissions/data/mock_permission_repository.dart';
import 'package:superapp_platform/features/debug_center/data/debug_log_repository.dart';

void main() {
  group('MockSecureStorageRepository Tests', () {
    late MockSecureStorageRepository repository;

    setUp(() {
      repository = MockSecureStorageRepository();
    });

    test('Stores and retrieves key-value pair securely with default domain', () async {
      final setResult = await repository.setItem(
        appId: 'test_app',
        key: 'jwt_token',
        value: 'secret_token_123',
      );

      expect(setResult['success'], true);
      expect(setResult['key'], 'jwt_token');
      expect(setResult['securityLevel'], 'KEYCHAIN_OR_KEYSTORE');

      final getResult = await repository.getItem(
        appId: 'test_app',
        key: 'jwt_token',
      );

      expect(getResult['exists'], true);
      expect(getResult['value'], 'secret_token_123');
      expect(getResult['securityLevel'], 'KEYCHAIN_OR_KEYSTORE');
    });

    test('Isolates keys by appId (sandboxing)', () async {
      await repository.setItem(
        appId: 'app_1',
        key: 'shared_key',
        value: 'val_1',
      );
      await repository.setItem(
        appId: 'app_2',
        key: 'shared_key',
        value: 'val_2',
      );

      final app1Res = await repository.getItem(appId: 'app_1', key: 'shared_key');
      final app2Res = await repository.getItem(appId: 'app_2', key: 'shared_key');

      expect(app1Res['value'], 'val_1');
      expect(app2Res['value'], 'val_2');
    });

    test('Supports custom domain grouping and key removal', () async {
      await repository.setItem(
        appId: 'test_app',
        key: 'api_key',
        value: 'key_xyz',
        domain: 'finance.domain',
      );

      final getBefore = await repository.getItem(
        appId: 'test_app',
        key: 'api_key',
        domain: 'finance.domain',
      );
      expect(getBefore['exists'], true);
      expect(getBefore['value'], 'key_xyz');

      final removeRes = await repository.removeItem(
        appId: 'test_app',
        key: 'api_key',
        domain: 'finance.domain',
      );
      expect(removeRes['removed'], true);

      final getAfter = await repository.getItem(
        appId: 'test_app',
        key: 'api_key',
        domain: 'finance.domain',
      );
      expect(getAfter['exists'], false);
      expect(getAfter['value'], isNull);
    });

    test('Clears all keys for an app', () async {
      await repository.setItem(appId: 'test_app', key: 'k1', value: 'v1');
      await repository.setItem(appId: 'test_app', key: 'k2', value: 'v2');

      final clearRes = await repository.clear(appId: 'test_app');
      expect(clearRes['cleared'], true);
      expect(clearRes['count'], 2);

      final keys = await repository.getAllKeys(appId: 'test_app');
      expect(keys, isEmpty);
    });

    test('Saves, retrieves, and deletes domain credentials (Keychain/Keystore)', () async {
      final setRes = await repository.setCredentials(
        appId: 'test_app',
        domain: 'api.bank.com',
        username: 'alice',
        password: 'password123',
      );

      expect(setRes['success'], true);
      expect(setRes['username'], 'alice');
      expect(setRes['securityLevel'], 'KEYCHAIN_OR_KEYSTORE');

      final getRes = await repository.getCredentials(
        appId: 'test_app',
        domain: 'api.bank.com',
      );
      expect(getRes['exists'], true);
      expect(getRes['username'], 'alice');
      expect(getRes['password'], 'password123');

      final delRes = await repository.deleteCredentials(
        appId: 'test_app',
        domain: 'api.bank.com',
      );
      expect(delRes['deleted'], true);

      final getAfterDel = await repository.getCredentials(
        appId: 'test_app',
        domain: 'api.bank.com',
      );
      expect(getAfterDel['exists'], false);
    });
  });

  group('NativeActionDispatcher Secure Storage Integration Tests', () {
    late NativeActionDispatcher dispatcher;
    late MockSecureStorageRepository secureStorageRepo;
    late MockPermissionRepository permissionRepo;

    final testManifest = const MiniAppManifest(
      id: 'sdk_playground',
      name: 'SDK Playground',
      description: 'Test Manifest',
      version: '1.0.0',
      icon: 'code',
      entryUrl: 'assets/mini_apps/sdk_playground/index.html',
      capabilities: [
        'storage.setSecureItem',
        'storage.getSecureItem',
        'storage.removeSecureItem',
        'storage.clear',
        'storage.setCredentials',
        'storage.getCredentials',
        'storage.deleteCredentials',
        'permission.getPermissions',
      ],
    );

    setUp(() {
      final authRepo = MockAuthRepository();
      final authCodeService = MockAuthCodeService();
      final tokenService = MockTokenService(authCodeService: authCodeService);
      final userRepo = MockUserRepository(authRepository: authRepo);
      final deviceAdapter = MockDeviceAdapter();
      final orderRepo = MockOrderRepository();
      permissionRepo = MockPermissionRepository();
      final debugLogRepo = DebugLogRepository();
      secureStorageRepo = MockSecureStorageRepository();

      dispatcher = NativeActionDispatcher(
        authRepo: authRepo,
        authCodeService: authCodeService,
        tokenService: tokenService,
        userRepo: userRepo,
        deviceAdapter: deviceAdapter,
        orderRepo: orderRepo,
        permissionRepo: permissionRepo,
        debugLogRepo: debugLogRepo,
        secureStorageRepo: secureStorageRepo,
      );
    });

    test('Dispatches storage.setSecureItem and storage.getSecureItem end-to-end', () async {
      final context = ActionContext(appId: 'sdk_playground', manifest: testManifest);

      final setRes = await dispatcher.dispatch(
        'storage.setSecureItem',
        {
          'key': 'user_vault_key',
          'value': 'encrypted_super_secret_payload',
          'domain': 'secure.vault',
        },
        context,
      );

      expect(setRes['success'], true);
      expect(setRes['key'], 'user_vault_key');
      expect(setRes['securityLevel'], 'KEYCHAIN_OR_KEYSTORE');

      final getRes = await dispatcher.dispatch(
        'storage.getSecureItem',
        {
          'key': 'user_vault_key',
          'domain': 'secure.vault',
        },
        context,
      );

      expect(getRes['exists'], true);
      expect(getRes['value'], 'encrypted_super_secret_payload');
    });

    test('Rejects storage.setSecureItem with INVALID_PARAMS if key or value is missing', () async {
      final context = ActionContext(appId: 'sdk_playground', manifest: testManifest);

      expect(
        () => dispatcher.dispatch('storage.setSecureItem', {'value': 'val'}, context),
        throwsA(isA<BridgeError>().having((e) => e.code, 'code', BridgeErrorCode.invalidParams)),
      );

      expect(
        () => dispatcher.dispatch('storage.setSecureItem', {'key': 'k'}, context),
        throwsA(isA<BridgeError>().having((e) => e.code, 'code', BridgeErrorCode.invalidParams)),
      );
    });

    test('Dispatches storage.setCredentials, getCredentials, deleteCredentials', () async {
      final context = ActionContext(appId: 'sdk_playground', manifest: testManifest);

      final setCredRes = await dispatcher.dispatch(
        'storage.setCredentials',
        {
          'domain': 'superapp.finance.vn',
          'username': 'demo_user',
          'password': 'demo_password',
        },
        context,
      );
      expect(setCredRes['success'], true);
      expect(setCredRes['username'], 'demo_user');

      final getCredRes = await dispatcher.dispatch(
        'storage.getCredentials',
        {'domain': 'superapp.finance.vn'},
        context,
      );
      expect(getCredRes['exists'], true);
      expect(getCredRes['username'], 'demo_user');
      expect(getCredRes['password'], 'demo_password');

      final delCredRes = await dispatcher.dispatch(
        'storage.deleteCredentials',
        {'domain': 'superapp.finance.vn'},
        context,
      );
      expect(delCredRes['deleted'], true);
    });

    test('Dispatches permission.getPermissions returning granted list', () async {
      final context = ActionContext(appId: 'sdk_playground', manifest: testManifest);
      permissionRepo.setPermission('sdk_playground', 'device.getLocation', true);

      final res = await dispatcher.dispatch('permission.getPermissions', {}, context);
      expect(res['appId'], 'sdk_playground');
      expect(res['permissions']['device.getLocation'], true);
    });
  });
}
