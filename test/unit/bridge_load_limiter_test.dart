import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_all/webview_all.dart';
import 'package:webview_platform_interface/webview_platform_interface.dart';
import 'package:superapp_platform/core/errors/bridge_error.dart';
import 'package:superapp_platform/features/debug_center/data/debug_log_repository.dart';
import 'package:superapp_platform/features/mini_app_bridge/bridge_dispatcher.dart';
import 'package:superapp_platform/features/mini_app_bridge/bridge_load_config.dart';
import 'package:superapp_platform/features/mini_app_bridge/user_interaction_queue.dart';
import 'package:superapp_platform/features/mini_app_catalog/domain/mini_app_manifest.dart';
import 'package:superapp_platform/features/native_actions/application/native_action_dispatcher.dart';
import 'package:superapp_platform/features/native_actions/domain/action_context.dart';
import 'package:superapp_platform/features/native_actions/domain/action_definition.dart';
import 'package:superapp_platform/features/permissions/presentation/permission_prompt_dialog.dart';
import '../support/auth_fixtures.dart';
import 'package:superapp_platform/features/authentication/data/auth_repository_impl.dart';
import 'package:superapp_platform/features/authentication/data/auth_code_service_shim.dart';
import 'package:superapp_platform/features/authentication/data/token_service_shim.dart';
import 'package:superapp_platform/features/user_profile/data/user_repository_impl.dart';
import 'package:superapp_platform/features/device/data/device_adapter_impl.dart';
import 'package:superapp_platform/features/permissions/data/permission_repository_impl.dart';

class MockPlatformWebViewController extends PlatformWebViewController {
  MockPlatformWebViewController(super.params) : super.implementation();

  String? mockUrl;
  final List<String> executedScripts = [];

  @override
  Future<String?> currentUrl() async => mockUrl;

  @override
  Future<void> runJavaScript(String javaScript) async {
    executedScripts.add(javaScript);
  }
}

class BlockingAsyncHandler implements NativeActionHandler {
  final Completer<void> completer = Completer<void>();

  @override
  String get actionName => 'test.blocking';

  @override
  String? get requiredCapability => null;

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    await completer.future;
    return {'status': 'unblocked'};
  }
}

class MockCapabilityActionHandler implements NativeActionHandler {
  @override
  String get actionName => 'test.permAction';

  @override
  String? get requiredCapability => 'test.permCapability';

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    return {'status': 'success'};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const manifest = MiniAppManifest(
    id: 'test_app',
    name: 'Test App',
    description: 'Test',
    version: '1.0.0',
    icon: 'test',
    entryUrl: 'https://superappplatfrom.alwaysdata.net/api/v1/miniapps/test_app/1.0.0/dist/index.html',
    capabilities: ['device.getDeviceInfo'],
  );

