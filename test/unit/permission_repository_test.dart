import 'package:superapp_platform/features/authentication/data/auth_code_service_shim.dart';
import 'package:superapp_platform/features/authentication/data/token_service_shim.dart';
import 'package:superapp_platform/features/debug_center/data/debug_log_repository.dart';
import 'package:superapp_platform/features/device/data/device_adapter_impl.dart';
import 'package:superapp_platform/features/native_actions/application/native_action_dispatcher.dart';
import 'package:superapp_platform/features/native_actions/domain/action_context.dart';
import 'package:superapp_platform/features/user_profile/data/user_repository_impl.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:superapp_platform/features/authentication/data/auth_repository_impl.dart';
import 'package:superapp_platform/features/permissions/data/permission_repository_impl.dart';

void main() {
  late AuthRepositoryImpl auth;
  late PermissionRepositoryImpl permissions;
  late Future<http.Response> Function(http.Request) permissionResponse;
  var reads = 0;

  Future<void> login(String id) => auth.login(id, 'password').then((_) {});
  http.Response state(List<String> grants, {List<String> denied = const []}) =>
      http.Response(
        jsonEncode({
          'effectivePermissions': grants,
          'decisions': [
            for (final cap in grants) {'capability': cap, 'granted': true},
            for (final cap in denied) {'capability': cap, 'granted': false},
          ],
        }),
        200,
      );

  setUp(() async {
    reads = 0;
    auth = AuthRepositoryImpl(
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode({
            'user': {
              'id': jsonDecode(request.body)['email'],
              'displayName': 'Test',
            },
            'accessToken': 'real_access_token',
            'refreshToken': 'refresh',
            'expiresIn': 3600,
          }),
          200,
        ),
      ),
    );
    await login('alice');
    permissionResponse = (_) async =>
        state(['device.scanQRCode'], denied: ['contacts']);
    permissions = PermissionRepositoryImpl(
      authRepo: auth,
      usersUrl: 'https://example.test/api/v1/users',
      httpClient: MockClient((request) async {
        reads++;
        return permissionResponse(request);
      }),
    );
  });
  tearDown(() {
    permissions.dispose();
    auth.dispose();
  });

  test(
    'restores backend decisions and shares concurrent startup reads',
    () async {
      await Future.wait([
        permissions.ensurePermissionsLoaded('sdk_playground'),
        permissions.ensurePermissionsLoaded('sdk_playground'),
      ]);
      expect(reads, 1);
      expect(
        permissions.isGranted('sdk_playground', 'device.scanQRCode'),
        isTrue,
      );
      expect(
        permissions.isExplicitlyDenied('sdk_playground', 'contacts'),
        isTrue,
      );
      await permissions.ensurePermissionsLoaded('sdk_playground');
      expect(reads, 1);
    },
  );

  test('another account never inherits cached grants', () async {
    await permissions.ensurePermissionsLoaded('sdk_playground');
    await auth.logout();
    await login('bob');
    expect(
      permissions.isGranted('sdk_playground', 'device.scanQRCode'),
      isFalse,
    );
    permissionResponse = (_) async => state([]);
    await permissions.ensurePermissionsLoaded('sdk_playground');
    expect(
      permissions.isGranted('sdk_playground', 'device.scanQRCode'),
      isFalse,
    );
    expect(reads, 2);
  });

  test(
    'late response from a previous account cannot restore its grants',
    () async {
      final delayed = Completer<http.Response>();
      permissionResponse = (_) => delayed.future;
      final pending = permissions.ensurePermissionsLoaded('sdk_playground');
      await auth.logout();
      await login('bob');
      delayed.complete(state(['device.scanQRCode']));
      await pending;
      expect(
        permissions.isGranted('sdk_playground', 'device.scanQRCode'),
        isFalse,
      );
    },
  );

  test(
    'refresh replaces stale grants and respects platform revocations',
    () async {
      await permissions.ensurePermissionsLoaded('sdk_playground');
      permissionResponse = (_) async => http.Response(
        jsonEncode({
          'effectivePermissions': [],
          'decisions': [
            {'capability': 'device.scanQRCode', 'granted': true},
          ],
        }),
        200,
      );
      await permissions.fetchPermissionsFromBackend('sdk_playground');
      expect(
        permissions.isGranted('sdk_playground', 'device.scanQRCode'),
        isFalse,
      );
    },
  );

  test(
    'failed restore is retried rather than cached or treated as new consent',
    () async {
      permissionResponse = (_) async => http.Response('Unavailable', 503);
      await expectLater(
        permissions.ensurePermissionsLoaded('sdk_playground'),
        throwsA(anything),
      );
      permissionResponse = (_) async => state(['device.scanQRCode']);
      await permissions.ensurePermissionsLoaded('sdk_playground');
      expect(reads, 2);
      expect(
        permissions.isGranted('sdk_playground', 'device.scanQRCode'),
        isTrue,
      );
    },
  );
  test(
    'first dispatched action restores saved consent without a new dialog',
    () async {
      permissionResponse = (_) async => state(['user.getProfile']);
      final logs = DebugLogRepository();
      final authCodes = AuthCodeServiceShim();
      addTearDown(logs.dispose);
      final dispatcher = NativeActionDispatcher(
        authRepo: auth,
        authCodeService: authCodes,
        tokenService: TokenServiceShim(authCodeService: authCodes),
        userRepo: UserRepositoryImpl(authRepository: auth),
        deviceAdapter: DeviceAdapterImpl(),
        permissionRepo: permissions,
        debugLogRepo: logs,
      );
      // No BuildContext: this would fail with PERMISSION_DENIED if it prompted.
      final result = await dispatcher.dispatch(
        'user.getProfile',
        {},
        ActionContext(appId: 'sdk_playground'),
      );
      expect(result['id'], 'alice');
      expect(reads, 1);
      await dispatcher.dispatch('permission.check', {
        'capability': 'user.getProfile',
      }, ActionContext(appId: 'sdk_playground'));
      expect(reads, 1);
    },
  );
}
