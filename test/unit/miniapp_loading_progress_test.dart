import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:webview_platform_interface/webview_platform_interface.dart';
import 'package:superapp_platform/core/config/endpoint_config.dart';
import 'package:superapp_platform/features/mini_app_catalog/data/mini_app_repository.dart';
import 'package:superapp_platform/features/mini_app_runtime/presentation/mini_app_runtime_screen.dart';

class FakeWebViewPlatform extends WebViewPlatform {
  FakeWebViewController? lastController;
  FakeNavigationDelegate? lastDelegate;

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    final controller = FakeWebViewController(params);
    lastController = controller;
    return controller;
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) {
    final delegate = FakeNavigationDelegate(params);
    lastDelegate = delegate;
    return delegate;
  }

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) {
    return FakeWebViewWidget(params);
  }
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
}

class FakeNavigationDelegate extends PlatformNavigationDelegate {
  FakeNavigationDelegate(super.params) : super.implementation();

  void Function(int progress)? onProgressCallback;
  void Function(String url)? onPageStartedCallback;
  void Function(String url)? onPageFinishedCallback;

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

class FakeWebViewWidget extends PlatformWebViewWidget {
  FakeWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox(key: Key('fake_webview'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeWebViewPlatform fakePlatform;

  setUp(() {
    fakePlatform = FakeWebViewPlatform();
    WebViewPlatform.instance = fakePlatform;
  });

  testWidgets('MiniApp loading progress starts at 0%, advances smoothly across stages, and transitions into app', (tester) async {
    final mockClient = MockClient((request) async {
      if (request.url.path.contains('/catalog/apps/test_app')) {
        return http.Response(
          '{"id":"test_app","name":"Test Mini App","version":"1.0.0","runtimeType":"schema","category":"Utilities","entryUrl":"https://example.com/test","permissions":[],"schema":{}}',
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
          home: MiniAppRuntimeScreen(appId: 'test_app'),
        ),
      ),
    );

    // Initial frame: Must start at 0% (NOT 15%)
    expect(find.text('0%'), findsOneWidget);
    expect(find.text('Đang kiểm tra Mini App...'), findsOneWidget);

    // Ticker advances progress smoothly
    await tester.pump(const Duration(milliseconds: 90));
    final percentFinder = find.byWidgetPredicate(
      (widget) => widget is Text && widget.data != null && widget.data!.endsWith('%'),
    );
    expect(percentFinder, findsOneWidget);
    var textWidget = tester.widget<Text>(percentFinder);
    var percentVal = int.parse(textWidget.data!.replaceAll('%', ''));
    expect(percentVal, greaterThan(0));

    // Wait for manifest & permissions async requests to complete
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    // Progress continues to climb past 15% and 30%
    textWidget = tester.widget<Text>(percentFinder);
    percentVal = int.parse(textWidget.data!.replaceAll('%', ''));
    expect(percentVal, greaterThanOrEqualTo(25));

    // Simulate WebView page started & resource progress
    fakePlatform.lastDelegate?.onPageStartedCallback?.call('https://example.com/test');
    await tester.pump(const Duration(milliseconds: 100));

    // Simulate onProgress(80)
    fakePlatform.lastDelegate?.onProgressCallback?.call(80);
    await tester.pump(const Duration(milliseconds: 150));

    textWidget = tester.widget<Text>(percentFinder);
    percentVal = int.parse(textWidget.data!.replaceAll('%', ''));
    expect(percentVal, greaterThanOrEqualTo(65));

    // Simulate onPageFinished
    fakePlatform.lastDelegate?.onPageFinishedCallback?.call('https://example.com/test');
    await tester.pump(const Duration(milliseconds: 60));
    final currentFinder = find.byWidgetPredicate(
      (widget) => widget is Text && widget.data != null && widget.data!.endsWith('%'),
    );
    if (currentFinder.evaluate().isNotEmpty) {
      final t = tester.widget<Text>(currentFinder);
      print('Current progress after onPageFinished: ${t.data}');
    }

    // After animation delay, fade out and diagnostic check:
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 3000));

    // Loading overlay is now completely dismissed and WebView is active!
    expect(find.byKey(const Key('fake_webview')), findsOneWidget);
  });
}