  group('Native Bridge Load Limiting Tests', () {
    late AuthRepositoryImpl authRepo;
    late AuthCodeServiceShim authCodeService;
    late TokenServiceShim tokenService;
    late UserRepositoryImpl userRepo;
    late DeviceAdapterImpl deviceAdapter;
    late PermissionRepositoryImpl permissionRepo;
    late DebugLogRepository debugLogRepo;
    late NativeActionDispatcher actionDispatcher;
    late MockPlatformWebViewController mockPlatform;
    late WebViewController controller;

    setUp(() {
      authRepo = TestAuthRepository();
      authCodeService = AuthCodeServiceShim();
      tokenService = TokenServiceShim(authCodeService: authCodeService);
      userRepo = UserRepositoryImpl(authRepository: authRepo);
      deviceAdapter = DeviceAdapterImpl();
      permissionRepo = PermissionRepositoryImpl();
      debugLogRepo = DebugLogRepository();

      actionDispatcher = NativeActionDispatcher(
        authRepo: authRepo,
        authCodeService: authCodeService,
        tokenService: tokenService,
        userRepo: userRepo,
        deviceAdapter: deviceAdapter,
        permissionRepo: permissionRepo,
        debugLogRepo: debugLogRepo,
      );

      mockPlatform = MockPlatformWebViewController(
        const PlatformWebViewControllerCreationParams(),
      )..mockUrl = manifest.entryUrl;
      controller = WebViewController.fromPlatform(mockPlatform);
    });

    tearDown(() {
      authRepo.dispose();
      debugLogRepo.dispose();
      actionDispatcher.dispose();
    });

    test('Message size limit rejects oversized payload before parsing JSON', () async {
      final dispatcher = BridgeDispatcher(
        actionDispatcher: actionDispatcher,
        debugLogRepo: debugLogRepo,
        controller: controller,
        manifest: manifest,
        backendBaseUrl: 'https://superappplatfrom.alwaysdata.net',
        loadConfig: const BridgeLoadConfig(
          maxMessageSizeBytes: 500, // Small limit for test
        ),
      );

      // Create a payload larger than 500 bytes
      final largeData = 'A' * 600;
      final oversizedJson = jsonEncode({
        'id': 'req_oversized_1',
        'action': 'debug.echo',
        'payload': {'data': largeData},
        'appId': 'test_app',
      });

      await dispatcher.handleMessage(oversizedJson, null);

      // Should record failure in debug log without throwing or freezing
      expect(debugLogRepo.logs.isNotEmpty, isTrue);
      final lastLog = debugLogRepo.logs.first;
      expect(lastLog.id, 'req_oversized_1');
      expect(lastLog.success, isFalse);
      expect(lastLog.errorMessage, contains('vượt quá giới hạn cho phép'));

      // Should dispatch a failure response back to WebView
      expect(mockPlatform.executedScripts.isNotEmpty, isTrue);
      expect(mockPlatform.executedScripts.first, contains('PAYLOAD_TOO_LARGE'));
      expect(mockPlatform.executedScripts.first, contains('req_oversized_1'));
    });

    test('Concurrency limit rejects requests exceeding max in-flight RPCs', () async {
      final blockingHandler = BlockingAsyncHandler();
      actionDispatcher.registerHandler(blockingHandler);

      final dispatcher = BridgeDispatcher(
        actionDispatcher: actionDispatcher,
        debugLogRepo: debugLogRepo,
        controller: controller,
        manifest: manifest,
        backendBaseUrl: 'https://superappplatfrom.alwaysdata.net',
        loadConfig: const BridgeLoadConfig(
          maxConcurrentRequests: 2, // Concurrency limit of 2
        ),
      );

      // Start 2 concurrent blocking RPCs
      final f1 = dispatcher.handleMessage(jsonEncode({
        'id': 'req_conc_1',
        'action': 'test.blocking',
        'payload': {},
        'appId': 'test_app',
      }), null);

      final f2 = dispatcher.handleMessage(jsonEncode({
        'id': 'req_conc_2',
        'action': 'test.blocking',
        'payload': {},
        'appId': 'test_app',
      }), null);

      // Both should be in-flight
      expect(dispatcher.inFlightRequestIds.length, 2);

      // Send 3rd request - should be immediately rejected with RATE_LIMIT_EXCEEDED
      await dispatcher.handleMessage(jsonEncode({
        'id': 'req_conc_3',
        'action': 'debug.echo',
        'payload': {'text': 'overflow'},
        'appId': 'test_app',
      }), null);

      // Verify 3rd request received rate limit failure response
      expect(mockPlatform.executedScripts.any((s) => s.contains('req_conc_3') && s.contains('RATE_LIMIT_EXCEEDED')), isTrue);

      // Unblock initial requests
      blockingHandler.completer.complete();
      await f1;
      await f2;

      // In-flight should return to 0
      expect(dispatcher.inFlightRequestIds, isEmpty);
    });

    test('Rate limiter restricts calls exceeding maxRequestsPerWindow', () async {
      final rateLimiter = BridgeRateLimiter(
        maxRequestsPerWindow: 3,
        windowDuration: const Duration(seconds: 1),
      );

      final dispatcher = BridgeDispatcher(
        actionDispatcher: actionDispatcher,
        debugLogRepo: debugLogRepo,
        controller: controller,
        manifest: manifest,
        backendBaseUrl: 'https://superappplatfrom.alwaysdata.net',
        rateLimiter: rateLimiter,
      );

      // 3 calls within window should succeed
      for (int i = 1; i <= 3; i++) {
        await dispatcher.handleMessage(jsonEncode({
          'id': 'req_rate_$i',
          'action': 'debug.echo',
          'payload': {'msg': 'ok'},
          'appId': 'test_app',
        }), null);
      }

      // Verify all 3 succeeded
      expect(debugLogRepo.logs.length, 3);
      expect(debugLogRepo.logs.every((l) => l.success), isTrue);

      // 4th call exceeds rate limit
      await dispatcher.handleMessage(jsonEncode({
        'id': 'req_rate_4',
        'action': 'debug.echo',
        'payload': {'msg': 'fail'},
        'appId': 'test_app',
      }), null);

      final lastLog = debugLogRepo.logs.first;
      expect(lastLog.id, 'req_rate_4');
      expect(lastLog.success, isFalse);
      expect(lastLog.errorMessage, contains('Tần suất gọi Bridge vượt quá giới hạn'));
    });

    test('UserInteractionQueue serializes user interaction modals and enforces capacity limit', () async {
      final queue = UserInteractionQueue(maxQueueSize: 2);
      final executionOrder = <int>[];

      final completer1 = Completer<void>();
      final completer2 = Completer<void>();

      // Task 1 starts immediately
      final f1 = queue.run(() async {
        executionOrder.add(1);
        await completer1.future;
        return 'res1';
      });

      expect(queue.activeCount, 1);
      expect(queue.pendingCount, 0);

      // Task 2 queues up
      final f2 = queue.run(() async {
        executionOrder.add(2);
        await completer2.future;
        return 'res2';
      });

      expect(queue.activeCount, 1);
      expect(queue.pendingCount, 1);

      // Task 3 queues up (reaches maxQueueSize = 2)
      final f3 = queue.run(() async {
        executionOrder.add(3);
        return 'res3';
      });

      expect(queue.pendingCount, 2);

      // Task 4 overflows queue capacity and must throw BridgeError.rateLimitExceeded
      expect(
        () => queue.run(() async => 'overflow'),
        throwsA(isA<BridgeError>().having((e) => e.code, 'code', BridgeErrorCode.rateLimitExceeded)),
      );

      // Finish Task 1
      completer1.complete();
      expect(await f1, 'res1');

      // Task 2 should now be running
      await Future<void>.delayed(Duration.zero);
      expect(queue.activeCount, 1);
      expect(executionOrder, [1, 2]);

      // Finish Task 2
      completer2.complete();
      expect(await f2, 'res2');

      // Task 3 runs and completes
      expect(await f3, 'res3');
      expect(executionOrder, [1, 2, 3]);
      expect(queue.activeCount, 0);
      expect(queue.pendingCount, 0);
    });

    test('UserInteractionQueue cancels pending tasks when disposed', () async {
      final queue = UserInteractionQueue(maxQueueSize: 5);
      final blocker = Completer<void>();

      final f1 = queue.run(() async {
        await blocker.future;
        return 1;
      });

      final f2 = queue.run(() async => 2);
      final f3 = queue.run(() async => 3);

      expect(queue.pendingCount, 2);

      // Dispose queue
      queue.dispose();

      // Pending tasks should fail with BridgeError.cancelled
      expect(f2, throwsA(isA<BridgeError>().having((e) => e.code, 'code', BridgeErrorCode.cancelled)));
      expect(f3, throwsA(isA<BridgeError>().having((e) => e.code, 'code', BridgeErrorCode.cancelled)));

      blocker.complete();
      await f1;
    });

    testWidgets('Permission prompt deduplication prevents multiple dialogs for concurrent requests', (tester) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) {
            capturedContext = context;
            return const Scaffold(body: Text('Host App'));
          },
        ),
      ));

      actionDispatcher.registerHandler(MockCapabilityActionHandler());

      const appManifest = MiniAppManifest(
        id: 'test_app',
        name: 'Test App',
        description: 'Test',
        version: '1.0.0',
        icon: 'test',
        entryUrl: 'https://superappplatfrom.alwaysdata.net/api/v1/miniapps/test_app/1.0.0/dist/index.html',
        capabilities: ['test.permCapability'],
      );

      final actionContext = ActionContext(
        appId: appManifest.id,
        manifest: appManifest,
        buildContext: capturedContext,
        userInteractionQueue: actionDispatcher.userInteractionQueue,
      );

      // Dispatch 3 concurrent calls requesting the same capability
      final f1 = actionDispatcher.dispatch('test.permAction', {}, actionContext);
      final f2 = actionDispatcher.dispatch('test.permAction', {}, actionContext);
      final f3 = actionDispatcher.dispatch('test.permAction', {}, actionContext);

      await tester.pumpAndSettle();

      // Only 1 permission prompt dialog should be shown
      expect(find.byType(PermissionPromptDialog), findsOneWidget);
      expect(find.text('Cho phép (Allow)'), findsOneWidget);

      // User grants permission
      await tester.tap(find.text('Cho phép (Allow)'));
      await tester.pumpAndSettle();

      // All 3 requests complete successfully
      final results = await Future.wait([f1, f2, f3]);
      expect(results.length, 3);
      for (final res in results) {
        expect(res, {'status': 'success'});
      }

      // Permission repository should now have granted status
      expect(permissionRepo.isGranted('test_app', 'test.permCapability'), isTrue);
    });
  });
}
