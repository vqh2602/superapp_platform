import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:webview_all/webview_all.dart';
import 'package:webview_platform_interface/webview_platform_interface.dart';
import 'package:superapp_platform/core/config/endpoint_config.dart';
import 'package:superapp_platform/core/errors/bridge_error.dart';
import 'package:superapp_platform/features/debug_center/data/debug_log_repository.dart';
import 'package:superapp_platform/features/mini_app_bridge/bridge_dispatcher.dart';
import 'package:superapp_platform/features/mini_app_catalog/data/mini_app_repository.dart';
import 'package:superapp_platform/features/mini_app_catalog/domain/mini_app_manifest.dart';
import 'package:superapp_platform/features/mini_app_runtime/domain/mini_app_runtime_session.dart';
import 'package:superapp_platform/features/mini_app_runtime/presentation/mini_app_runtime_screen.dart';
import 'package:superapp_platform/features/native_actions/application/native_action_dispatcher.dart';
import 'package:superapp_platform/features/native_actions/domain/action_context.dart';
import 'package:superapp_platform/features/native_actions/domain/action_definition.dart';
import '../support/auth_fixtures.dart';
import 'package:superapp_platform/features/authentication/data/auth_code_service_shim.dart';
import 'package:superapp_platform/features/authentication/data/token_service_shim.dart';
import 'package:superapp_platform/features/user_profile/data/user_repository_impl.dart';
import 'package:superapp_platform/features/device/data/device_adapter_impl.dart';
import 'package:superapp_platform/features/permissions/data/permission_repository_impl.dart';
import 'package:superapp_platform/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:superapp_platform/features/authentication/domain/models/auth_session.dart';
import 'package:superapp_platform/features/authentication/domain/models/platform_user.dart';

class FakeAuthNotifier extends AuthNotifier {
  final AuthState initial;
  FakeAuthNotifier([this.initial = const AuthState()]);

  @override
  AuthState build() => initial;

  void setAuthenticatedUser(String userId, String username) {
    state = AuthState(
      session: AuthSession(
        accessToken: 'token_$userId',
        refreshToken: 'refresh_$userId',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        user: PlatformUser(
          id: userId,
          name: username,
          phone: '0901234567',
          role: 'customer',
          email: '$username@example.com',
        ),
      ),
    );
  }

  void logoutUser() {
    state = const AuthState();
  }
}

class MockPlatformWebViewController extends PlatformWebViewController {
  MockPlatformWebViewController(super.params) : super.implementation();

  String? mockUrl;
  final List<String> executedScripts = [];
  String? lastLoadedRequest;

  @override
  Future<String?> currentUrl() async => mockUrl;

  @override
  Future<void> runJavaScript(String javaScript) async {
    executedScripts.add(javaScript);
  }

  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    lastLoadedRequest = params.uri.toString();
  }
}

class FakeWebViewWidget extends PlatformWebViewWidget {
  FakeWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox(key: Key('fake_webview'));
}

class FakeNavigationDelegate extends PlatformNavigationDelegate {
  FakeNavigationDelegate(super.params) : super.implementation();

  @override
  Future<void> setOnNavigationRequest(NavigationRequestCallback onNavigationRequest) async {}

  @override
  Future<void> setOnProgress(void Function(int progress) onProgress) async {}

  @override
  Future<void> setOnPageStarted(void Function(String url) onPageStarted) async {}

  @override
  Future<void> setOnPageFinished(void Function(String url) onPageFinished) async {}

  @override
  Future<void> setOnWebResourceError(void Function(WebResourceError error) onWebResourceError) async {}
}

class FakeWebViewController extends PlatformWebViewController {
  FakeWebViewController(super.params) : super.implementation();

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> setBackgroundColor(Color color) async {}

  @override
  Future<void> setPlatformNavigationDelegate(PlatformNavigationDelegate handler) async {}

  @override
  Future<void> addJavaScriptChannel(JavaScriptChannelParams javaScriptChannelParams) async {}

  @override
  Future<void> setOnConsoleMessage(void Function(JavaScriptConsoleMessage consoleMessage) onConsoleMessage) async {}

  @override
  Future<void> loadRequest(LoadRequestParams params) async {}

  @override
  Future<void> loadFlutterAsset(String key) async {}

  @override
  Future<void> runJavaScript(String javaScript) async {}

  @override
  Future<Object> runJavaScriptReturningResult(String javaScript) async => 'true';

  @override
  Future<void> reload() async {}

