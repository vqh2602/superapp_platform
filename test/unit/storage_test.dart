import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../support/auth_fixtures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superapp_platform/core/errors/bridge_error.dart';
import 'package:superapp_platform/core/security/runtime_security_context.dart';
import 'package:superapp_platform/features/storage/data/secure_storage_repository_impl.dart';
import 'package:superapp_platform/features/native_actions/application/native_action_dispatcher.dart';
import 'package:superapp_platform/features/native_actions/domain/action_context.dart';
import 'package:superapp_platform/features/mini_app_catalog/domain/mini_app_manifest.dart';
import 'package:superapp_platform/features/authentication/data/auth_code_service_shim.dart';
import 'package:superapp_platform/features/authentication/data/token_service_shim.dart';
import 'package:superapp_platform/features/user_profile/data/user_repository_impl.dart';
import 'package:superapp_platform/features/device/data/device_adapter_impl.dart';
import 'package:superapp_platform/features/permissions/data/permission_repository_impl.dart';
import 'package:superapp_platform/features/debug_center/data/debug_log_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  group('SecureStorageRepositoryImpl Tests', () {
    late SecureStorageRepositoryImpl repository;

    setUp(() {
      repository = SecureStorageRepositoryImpl();
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
    late SecureStorageRepositoryImpl secureStorageRepo;
    late PermissionRepositoryImpl permissionRepo;

    final testManifest = const MiniAppManifest(
      id: 'sdk_playground',
      name: 'SDK Playground',
      description: 'Test Manifest',
      version: '1.0.5',
      icon: 'code',
      entryUrl: 'http://localhost:3000/api/v1/miniapps/sdk_playground/1.0.5/dist/index.html',
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
      final authRepo = TestAuthRepository();
      final authCodeService = AuthCodeServiceShim();
      final tokenService = TokenServiceShim(authCodeService: authCodeService);
      final userRepo = UserRepositoryImpl(authRepository: authRepo);
      final deviceAdapter = DeviceAdapterImpl();
      permissionRepo = PermissionRepositoryImpl();
      final debugLogRepo = DebugLogRepository();
      secureStorageRepo = SecureStorageRepositoryImpl();

      dispatcher = NativeActionDispatcher(
        authRepo: authRepo,
        authCodeService: authCodeService,
        tokenService: tokenService,
        userRepo: userRepo,
        deviceAdapter: deviceAdapter,
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

  group('Secure Storage Multi-User Isolation & Anti-Collision v2 Tests', () {
    late SecureStorageRepositoryImpl repository;

    setUp(() {
      repository = SecureStorageRepositoryImpl();
    });

    test('Isolates data between User A and User B on the same Mini App and device', () async {
      // User A writes sensitive data
      await repository.setItem(
        appId: 'bank_app',
        key: 'auth_token',
        value: 'token_of_user_A',
        userId: 'user_A',
      );

      // User B attempts to read the same key on the same app
      final userBRead = await repository.getItem(
        appId: 'bank_app',
        key: 'auth_token',
        userId: 'user_B',
      );
      expect(userBRead['exists'], false);
      expect(userBRead['value'], isNull);

      // User B writes their own data
      await repository.setItem(
        appId: 'bank_app',
        key: 'auth_token',
        value: 'token_of_user_B',
        userId: 'user_B',
      );

      // Verify User A still has their original data
      final userARead = await repository.getItem(
        appId: 'bank_app',
        key: 'auth_token',
        userId: 'user_A',
      );
      expect(userARead['exists'], true);
      expect(userARead['value'], 'token_of_user_A');

      // Verify User B has their own distinct data
      final userBRead2 = await repository.getItem(
        appId: 'bank_app',
        key: 'auth_token',
        userId: 'user_B',
      );
      expect(userBRead2['exists'], true);
      expect(userBRead2['value'], 'token_of_user_B');
    });

    test('Prevents delimiter-based key collisions (SHA-256 hashed components)', () async {
      // Case 1: appId = "foo_bar", domain = "baz", key = "qux"
      await repository.setItem(
        appId: 'foo_bar',
        domain: 'baz',
        key: 'qux',
        value: 'value_1',
        userId: 'user_1',
      );

      // Case 2: appId = "foo", domain = "bar_baz", key = "qux"
      // In naive underscore concatenation ("sec_foo_bar_baz_qux"), these would collide!
      await repository.setItem(
        appId: 'foo',
        domain: 'bar_baz',
        key: 'qux',
        value: 'value_2',
        userId: 'user_1',
      );

      final read1 = await repository.getItem(
        appId: 'foo_bar',
        domain: 'baz',
        key: 'qux',
        userId: 'user_1',
      );
      final read2 = await repository.getItem(
        appId: 'foo',
        domain: 'bar_baz',
        key: 'qux',
        userId: 'user_1',
      );

      expect(read1['value'], 'value_1');
      expect(read2['value'], 'value_2');
      expect(read1['value'] != read2['value'], true);
    });

    test('clearUserData purges all keys for a logged out user without affecting other users', () async {
      await repository.setItem(appId: 'app1', key: 'k1', value: 'v1', userId: 'alice');
      await repository.setItem(appId: 'app2', key: 'k2', value: 'v2', userId: 'alice');
      await repository.setItem(appId: 'app1', key: 'k1', value: 'v_bob', userId: 'bob');

      final clearRes = await repository.clearUserData('alice');
      expect(clearRes['cleared'], true);
      expect(clearRes['count'], 2);

      // Alice's data is wiped
      final aliceGet1 = await repository.getItem(appId: 'app1', key: 'k1', userId: 'alice');
      final aliceGet2 = await repository.getItem(appId: 'app2', key: 'k2', userId: 'alice');
      expect(aliceGet1['exists'], false);
      expect(aliceGet2['exists'], false);

      // Bob's data remains safe and accessible
      final bobGet = await repository.getItem(appId: 'app1', key: 'k1', userId: 'bob');
      expect(bobGet['exists'], true);
      expect(bobGet['value'], 'v_bob');
    });

    test('clearAppData purges Mini App data across users when uninstalled', () async {
      await repository.setItem(appId: 'target_app', key: 'k1', value: 'v_alice', userId: 'alice');
      await repository.setItem(appId: 'target_app', key: 'k1', value: 'v_bob', userId: 'bob');
      await repository.setItem(appId: 'other_app', key: 'k1', value: 'v_stay', userId: 'alice');

      final clearRes = await repository.clearAppData('target_app');
      expect(clearRes['cleared'], true);
      expect(clearRes['count'], 2);

      // Target app is gone for all users
      expect((await repository.getItem(appId: 'target_app', key: 'k1', userId: 'alice'))['exists'], false);
      expect((await repository.getItem(appId: 'target_app', key: 'k1', userId: 'bob'))['exists'], false);

      // Other app data is untouched
      final stayGet = await repository.getItem(appId: 'other_app', key: 'k1', userId: 'alice');
      expect(stayGet['exists'], true);
      expect(stayGet['value'], 'v_stay');
    });

    test('getAll restricts bulk dumping and never leaks credentials', () async {
      // 1. Store regular secure items
      await repository.setItem(appId: 'sec_test', key: 'setting_1', value: 'dark_mode', userId: 'u1');
      await repository.setItem(appId: 'sec_test', key: 'setting_2', value: 'vi_VN', userId: 'u1');

      // 2. Store highly sensitive credentials
      await repository.setCredentials(
        appId: 'sec_test',
        domain: 'default',
        username: 'admin',
        password: 'super_secret_password',
        userId: 'u1',
      );

      // 3. Call getAll
      final all = await repository.getAll(appId: 'sec_test', userId: 'u1');

      // Regular keys are present
      expect(all['setting_1'], 'dark_mode');
      expect(all['setting_2'], 'vi_VN');

      // Credentials are NOT returned in getAll (Anti-Bulk Exfiltration Policy)
      expect(all.containsKey('__cred__'), false);
      expect(all.containsKey('password'), false);
      expect(all.values.contains('super_secret_password'), false);

      // Verify maxLimit enforcement
      final limited = await repository.getAll(appId: 'sec_test', userId: 'u1', maxLimit: 1);
      expect(limited.length, 1);
    });

    test('ActionContext with RuntimeSecurityContext routes storage with user isolation', () async {
      final authRepo = TestAuthRepository();
      final dispatcher = NativeActionDispatcher(
        authRepo: authRepo,
        authCodeService: AuthCodeServiceShim(),
        tokenService: TokenServiceShim(authCodeService: AuthCodeServiceShim()),
        userRepo: UserRepositoryImpl(authRepository: authRepo),
        deviceAdapter: DeviceAdapterImpl(),
        permissionRepo: PermissionRepositoryImpl(),
        debugLogRepo: DebugLogRepository(),
        secureStorageRepo: repository,
      );

      final secAlice = RuntimeSecurityContext(
        appId: 'wallet_app',
        userId: 'alice_123',
        approvedOrigin: 'https://example.com',
        activeVersion: '1.0.0',
        allowedCapabilities: {'storage.setSecureItem', 'storage.getSecureItem'},
        runtimeSessionId: 'sess_1',
      );
      final ctxAlice = ActionContext(appId: 'wallet_app', securityContext: secAlice);

      final secBob = RuntimeSecurityContext(
        appId: 'wallet_app',
        userId: 'bob_456',
        approvedOrigin: 'https://example.com',
        activeVersion: '1.0.0',
        allowedCapabilities: {'storage.setSecureItem', 'storage.getSecureItem'},
        runtimeSessionId: 'sess_2',
      );
      final ctxBob = ActionContext(appId: 'wallet_app', securityContext: secBob);

      // Alice writes key via dispatcher
      await dispatcher.dispatch('storage.setSecureItem', {
        'key': 'pin_code',
        'value': '9988',
      }, ctxAlice);

      // Bob tries to read the same key via dispatcher
      final bobRes = await dispatcher.dispatch('storage.getSecureItem', {
        'key': 'pin_code',
      }, ctxBob);
      expect(bobRes['exists'], false);
      expect(bobRes['value'], isNull);

      // Alice reads her pin
      final aliceRes = await dispatcher.dispatch('storage.getSecureItem', {
        'key': 'pin_code',
      }, ctxAlice);
      expect(aliceRes['exists'], true);
      expect(aliceRes['value'], '9988');
    });
  });
}
