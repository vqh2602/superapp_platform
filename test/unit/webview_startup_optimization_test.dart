import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:webview_platform_interface/webview_platform_interface.dart';
import 'package:superapp_platform/core/config/endpoint_config.dart';
import 'package:superapp_platform/features/mini_app_catalog/data/mini_app_repository.dart';
import 'package:superapp_platform/features/mini_app_runtime/application/webview_engine_warmer.dart';
import 'package:superapp_platform/features/mini_app_runtime/presentation/mini_app_runtime_screen.dart';
import 'package:superapp_platform/features/permissions/data/permission_repository_impl.dart';

class MockWebViewPlatform extends WebViewPlatform {
  MockWebViewController? lastController;
  MockNavigationDelegate? lastDelegate;
  int controllerCreationCount = 0;

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    controllerCreationCount++;
    final controller = MockWebViewController(params);
    lastController = controller;
    return controller;
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) {
    final delegate = MockNavigationDelegate(params);
    lastDelegate = delegate;
    return delegate;
  }

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) {
    return MockWebViewWidget(params);
  }
}

class MockWebViewController extends PlatformWebViewController {
  MockWebViewController(super.params) : super.implementation();

  final List<String> loadedUrls = [];
  final List<String> executedScripts = [];
  Color? backgroundColor;

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> setBackgroundColor(Color color) async {
    backgroundColor = color;
  }

  @override
  Future<void> setPlatformNavigationDelegate(PlatformNavigationDelegate handler) async {}

  @override
  Future<void> addJavaScriptChannel(JavaScriptChannelParams javaScriptChannelParams) async {}

  @override
  Future<void> setOnConsoleMessage(void Function(JavaScriptConsoleMessage consoleMessage) onConsoleMessage) async {}

  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    loadedUrls.add(params.uri.toString());
  }

  @override
  Future<void> loadFlutterAsset(String key) async {
    loadedUrls.add(key);
  }

  @override
  Future<void> runJavaScript(String javaScript) async {
    executedScripts.add(javaScript);
  }

  @override
  Future<Object> runJavaScriptReturningResult(String javaScript) async => 'true';

  @override
  Future<void> reload() async {}

  @override
  Future<String?> currentUrl() async => loadedUrls.isNotEmpty ? loadedUrls.last : null;
}

class MockNavigationDelegate extends PlatformNavigationDelegate {
  MockNavigationDelegate(super.params) : super.implementation();

  void Function(int progress)? onProgressCallback;
  void Function(String url)? onPageStartedCallback;
  void Function(String url)? onPageFinishedCallback;

  @override
  Future<void> setOnNavigationRequest(NavigationRequestCallback onNavigationRequest) async {}

  @override
  Future<void> setOnProgress(void Function(int progress) onProgress) async {
    onProgressCallback = onProgress;
  }

  @override
  Future<void> setOnPageStarted(void Function(String url) onPageStarted) async {
    onPageStartedCallback = onPageStarted;
  }

  @override
  Future<void> setOnPageFinished(void Function(String url) onPageFinished) async {
    onPageFinishedCallback = onPageFinished;
  }

  @override
  Future<void> setOnWebResourceError(void Function(WebResourceError error) onWebResourceError) async {}
}

class MockWebViewWidget extends PlatformWebViewWidget {
  MockWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox(key: Key('mock_webview'));
}