  @override
  Future<String?> currentUrl() async => 'https://example.com/test';
}

class FakeWebViewPlatform extends WebViewPlatform {
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) => FakeWebViewController(params);

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => FakeNavigationDelegate(params);

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => FakeWebViewWidget(params);
}

class SlowAsyncActionHandler implements NativeActionHandler {
  final Completer<String> completer = Completer<String>();

  @override
  String get actionName => 'custom.slowAsync';

  @override
  String? get requiredCapability => null;

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    final result = await completer.future;
    return {'result': result};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const manifest = MiniAppManifest(
    id: 'test_app',
    name: 'Test App',
    description: 'Unit test app',
    version: '1.0.0',
    icon: 'test',
    entryUrl: 'https://superappplatfrom.alwaysdata.net/api/v1/miniapps/test_app/1.0.0/dist/index.html',
    capabilities: ['device.getDeviceInfo'],
  );

  group('4.3 WebView Session Lifecycle & Isolation Tests', () {
    test('MiniAppRuntimeSession isolates controller, timers, and lifecycle state', () {
      final session = MiniAppRuntimeSession(
        sessionId: 'sess_uuid_1',
        appId: 'test_app',
      );

      expect(session.sessionId, 'sess_uuid_1');
      expect(session.appId, 'test_app');
      expect(session.isActive, isTrue);
      expect(session.isDisposed, isFalse);

      bool timer1Fired = false;
      bool timer2Fired = false;
      final t1 = Timer(const Duration(seconds: 10), () => timer1Fired = true);
      final t2 = Timer(const Duration(seconds: 10), () => timer2Fired = true);

      session.loadTimeoutTimer = t1;
      session.registerTimer(t2);

      final mockPlatform = MockPlatformWebViewController(
        const PlatformWebViewControllerCreationParams(),
      );
      final controller = WebViewController.fromPlatform(mockPlatform);
      session.controller = controller;

      // Dispose session
      session.dispose();

      expect(session.isDisposed, isTrue);
      expect(session.isActive, isFalse);
      expect(session.controller, isNull);
      expect(session.loadTimeoutTimer, isNull);
      expect(mockPlatform.lastLoadedRequest, 'about:blank');
      expect(t1.isActive, isFalse);
      expect(t2.isActive, isFalse);
      expect(timer1Fired, isFalse);
      expect(timer2Fired, isFalse);

      // Registering timer after dispose cancels immediately
      bool timer3Fired = false;
      final t3 = Timer(const Duration(seconds: 10), () => timer3Fired = true);
      session.registerTimer(t3);
      expect(t3.isActive, isFalse);
      expect(timer3Fired, isFalse);
    });

    test('BridgeDispatcher drops ongoing RPC and blocks response when session is disposed during execution', () async {
      final mockPlatform = MockPlatformWebViewController(
        const PlatformWebViewControllerCreationParams(),
      )..mockUrl = manifest.entryUrl;
      final controller = WebViewController.fromPlatform(mockPlatform);

      final authRepo = TestAuthRepository();
      final authCodeService = AuthCodeServiceShim();
      final tokenService = TokenServiceShim(authCodeService: authCodeService);
      final userRepo = UserRepositoryImpl(authRepository: authRepo);
      final deviceAdapter = DeviceAdapterImpl();
      final permissionRepo = PermissionRepositoryImpl();
      final debugLogRepo = DebugLogRepository();

      final slowHandler = SlowAsyncActionHandler();
      final actionDispatcher = NativeActionDispatcher(
        authRepo: authRepo,
        authCodeService: authCodeService,
        tokenService: tokenService,
        userRepo: userRepo,
        deviceAdapter: deviceAdapter,
        permissionRepo: permissionRepo,
        debugLogRepo: debugLogRepo,
      );
      actionDispatcher.registerHandler(slowHandler);

      final dispatcher = BridgeDispatcher(
        actionDispatcher: actionDispatcher,
        debugLogRepo: debugLogRepo,
        controller: controller,
        manifest: manifest,
        backendBaseUrl: 'https://superappplatfrom.alwaysdata.net',
        runtimeSessionId: 'sess_active_123',
      );

      final requestPayload = jsonEncode({
        'id': 'rpc_request_999',
        'action': 'custom.slowAsync',
        'payload': {'msg': 'hello'},
        'appId': 'test_app',
        'sessionId': 'sess_active_123',
      });

      // 1. Dispatch RPC message into dispatcher (starts async work)
      final handleFuture = dispatcher.handleMessage(requestPayload, null);

      // Verify RPC is marked in-flight
      expect(dispatcher.inFlightRequestIds, contains('rpc_request_999'));

      // 2. Simulate session termination (switch mini app or page unmount)
      dispatcher.dispose();
      expect(dispatcher.isDisposed, isTrue);
      expect(dispatcher.inFlightRequestIds, isEmpty);

      // 3. Complete the background async task from old RPC
      slowHandler.completer.complete('async_done');
      await handleFuture;

      // 4. Verify no response script was dispatched to controller (blocked from reaching old WebView)
      expect(mockPlatform.executedScripts, isEmpty);

      // 5. Subsequent RPC messages on disposed dispatcher are ignored immediately
      await dispatcher.handleMessage(requestPayload, null);
      expect(mockPlatform.executedScripts, isEmpty);

      authRepo.dispose();
      debugLogRepo.dispose();
    });

    test('ActionContext checkCancelled throws BridgeError.cancelled when session is inactive', () {
      bool isSessionActive = true;
      final context = ActionContext(
        appId: 'test_app',
        manifest: manifest,
        runtimeSessionId: 'test_sess',
        isSessionActive: () => isSessionActive,
      );

      expect(context.isCancelled, isFalse);
      expect(() => context.checkCancelled(), returnsNormally);

      // Session disposed or switched
      isSessionActive = false;
      expect(context.isCancelled, isTrue);
      expect(
        () => context.checkCancelled(),
        throwsA(isA<BridgeError>().having((e) => e.code, 'code', BridgeErrorCode.cancelled)),
      );
    });

    test('NativeActionDispatcher rejects cancelled ActionContext before executing action', () async {
      final authRepo = TestAuthRepository();
      final authCodeService = AuthCodeServiceShim();
      final tokenService = TokenServiceShim(authCodeService: authCodeService);
      final userRepo = UserRepositoryImpl(authRepository: authRepo);
      final deviceAdapter = DeviceAdapterImpl();
      final permissionRepo = PermissionRepositoryImpl();
      final debugLogRepo = DebugLogRepository();

      final actionDispatcher = NativeActionDispatcher(
        authRepo: authRepo,
        authCodeService: authCodeService,
        tokenService: tokenService,
        userRepo: userRepo,
        deviceAdapter: deviceAdapter,
        permissionRepo: permissionRepo,
        debugLogRepo: debugLogRepo,
      );

      final cancelledContext = ActionContext(
        appId: 'test_app',
        manifest: manifest,
        isSessionActive: () => false, // Already cancelled session
      );

      expect(
        () => actionDispatcher.dispatch('debug.echo', {'msg': 'test'}, cancelledContext),
        throwsA(isA<BridgeError>().having((e) => e.code, 'code', BridgeErrorCode.cancelled)),
      );

      authRepo.dispose();
      debugLogRepo.dispose();
    });

    test('Switching Mini App generates distinct runtimeSessionId and cleans up old session resources', () {
      final sessionA = MiniAppRuntimeSession(sessionId: 'session_A', appId: 'app_a');
      final sessionB = MiniAppRuntimeSession(sessionId: 'session_B', appId: 'app_b');

      expect(sessionA.sessionId, isNot(equals(sessionB.sessionId)));

      // Session A setup
      final mockPlatformA = MockPlatformWebViewController(
        const PlatformWebViewControllerCreationParams(),
      );
      sessionA.controller = WebViewController.fromPlatform(mockPlatformA);
      sessionA.loadTimeoutTimer = Timer(const Duration(minutes: 1), () {});

      // Switch Mini App: dispose session A
      sessionA.dispose();
      expect(sessionA.isDisposed, isTrue);
      expect(sessionA.controller, isNull);
      expect(sessionA.loadTimeoutTimer, isNull);
      expect(mockPlatformA.lastLoadedRequest, 'about:blank');

      // Session B remains completely clean and active
      expect(sessionB.isActive, isTrue);
      expect(sessionB.isDisposed, isFalse);
    });

    testWidgets('MiniAppRuntimeScreen switching mini app terminates old session and generates fresh runtimeSessionId', (tester) async {
      final fakePlatform = FakeWebViewPlatform();
      WebViewPlatform.instance = fakePlatform;

      final mockClient = MockClient((request) async {
        final path = request.url.path;
        if (path.contains('app_1')) {
          return http.Response(
            '{"id":"app_1","name":"App One","version":"1.0.0","runtimeType":"schema","category":"Utilities","entryUrl":"https://example.com/app1","permissions":[],"schema":{}}',
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (path.contains('app_2')) {
          return http.Response(
            '{"id":"app_2","name":"App Two","version":"1.0.0","runtimeType":"schema","category":"Utilities","entryUrl":"https://example.com/app2","permissions":[],"schema":{}}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{"effectivePermissions":[]}', 200);
      });

      final testRepo = MiniAppRepository(
        httpClient: mockClient,
        catalogUrl: 'https://example.com/api/v1/catalog',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            miniAppRepositoryProvider.overrideWithValue(testRepo),
            backendEndpointProvider.overrideWith(() => BackendEndpointNotifier()),
          ],
          child: const MaterialApp(
            home: MiniAppRuntimeScreen(appId: 'app_1'),
          ),
        ),
      );

      // Let session 1 initialize
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      final state = tester.state(find.byType(MiniAppRuntimeScreen)) as dynamic;
      final session1 = state.currentSession as MiniAppRuntimeSession;
      final sessionId1 = state.runtimeSessionId as String;

      expect(session1.appId, 'app_1');
      expect(session1.isActive, isTrue);
      expect(sessionId1.isNotEmpty, isTrue);

      // Trigger mini app switch to app_2 via session's bridge dispatcher
      await session1.dispatcher?.handleMessage(
        jsonEncode({
          'id': 'nav_req_1',
          'action': 'navigation.openMiniApp',
          'payload': {'appId': 'app_2'},
          'appId': 'app_1',
          'sessionId': sessionId1,
        }),
        null,
      );

      // Settle UI transitions
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Session 1 MUST be cancelled and disposed
      expect(session1.isDisposed, isTrue);
      expect(session1.isActive, isFalse);

      // Session 2 is active with distinct runtimeSessionId and new appId
      final session2 = state.currentSession as MiniAppRuntimeSession;
      final sessionId2 = state.runtimeSessionId as String;

      expect(session2, isNot(equals(session1)));
      expect(sessionId2, isNot(equals(sessionId1)));
      expect(session2.appId, 'app_2');
      expect(session2.isActive, isTrue);
    });

    testWidgets('MiniAppRuntimeScreen terminates session when user logs out and reinitializes on account switch', (tester) async {
      final fakePlatform = FakeWebViewPlatform();
      WebViewPlatform.instance = fakePlatform;

      final mockClient = MockClient((request) async {
        return http.Response(
          '{"id":"app_1","name":"App One","version":"1.0.0","runtimeType":"schema","category":"Utilities","entryUrl":"https://example.com/app1","permissions":[],"schema":{}}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final testRepo = MiniAppRepository(
        httpClient: mockClient,
        catalogUrl: 'https://example.com/api/v1/catalog',
      );

      final fakeAuthNotifier = FakeAuthNotifier(
        AuthState(
          session: AuthSession(
            accessToken: 'token_u1',
            refreshToken: 'refresh_u1',
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
            user: const PlatformUser(
              id: 'user_1',
              name: 'user1',
              phone: '0901234567',
              role: 'customer',
              email: 'user1@example.com',
            ),
          ),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            miniAppRepositoryProvider.overrideWithValue(testRepo),
            backendEndpointProvider.overrideWith(() => BackendEndpointNotifier()),
            authStateProvider.overrideWith(() => fakeAuthNotifier),
          ],
          child: const MaterialApp(
            home: MiniAppRuntimeScreen(appId: 'app_1'),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      final state = tester.state(find.byType(MiniAppRuntimeScreen)) as dynamic;
      final session1 = state.currentSession as MiniAppRuntimeSession;
      expect(session1.isActive, isTrue);
      expect(session1.dispatcher?.userId, 'user_1');

      // 1. Account switch from user_1 to user_2
      fakeAuthNotifier.setAuthenticatedUser('user_2', 'user2');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Old session must be disposed
      expect(session1.isDisposed, isTrue);

      // New session must be active with user_2
      final session2 = state.currentSession as MiniAppRuntimeSession;
      expect(session2, isNot(equals(session1)));
      expect(session2.isActive, isTrue);
      expect(session2.dispatcher?.userId, 'user_2');

      // 2. User logs out
      fakeAuthNotifier.logoutUser();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Session 2 must be disposed and currentSession cleared
      expect(session2.isDisposed, isTrue);
      expect(state.currentSession, isNull);
    });
  });
}
