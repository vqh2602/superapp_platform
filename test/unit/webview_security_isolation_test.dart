import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:superapp_platform/core/errors/bridge_error.dart';
import 'package:superapp_platform/core/security/mini_app_security_policy.dart';
import 'package:superapp_platform/core/security/runtime_security_context.dart';
import 'package:superapp_platform/features/authentication/data/auth_code_service_shim.dart';
import 'package:superapp_platform/features/authentication/data/auth_repository_impl.dart';
import 'package:superapp_platform/features/authentication/data/token_service_shim.dart';
import 'package:superapp_platform/features/debug_center/data/debug_log_repository.dart';
import 'package:superapp_platform/features/device/data/device_adapter_impl.dart';
import 'package:superapp_platform/features/mini_app_bridge/bridge_dispatcher.dart';
import 'package:superapp_platform/features/mini_app_catalog/domain/mini_app_manifest.dart';
import 'package:superapp_platform/features/native_actions/application/native_action_dispatcher.dart';
import 'package:superapp_platform/features/native_actions/domain/action_context.dart';
import 'package:superapp_platform/features/permissions/data/permission_repository_impl.dart';
import 'package:superapp_platform/features/user_profile/data/user_repository_impl.dart';
import 'package:webview_all/webview_all.dart';
import 'package:webview_platform_interface/webview_platform_interface.dart';
import '../support/auth_fixtures.dart';

class MockPlatformWebViewController extends PlatformWebViewController {
  MockPlatformWebViewController(super.params) : super.implementation();

  String? mockUrl;

  @override
  Future<String?> currentUrl() async => mockUrl;

  @override
  Future<void> runJavaScript(String javaScript) async {}
}