class FailingPermissionRepository extends PermissionRepositoryImpl {
  @override
  Future<Map<String, bool>> ensurePermissionsLoaded(
    String appId, {
    Duration? ttl,
    bool forceRefresh = false,
  }) async {
    throw Exception('Simulated network error fetching permissions');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockWebViewPlatform mockPlatform;

  setUp(() {
    mockPlatform = MockWebViewPlatform();
    WebViewPlatform.instance = mockPlatform;
  });

  group('WebView Engine Warmer Tests', () {
    test('warmUp creates a clean WebViewController without loading any URL or scripts', () {
      final warmer = WebViewEngineWarmer();
      expect(warmer.hasPrewarmedEngine, isFalse);

      warmer.warmUp();
      expect(warmer.hasPrewarmedEngine, isTrue);
      expect(mockPlatform.controllerCreationCount, 1);
      expect(mockPlatform.lastController?.loadedUrls, isEmpty);
      expect(mockPlatform.lastController?.executedScripts, isEmpty);

      // Consuming returns the pre-warmed controller and empties warmer
      final consumed = warmer.consume();
      expect(consumed, isNotNull);
      expect(warmer.hasPrewarmedEngine, isFalse);

      // Consuming again returns null
      expect(warmer.consume(), isNull);
    });

    test('clear resets the pre-warmed controller to about:blank', () {
      final warmer = WebViewEngineWarmer();
      warmer.warmUp();
      expect(warmer.hasPrewarmedEngine, isTrue);

      warmer.clear();
      expect(warmer.hasPrewarmedEngine, isFalse);
      expect(mockPlatform.lastController?.loadedUrls, contains('about:blank'));
    });
  });

  group('Mini App Runtime Startup Optimization Tests', () {
    testWidgets('Startup runs authorization and permissions concurrently, using prewarmed controller', (tester) async {
      final warmer = WebViewEngineWarmer();
      warmer.warmUp();
      final prewarmedController = mockPlatform.lastController;

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/catalog/apps/fast_app')) {
          return http.Response(
            jsonEncode({
              'id': 'fast_app',
              'name': 'Fast App',
              'version': '1.0.0',
              'runtimeType': 'schema',
              'category': 'Utilities',
              'entryUrl': 'https://example.com/fast',
              'permissions': [],
              'schema': {'theme': {'backgroundColor': '#00FF00'}},
            }),
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
            webViewEngineWarmerProvider.overrideWithValue(warmer),
            backendEndpointProvider.overrideWith(() => BackendEndpointNotifier()),
          ],
          child: const MaterialApp(
            home: MiniAppRuntimeScreen(appId: 'fast_app'),
          ),
        ),
      );

      // Prewarmed controller was consumed; no extra controller was created
      expect(warmer.hasPrewarmedEngine, isFalse);
      expect(mockPlatform.controllerCreationCount, 1);

      // Pump to let concurrent authorization and permissions complete
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      // Theme background was applied to the controller
      expect(prewarmedController?.backgroundColor, isNotNull);

      // Entry URL was loaded after authorization and permission validation
      expect(prewarmedController?.loadedUrls, contains('https://example.com/fast'));
    });

    testWidgets('Revoked Mini App authorization strictly blocks execution and does not load Mini App URL', (tester) async {
      final warmer = WebViewEngineWarmer();
      warmer.warmUp();
      final prewarmedController = mockPlatform.lastController;

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/catalog/apps/revoked_app')) {
          return http.Response(
            jsonEncode({
              'id': 'revoked_app',
              'status': 'revoked',
              'isPublished': false,
            }),
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
            webViewEngineWarmerProvider.overrideWithValue(warmer),
            backendEndpointProvider.overrideWith(() => BackendEndpointNotifier()),
          ],
          child: const MaterialApp(
            home: MiniAppRuntimeScreen(appId: 'revoked_app'),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      // Must display license revocation error
      expect(
        find.text('Mini App "revoked_app" chưa được cấp phép thực thi hoặc đã bị thu hồi quyền'),
        findsOneWidget,
      );

      // Mini App entry URL was NEVER loaded
      expect(prewarmedController?.loadedUrls.where((u) => u != 'about:blank'), isEmpty);
    });

    testWidgets('Failed permission loading strictly blocks Mini App execution', (tester) async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/catalog/apps/err_perm_app')) {
          return http.Response(
            jsonEncode({
              'id': 'err_perm_app',
              'name': 'Err Perm App',
              'version': '1.0.0',
              'runtimeType': 'schema',
              'category': 'Utilities',
              'entryUrl': 'https://example.com/err_perm',
              'permissions': [],
              'schema': {},
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        // Permissions fetch failure: 500 Internal Server Error
        return http.Response('Server Error', 500);
      });

      final testRepo = MiniAppRepository(
        httpClient: mockClient,
        catalogUrl: 'https://example.com/api/v1/catalog',
      );

      final failingPermissionRepo = FailingPermissionRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            miniAppRepositoryProvider.overrideWithValue(testRepo),
            permissionRepositoryProvider.overrideWithValue(failingPermissionRepo),
            backendEndpointProvider.overrideWith(() => BackendEndpointNotifier()),
          ],
          child: const MaterialApp(
            home: MiniAppRuntimeScreen(appId: 'err_perm_app'),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      // Even if authorization succeeded, permission error blocks execution
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Text && (widget.data?.contains('Không thể tải quyền') ?? false),
        ),
        findsWidgets,
      );

      // Mini App entry URL was NEVER loaded
      expect(
        mockPlatform.lastController?.loadedUrls.where((u) => u.contains('err_perm')),
        isEmpty,
      );
    });
  });
}
