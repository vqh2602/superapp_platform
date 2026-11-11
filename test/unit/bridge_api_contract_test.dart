import 'package:flutter_test/flutter_test.dart';
import 'package:superapp_platform/core/contracts/bridge_api_contract.dart';
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
import '../support/auth_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Bridge API Contract Compatibility Tests', () {
    late AuthRepositoryImpl authRepo;
    late AuthCodeServiceShim authCodeService;
    late TokenServiceShim tokenService;
    late UserRepositoryImpl userRepo;
    late DeviceAdapterImpl deviceAdapter;
    late PermissionRepositoryImpl permissionRepo;
    late DebugLogRepository debugLogRepo;
    late NativeActionDispatcher dispatcher;

    const manifest = MiniAppManifest(
      id: 'contract_test_app',
      name: 'Contract Test MiniApp',
      description: 'Used for automated bridge contract tests',
      version: '1.0.0',
      icon: 'icon',
      entryUrl: 'https://superappplatfrom.alwaysdata.net/api/v1/miniapps/contract_test_app/1.0.0/dist/index.html',
      capabilities: [
        'auth.requestCode',
        'auth.login',
        'user.getProfile',
        'user.getBasicInfo',
        'device.getLocation',
        'device.scanQRCode',
        'storage.secure',
      ],
    );

    setUp(() async {
      authRepo = TestAuthRepository();
      await authRepo.login('user_001');

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
      dispatcher.dispose();
    });

    test('Automated Contract Test: 100% of SDK actions have registered handlers in Flutter Host', () {
      final registered = dispatcher.registeredActionNames;
      final missingActions = BridgeApiContract.requiredSdkActionNames.difference(registered);

      expect(
        missingActions,
        isEmpty,
        reason: 'Flutter Host must support every action in the SDK contract without ACTION_NOT_FOUND errors. Missing: $missingActions',
      );
    });

    test('Automated Contract Test: All canonical actions in BridgeApiContract are registered', () {
      final registered = dispatcher.registeredActionNames;
      final missingCanonical = <String>[];

      for (final spec in BridgeApiContract.actions) {
        if (!registered.contains(spec.action)) {
          missingCanonical.add(spec.action);
        }
      }

      expect(
        missingCanonical,
        isEmpty,
        reason: 'Canonical actions defined in BridgeApiContract must be registered. Missing: $missingCanonical',
      );
    });

    group('Auth Contract Tests (auth.login & auth.getAccessToken)', () {
      test('auth.login returns authCode, token, and user info when authenticated', () async {
        final context = ActionContext(
          appId: manifest.id,
          manifest: manifest,
        );

        final result = await dispatcher.dispatch('auth.login', {
          'scopes': ['user.email', 'user.phone'],
        }, context);

        expect(result, isA<Map<String, dynamic>>());
        expect(result['authCode'], isA<String>());
        expect(result['authCode'], startsWith('authcode_'));
        expect(result['accessToken'], isNotEmpty);
        expect(result['expiresIn'], isNotNull);
        expect(result['user'], isA<Map<String, dynamic>>());
        expect(result['user']['id'], isNotNull);
        expect(result['user']['email'], 'a@example.test');
      });

      test('auth.login throws authRequired when user is not authenticated', () async {
        final unauthRepo = AuthRepositoryImpl();
        final unauthDispatcher = NativeActionDispatcher(
          authRepo: unauthRepo,
          authCodeService: authCodeService,
          tokenService: tokenService,
          userRepo: UserRepositoryImpl(authRepository: unauthRepo),
          deviceAdapter: deviceAdapter,
          permissionRepo: permissionRepo,
          debugLogRepo: debugLogRepo,
        );

        final context = ActionContext(
          appId: manifest.id,
          manifest: manifest,
        );

        expect(
          () => unauthDispatcher.dispatch('auth.login', {}, context),
          throwsA(isA<BridgeError>().having((e) => e.code, 'code', BridgeErrorCode.authRequired)),
        );

        unauthDispatcher.dispose();
      });

      test('auth.getAccessToken returns active access token for logged-in user', () async {
        final context = ActionContext(
          appId: manifest.id,
          manifest: manifest,
        );

        final result = await dispatcher.dispatch('auth.getAccessToken', {}, context);

        expect(result['accessToken'], isNotEmpty);
        expect(result['tokenType'], 'Bearer');
        expect(result['expiresIn'], isNotNull);
      });
    });

    test('payment actions are unavailable', () async {
      for (final action in ['payment.createOrder', 'payment.openCheckout',
        'payment.checkStatus', 'payment.checkTransaction', 'payment.requestPayment']) {
        expect(dispatcher.registeredActionNames, isNot(contains(action)));
        await expectLater(dispatcher.dispatch(action, {}, const ActionContext(appId: 'test')),
          throwsA(isA<BridgeError>().having((e) => e.code, 'code', BridgeErrorCode.actionNotFound)));
      }
    });

    group('Phone & Utility Contract Tests (phone.* & debug.*)', () {
      test('phone.openExternalBrowser and phone.openDeepLink handlers are bound without ACTION_NOT_FOUND', () async {
        final context = ActionContext(
          appId: manifest.id,
          manifest: manifest,
        );

        expect(dispatcher.registeredActionNames.contains('phone.openExternalBrowser'), isTrue);
        expect(dispatcher.registeredActionNames.contains('phone.openDeepLink'), isTrue);

        // When called with invalid params, it reaches handler parameter validation, confirming it is not ACTION_NOT_FOUND
        expect(
          () => dispatcher.dispatch('phone.openExternalBrowser', {}, context),
          throwsA(isA<BridgeError>().having((e) => e.code, 'code', BridgeErrorCode.invalidParams)),
        );

        expect(
          () => dispatcher.dispatch('phone.openDeepLink', {}, context),
          throwsA(isA<BridgeError>().having((e) => e.code, 'code', BridgeErrorCode.invalidParams)),
        );
      });

      test('debug.simulateFailure throws accurate bridge errors according to type', () async {
        final context = ActionContext(
          appId: manifest.id,
          manifest: manifest,
        );

        expect(
          () => dispatcher.dispatch('debug.simulateFailure', {'type': 'unsupported'}, context),
          throwsA(isA<BridgeError>().having((e) => e.code, 'code', BridgeErrorCode.unsupported)),
        );

        expect(
          () => dispatcher.dispatch('debug.simulateFailure', {'type': 'permission_denied'}, context),
          throwsA(isA<BridgeError>().having((e) => e.code, 'code', BridgeErrorCode.permissionDenied)),
        );

        expect(
          () => dispatcher.dispatch('debug.simulateFailure', {'type': 'auth_required'}, context),
          throwsA(isA<BridgeError>().having((e) => e.code, 'code', BridgeErrorCode.authRequired)),
        );

        expect(
          () => dispatcher.dispatch('debug.simulateFailure', {'type': 'invalid_params'}, context),
          throwsA(isA<BridgeError>().having((e) => e.code, 'code', BridgeErrorCode.invalidParams)),
        );

        expect(
          () => dispatcher.dispatch('debug.simulateFailure', {'type': 'timeout'}, context),
          throwsA(isA<BridgeError>().having((e) => e.code, 'code', BridgeErrorCode.timeout)),
        );
      });
    });
  });
}