void main() {
  group('MiniAppSecurityPolicy URL Validation Tests', () {
    const webManifest = MiniAppManifest(
      id: 'store_app',
      name: 'Store App',
      description: 'Online Store',
      version: '1.2.0',
      icon: 'store',
      entryUrl: 'https://superappplatfrom.alwaysdata.net/api/v1/miniapps/store_app/1.2.0/dist/index.html',
      capabilities: ['device.getDeviceInfo'],
    );

    const schemaManifest = MiniAppManifest(
      id: 'survey_app',
      name: 'Survey App',
      description: 'Customer Survey',
      version: '1.0.0',
      icon: 'poll',
      entryUrl: 'https://superappplatfrom.alwaysdata.net/api/v1/miniapps/schema_runtime/1.0.0/dist/index.html',
      appRuntimeType: 'schema',
      capabilities: ['device.getDeviceInfo'],
    );

    const backendUrl = 'https://superappplatfrom.alwaysdata.net';

    test('Accepts valid HTTPS entry URL on trusted domain in production', () {
      final res = MiniAppSecurityPolicy.validateEntryUrl(
        'https://superappplatfrom.alwaysdata.net/api/v1/miniapps/store_app/1.2.0/dist/index.html',
        manifest: webManifest,
        backendBaseUrl: backendUrl,
        isReleaseMode: true,
      );
      expect(res.isValid, isTrue);
      expect(res.errorMessage, isNull);
    });

    test('Accepts per-app isolated subdomain pattern (store-app.apps.example.com)', () {
      final res = MiniAppSecurityPolicy.validateEntryUrl(
        'https://store-app.apps.example.com/index.html',
        manifest: webManifest,
        backendBaseUrl: backendUrl,
        isReleaseMode: true,
      );
      expect(res.isValid, isTrue);
    });

    test('Rejects dangerous schemes: javascript:, data:, file:, blob:', () {
      for (final dangerous in [
        'javascript:alert("hacked")',
        'data:text/html,<script>alert(1)</script>',
        'file:///etc/passwd',
        'blob:https://evil.com/uuid',
      ]) {
        final res = MiniAppSecurityPolicy.validateEntryUrl(
          dangerous,
          manifest: webManifest,
          backendBaseUrl: backendUrl,
          isReleaseMode: true,
        );
        expect(res.isValid, isFalse, reason: 'Scheme in $dangerous should be rejected');
        expect(res.errorMessage, contains('bị cấm'));
      }
    });

    test('Production strictly requires HTTPS and rejects HTTP', () {
      final res = MiniAppSecurityPolicy.validateEntryUrl(
        'http://superappplatfrom.alwaysdata.net/api/v1/miniapps/store_app/1.2.0/dist/index.html',
        manifest: webManifest,
        backendBaseUrl: backendUrl,
        isReleaseMode: true,
      );
      expect(res.isValid, isFalse);
      expect(res.errorMessage, contains('Chỉ chấp nhận giao thức HTTPS'));
    });

    test('Debug mode allows HTTP on localhost / 127.0.0.1', () {
      final res = MiniAppSecurityPolicy.validateEntryUrl(
        'http://localhost:3000/api/v1/miniapps/store_app/1.2.0/dist/index.html',
        manifest: webManifest,
        backendBaseUrl: 'http://localhost:3000',
        isReleaseMode: false,
      );
      expect(res.isValid, isTrue);
    });

    test('Cross-app path access on shared domain is rejected', () {
      // store_app attempting to load another app's directory (finance_app)
      final res = MiniAppSecurityPolicy.validateEntryUrl(
        'https://superappplatfrom.alwaysdata.net/api/v1/miniapps/finance_app/1.0.0/dist/index.html',
        manifest: webManifest,
        backendBaseUrl: backendUrl,
        isReleaseMode: true,
      );
      expect(res.isValid, isFalse);
      expect(res.errorMessage, contains('không nằm trong danh sách phân phối'));
    });

    test('Schema apps can safely load the shared schema_runtime container', () {
      final res = MiniAppSecurityPolicy.validateEntryUrl(
        'https://superappplatfrom.alwaysdata.net/api/v1/miniapps/schema_runtime/1.0.0/dist/index.html',
        manifest: schemaManifest,
        backendBaseUrl: backendUrl,
        isReleaseMode: true,
      );
      expect(res.isValid, isTrue);
    });

    test('Untrusted external domains are rejected from loading', () {
      final res = MiniAppSecurityPolicy.validateEntryUrl(
        'https://malicious-site.attacker.com/stealer.html',
        manifest: webManifest,
        backendBaseUrl: backendUrl,
        isReleaseMode: true,
      );
      expect(res.isValid, isFalse);
    });
  });

  group('MiniAppSecurityPolicy Navigation & Origin Binding Tests', () {
    const manifest = MiniAppManifest(
      id: 'demo_app',
      name: 'Demo App',
      description: 'Demo',
      version: '1.0.0',
      icon: 'code',
      entryUrl: 'https://superappplatfrom.alwaysdata.net/api/v1/miniapps/demo_app/1.0.0/dist/index.html',
      capabilities: ['device.getDeviceInfo'],
    );
    const backendUrl = 'https://superappplatfrom.alwaysdata.net';

    test('Correctly identifies internal trusted navigation vs external link', () {
      final internalUri = Uri.parse('https://superappplatfrom.alwaysdata.net/api/v1/miniapps/demo_app/1.0.0/dist/subpage.html');
      final externalUri = Uri.parse('https://external-bank.com/checkout');

      expect(MiniAppSecurityPolicy.isExternalNavigation(internalUri, manifest: manifest, backendBaseUrl: backendUrl, isReleaseMode: true), isFalse);
      expect(MiniAppSecurityPolicy.isExternalNavigation(externalUri, manifest: manifest, backendBaseUrl: backendUrl, isReleaseMode: true), isTrue);
    });

    test('Validates caller origin: allows currentUrl on trusted domain, rejects external origin', () {
      final validUrl = 'https://superappplatfrom.alwaysdata.net/api/v1/miniapps/demo_app/1.0.0/dist/index.html';
      final invalidUrl = 'https://evil.com/phishing.html';

      expect(
        MiniAppSecurityPolicy.validateCallerOrigin(currentUrl: validUrl, manifest: manifest, backendBaseUrl: backendUrl, isReleaseMode: true),
        isTrue,
      );
      expect(
        MiniAppSecurityPolicy.validateCallerOrigin(currentUrl: invalidUrl, manifest: manifest, backendBaseUrl: backendUrl, isReleaseMode: true),
        isFalse,
      );
    });
  });

  group('BridgeDispatcher Origin and Identity Enforcement Tests', () {
    late AuthRepositoryImpl authRepo;
    late AuthCodeServiceShim authCodeService;
    late TokenServiceShim tokenService;
    late UserRepositoryImpl userRepo;
    late DeviceAdapterImpl deviceAdapter;
    late PermissionRepositoryImpl permissionRepo;
    late DebugLogRepository debugLogRepo;
    late NativeActionDispatcher actionDispatcher;

    const manifest = MiniAppManifest(
      id: 'secure_app',
      name: 'Secure App',
      description: 'Security Test',
      version: '1.0.0',
      icon: 'lock',
      entryUrl: 'https://superappplatfrom.alwaysdata.net/api/v1/miniapps/secure_app/1.0.0/dist/index.html',
      capabilities: ['device.getDeviceInfo'],
    );

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
    });

    test('Bridge rejects request when currentUrl has been navigated to untrusted origin', () async {
      final mockPlatform = MockPlatformWebViewController(
        const PlatformWebViewControllerCreationParams(),
      )..mockUrl = 'https://attacker-origin.com/attack.html';

      final controller = WebViewController.fromPlatform(mockPlatform);
      final dispatcher = BridgeDispatcher(
        actionDispatcher: actionDispatcher,
        debugLogRepo: debugLogRepo,
        controller: controller,
        manifest: manifest,
        backendBaseUrl: 'https://superappplatfrom.alwaysdata.net',
      );

      final rawRequest = jsonEncode({
        'id': 'req_hack_01',
        'action': 'device.getDeviceInfo',
        'payload': {},
        'appId': 'secure_app',
      });

      // Verification: BridgeDispatcher logs failure and throws / responds with PERMISSION_DENIED
      await dispatcher.handleMessage(rawRequest, null as dynamic);

      expect(debugLogRepo.logs.isNotEmpty, isTrue);
      final lastLog = debugLogRepo.logs.first;
      expect(lastLog.success, isFalse);
      expect(lastLog.errorMessage, contains('không thuộc phạm vi Mini App hợp lệ'));
    });

    test('Bridge rejects request when payload passes a forged appId', () async {
      final mockPlatform = MockPlatformWebViewController(
        const PlatformWebViewControllerCreationParams(),
      )..mockUrl = 'https://superappplatfrom.alwaysdata.net/api/v1/miniapps/secure_app/1.0.0/dist/index.html';

      final controller = WebViewController.fromPlatform(mockPlatform);
      final dispatcher = BridgeDispatcher(
        actionDispatcher: actionDispatcher,
        debugLogRepo: debugLogRepo,
        controller: controller,
        manifest: manifest,
        backendBaseUrl: 'https://superappplatfrom.alwaysdata.net',
      );

      final rawRequest = jsonEncode({
        'id': 'req_forged_01',
        'action': 'device.getDeviceInfo',
        'payload': {},
        'appId': 'another_victim_app', // Impersonation attempt!
      });

      await dispatcher.handleMessage(rawRequest, null as dynamic);

      expect(debugLogRepo.logs.isNotEmpty, isTrue);
      final lastLog = debugLogRepo.logs.first;
      expect(lastLog.success, isFalse);
      expect(lastLog.errorMessage, contains('Định danh Mini App không hợp lệ'));
    });

    test('RuntimeSecurityContext contains all 6 required fields', () {
      final sec = RuntimeSecurityContext(
        appId: 'test_app',
        userId: 'user_123',
        approvedOrigin: 'https://superappplatfrom.alwaysdata.net/api/v1/miniapps/test_app/1.0.0/dist/index.html',
        activeVersion: '1.0.0',
        allowedCapabilities: {'device.getDeviceInfo', 'storage.setItem'},
        runtimeSessionId: 'sess_abc_123',
      );

      expect(sec.appId, 'test_app');
      expect(sec.userId, 'user_123');
      expect(sec.approvedOrigin, contains('test_app'));
      expect(sec.activeVersion, '1.0.0');
      expect(sec.allowedCapabilities, contains('device.getDeviceInfo'));
      expect(sec.allowedCapabilities, contains('storage.setItem'));
      expect(sec.allowedCapabilities.contains('device.scanQr'), isFalse);
      expect(sec.runtimeSessionId, 'sess_abc_123');
      expect(sec.isCapabilityAllowed('device.getDeviceInfo'), isTrue);
      expect(sec.isCapabilityAllowed('device.scanQr'), isFalse);
    });

    test('Bridge rejects request when JavaScript declares spoofed origin', () async {
      final mockPlatform = MockPlatformWebViewController(
        const PlatformWebViewControllerCreationParams(),
      )..mockUrl = 'https://superappplatfrom.alwaysdata.net/api/v1/miniapps/secure_app/1.0.0/dist/index.html';

      final controller = WebViewController.fromPlatform(mockPlatform);
      final dispatcher = BridgeDispatcher(
        actionDispatcher: actionDispatcher,
        debugLogRepo: debugLogRepo,
        controller: controller,
        manifest: manifest,
        backendBaseUrl: 'https://superappplatfrom.alwaysdata.net',
      );

      final rawRequest = jsonEncode({
        'id': 'req_spoof_origin',
        'action': 'device.getDeviceInfo',
        'payload': {},
        'appId': 'secure_app',
        'origin': 'https://evil-attacker.com', // Spoofed origin attempt!
      });

      await dispatcher.handleMessage(rawRequest, null as dynamic);

      expect(debugLogRepo.logs.isNotEmpty, isTrue);
      final lastLog = debugLogRepo.logs.first;
      expect(lastLog.success, isFalse);
      expect(lastLog.errorMessage, contains('Nguồn gốc do JavaScript khai báo'));
    });

    test('Bridge rejects request when client passes forged runtime sessionId', () async {
      final mockPlatform = MockPlatformWebViewController(
        const PlatformWebViewControllerCreationParams(),
      )..mockUrl = 'https://superappplatfrom.alwaysdata.net/api/v1/miniapps/secure_app/1.0.0/dist/index.html';

      final controller = WebViewController.fromPlatform(mockPlatform);
      final dispatcher = BridgeDispatcher(
        actionDispatcher: actionDispatcher,
        debugLogRepo: debugLogRepo,
        controller: controller,
        manifest: manifest,
        backendBaseUrl: 'https://superappplatfrom.alwaysdata.net',
        runtimeSessionId: 'valid_host_session_456',
      );

      final rawRequest = jsonEncode({
        'id': 'req_spoof_session',
        'action': 'device.getDeviceInfo',
        'payload': {},
        'appId': 'secure_app',
        'sessionId': 'hacked_session_789', // Forged session attempt!
      });

      await dispatcher.handleMessage(rawRequest, null as dynamic);

      expect(debugLogRepo.logs.isNotEmpty, isTrue);
      final lastLog = debugLogRepo.logs.first;
      expect(lastLog.success, isFalse);
      expect(lastLog.errorMessage, contains('Runtime session không hợp lệ'));
    });

    test('ActionContext properly exposes Host-verified properties and ignores payload permissions', () async {
      final sec = RuntimeSecurityContext(
        appId: 'secure_app',
        userId: 'verified_user_99',
        approvedOrigin: 'https://superappplatfrom.alwaysdata.net/api/v1/miniapps/secure_app/1.0.0/dist/index.html',
        activeVersion: '1.0.0',
        allowedCapabilities: {'device.getDeviceInfo'},
        runtimeSessionId: 'session_xyz',
      );

      final actionCtx = ActionContext(
        appId: sec.appId,
        origin: sec.approvedOrigin,
        manifest: manifest,
        securityContext: sec,
      );

      expect(actionCtx.appId, 'secure_app');
      expect(actionCtx.userId, 'verified_user_99');
      expect(actionCtx.approvedOrigin, contains('secure_app'));
      expect(actionCtx.runtimeSessionId, 'session_xyz');
      expect(actionCtx.allowedCapabilities, contains('device.getDeviceInfo'));

      // If Mini App tries an action that requires 'camera' or 'scanQr' which is not in allowedCapabilities,
      // Dispatcher rejects it even if the payload fraudulently claims permissions.
      expect(
        () => actionDispatcher.dispatch('device.scanQr', {
          'permissions': ['device.scanQr'], // Fraudulent payload claim
          'capabilities': ['device.scanQr'],
        }, actionCtx),
        throwsA(isA<BridgeError>().having(
          (e) => e.code,
          'code',
          equals(BridgeErrorCode.permissionDenied),
        )),
      );
    });
  });
}
