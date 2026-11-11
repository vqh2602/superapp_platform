import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:superapp_platform/core/errors/bridge_error.dart';
import 'package:superapp_platform/features/authentication/data/auth_code_service_shim.dart';
import 'package:superapp_platform/features/authentication/data/auth_repository_impl.dart';
import 'package:superapp_platform/features/authentication/data/token_service_shim.dart';
import 'package:superapp_platform/features/debug_center/data/debug_log_repository.dart';
import 'package:superapp_platform/features/device/data/device_adapter_impl.dart';
import 'package:superapp_platform/features/mini_app_catalog/domain/mini_app_manifest.dart';
import 'package:superapp_platform/core/security/runtime_security_context.dart';
import 'package:superapp_platform/features/native_actions/application/native_action_dispatcher.dart';
import 'package:superapp_platform/features/native_actions/domain/action_context.dart';
import 'package:superapp_platform/features/permissions/application/permission_service.dart';
import 'package:superapp_platform/features/permissions/data/permission_repository_impl.dart';
import 'package:superapp_platform/features/permissions/presentation/permission_prompt_dialog.dart';
import 'package:superapp_platform/features/user_profile/data/user_repository_impl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PermissionService Comprehensive Tests', () {
    late AuthRepositoryImpl authRepo;
    late PermissionRepositoryImpl permissionRepo;
    late PermissionService permissionService;
    late NativeActionDispatcher dispatcher;
    late Future<http.Response> Function(http.Request) backendHandler;

    const manifest = MiniAppManifest(
      id: 'demo_app',
      name: 'Demo Mini App',
      description: 'Demo App description',
      version: '1.0.0',
      icon: 'icon',
      entryUrl: 'https://superappplatfrom.alwaysdata.net/api/v1/miniapps/demo_app/1.0.0/dist/index.html',
      capabilities: ['device.getLocation', 'device.scanQRCode'],
    );

    setUp(() async {
      backendHandler = (req) async => http.Response('{}', 200);

      authRepo = AuthRepositoryImpl(
        httpClient: MockClient((req) async {
          return http.Response(
            jsonEncode({
              'user': {'id': 'user_test', 'displayName': 'Tester'},
              'accessToken': 'valid_token',
              'refreshToken': 'valid_refresh',
              'expiresIn': 3600,
            }),
            200,
          );
        }),
      );
      await authRepo.login('user_test', 'secret');

      permissionRepo = PermissionRepositoryImpl(
        authRepo: authRepo,
        usersUrl: 'https://superappplatfrom.alwaysdata.net/api/v1/users',
        httpClient: MockClient((req) => backendHandler(req)),
      );

      permissionService = PermissionService(permissionRepo: permissionRepo);

      dispatcher = NativeActionDispatcher(
        authRepo: authRepo,
        authCodeService: AuthCodeServiceShim(),
        tokenService: TokenServiceShim(authCodeService: AuthCodeServiceShim()),
        userRepo: UserRepositoryImpl(authRepository: authRepo),
        deviceAdapter: DeviceAdapterImpl(),
        permissionRepo: permissionRepo,
        permissionService: permissionService,
        debugLogRepo: DebugLogRepository(),
      );
    });

    tearDown(() {
      dispatcher.dispose();
      authRepo.dispose();
      permissionRepo.dispose();
    });

    test('permission.request denies capability when not declared in Manifest', () async {
      final context = ActionContext(
        appId: manifest.id,
        manifest: manifest,
      );

      // 'microphone' is NOT declared in manifest.capabilities
      expect(
        () => dispatcher.dispatch('permission.request', {
          'capability': 'microphone',
        }, context),
        throwsA(
          isA<BridgeError>().having(
            (e) => e.code,
            'code',
            BridgeErrorCode.permissionDenied,
          ).having(
            (e) => e.message,
            'message',
            contains('is not declared in Mini App manifest'),
          ),
        ),
      );
    });

    test('permission.request denies capability when not in RuntimeSecurityContext', () async {
      final securityContext = RuntimeSecurityContext(
        appId: manifest.id,
        approvedOrigin: manifest.entryUrl,
        activeVersion: manifest.version,
        runtimeSessionId: 'sess_1',
        allowedCapabilities: {'device.scanQRCode'}, // Only QR allowed
      );

      final context = ActionContext(
        appId: manifest.id,
        manifest: manifest,
        securityContext: securityContext,
      );

      // 'device.getLocation' is declared in manifest but restricted in securityContext
      expect(
        () => dispatcher.dispatch('permission.request', {
          'capability': 'device.getLocation',
        }, context),
        throwsA(
          isA<BridgeError>().having(
            (e) => e.code,
            'code',
            BridgeErrorCode.permissionDenied,
          ),
        ),
      );
    });

    testWidgets('permission.request shares prompt with concurrent action dispatch (Deduplication)', (tester) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (ctx) {
            capturedContext = ctx;
            return const Scaffold(body: Text('Host'));
          },
        ),
      ));

      final actionContext = ActionContext(
        appId: manifest.id,
        manifest: manifest,
        buildContext: capturedContext,
        userInteractionQueue: dispatcher.userInteractionQueue,
      );

      // Concurrent request via permission.request AND direct action dispatch
      final f1 = dispatcher.dispatch('permission.request', {
        'capability': 'device.scanQRCode',
      }, actionContext);

      final f2 = dispatcher.dispatch('permission.request', {
        'capability': 'device.scanQRCode',
      }, actionContext);

      await tester.pumpAndSettle();

      // Only ONE dialog must be shown
      expect(find.byType(PermissionPromptDialog), findsOneWidget);
      expect(find.text('Cho phép (Allow)'), findsOneWidget);

      // User allows
      await tester.tap(find.text('Cho phép (Allow)'));
      await tester.pumpAndSettle();

      final res1 = await f1;
      final res2 = await f2;

      expect(res1['granted'], isTrue);
      expect(res2['granted'], isTrue);
      expect(permissionService.isGranted(manifest.id, 'device.scanQRCode'), isTrue);
    });

    test('Atomic Sync: Rollback memory state when backend sync fails', () async {
      // Configure backend to fail on PUT permission
      backendHandler = (req) async {
        if (req.method == 'PUT') {
          return http.Response('Internal Server Error', 500);
        }
        return http.Response('{}', 200);
      };

      // Initial state is ungranted
      expect(permissionService.isGranted(manifest.id, 'device.getLocation'), isFalse);

      // Attempt to grant permission - backend fails with 500
      await expectLater(
        () => permissionRepo.updatePermission(manifest.id, 'device.getLocation', true),
        throwsA(isA<BridgeError>().having((e) => e.code, 'code', BridgeErrorCode.internalError)),
      );

      // Crucial: Client state must be rolled back to ungranted!
      expect(permissionRepo.isGranted(manifest.id, 'device.getLocation'), isFalse);
      expect(permissionService.isGranted(manifest.id, 'device.getLocation'), isFalse);
    });

    test('Atomic Sync: Rollback to previous state when revoking fails on backend', () async {
      // Pre-grant permission
      await permissionRepo.updatePermission(manifest.id, 'device.getLocation', true);
      expect(permissionRepo.isGranted(manifest.id, 'device.getLocation'), isTrue);

      backendHandler = (req) async => http.Response('Service Unavailable', 503);

      // Attempt to revoke - backend fails
      await expectLater(
        () => permissionRepo.updatePermission(manifest.id, 'device.getLocation', false),
        throwsA(isA<BridgeError>().having((e) => e.code, 'code', BridgeErrorCode.internalError)),
      );

      // Crucial: Client state must be rolled back to true (previous granted state)!
      expect(permissionRepo.isGranted(manifest.id, 'device.getLocation'), isTrue);
      expect(permissionService.isGranted(manifest.id, 'device.getLocation'), isTrue);
    });

    testWidgets('Atomic Sync: Successfully persists to client when backend returns 200', (tester) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (ctx) {
            capturedContext = ctx;
            return const Scaffold(body: Text('Host'));
          },
        ),
      ));

      final actionContext = ActionContext(
        appId: manifest.id,
        manifest: manifest,
        buildContext: capturedContext,
        userInteractionQueue: dispatcher.userInteractionQueue,
      );

      int backendSyncCalls = 0;
      backendHandler = (req) async {
        if (req.method == 'PUT') {
          backendSyncCalls++;
          return http.Response('{"success": true}', 200);
        }
        return http.Response('{}', 200);
      };

      final future = dispatcher.dispatch('permission.request', {
        'capability': 'device.getLocation',
      }, actionContext);

      await tester.pumpAndSettle();

      await tester.tap(find.text('Cho phép (Allow)'));
      await tester.pumpAndSettle();

      final result = await future;
      expect(result['granted'], isTrue);
      expect(backendSyncCalls, 1);
      expect(permissionService.isGranted(manifest.id, 'device.getLocation'), isTrue);
    });

    test('permission.request honors session cancellation and throws cancelled', () async {
      final cancelledContext = ActionContext(
        appId: manifest.id,
        manifest: manifest,
        isSessionActive: () => false, // Session cancelled
      );

      expect(
        () => dispatcher.dispatch('permission.request', {
          'capability': 'device.getLocation',
        }, cancelledContext),
        throwsA(isA<BridgeError>().having((e) => e.code, 'code', BridgeErrorCode.cancelled)),
      );
    });

    test('PermissionService.updatePermission performs atomic sync and rolls back on failure', () async {
      int putCalls = 0;
      backendHandler = (req) async {
        if (req.method == 'PUT') {
          putCalls++;
          return http.Response('Internal Server Error', 500);
        }
        return http.Response('{}', 200);
      };

      // Gọi updatePermission qua PermissionService
      await expectLater(
        () => permissionService.updatePermission(manifest.id, 'device.getLocation', true),
        throwsA(isA<BridgeError>().having((e) => e.code, 'code', BridgeErrorCode.internalError)),
      );

      expect(putCalls, 1);
      // Trạng thái bộ nhớ phải được rollback về false (chưa cấp)
      expect(permissionService.isGranted(manifest.id, 'device.getLocation'), isFalse);
      expect(permissionRepo.isGranted(manifest.id, 'device.getLocation'), isFalse);
    });

    test('PermissionService.revokeAll performs atomic sync and rolls back on failure', () async {
      // Thiết lập quyền ban đầu
      backendHandler = (req) async => http.Response('{}', 200);
      await permissionService.updatePermission(manifest.id, 'device.getLocation', true);
      expect(permissionService.isGranted(manifest.id, 'device.getLocation'), isTrue);

      // Backend lỗi khi DELETE
      backendHandler = (req) async {
        if (req.method == 'DELETE') {
          return http.Response('Service Unavailable', 503);
        }
        return http.Response('{}', 200);
      };

      await expectLater(
        () => permissionService.revokeAll(manifest.id),
        throwsA(isA<BridgeError>().having((e) => e.code, 'code', BridgeErrorCode.internalError)),
      );

      // Toàn bộ quyền đã cấp trước đó phải được phục hồi (rollback)
      expect(permissionService.isGranted(manifest.id, 'device.getLocation'), isTrue);
      expect(permissionRepo.isGranted(manifest.id, 'device.getLocation'), isTrue);
    });

    test('Deprecated setPermission routes through updatePermission and rolls back on failure', () async {
      backendHandler = (req) async {
        if (req.method == 'PUT') {
          return http.Response('Bad Gateway', 502);
        }
        return http.Response('{}', 200);
      };

      // setPermission cũ gọi updatePermission ngầm định
      // ignore: deprecated_member_use_from_same_package
      permissionRepo.setPermission(manifest.id, 'device.getLocation', true);

      // Chờ một chút để unawaited future hoàn thành
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Không còn hiện tượng fire-and-forget nuốt lỗi và giữ nguyên memory:
      // Memory đã được rollback an toàn về false!
      expect(permissionRepo.isGranted(manifest.id, 'device.getLocation'), isFalse);
      expect(permissionService.isGranted(manifest.id, 'device.getLocation'), isFalse);
    });
  });
}
