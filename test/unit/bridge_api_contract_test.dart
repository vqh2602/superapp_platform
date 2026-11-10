import 'package:flutter/material.dart';
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
import 'package:superapp_platform/features/payment/presentation/payment_checkout_bottom_sheet.dart';
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
        'payment.createOrder',
        'payment.openCheckout',
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

      permissionRepo.setPermission(manifest.id, 'payment.createOrder', true);
      permissionRepo.setPermission(manifest.id, 'payment.openCheckout', true);

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

    group('Payment Contract Tests (payment.*)', () {
      test('payment.createOrder validates amount and returns pending order', () async {
        final context = ActionContext(
          appId: manifest.id,
          manifest: manifest,
        );

        // Valid order
        final res = await dispatcher.dispatch('payment.createOrder', {
          'amount': 75000,
          'description': 'Đơn hàng trà sữa',
          'currency': 'VND',
        }, context);

        expect(res['orderId'], startsWith('ord_'));
        expect(res['amount'], 75000.0);
        expect(res['currency'], 'VND');
        expect(res['description'], 'Đơn hàng trà sữa');
        expect(res['status'], 'PENDING');

        // Invalid amount <= 0
        expect(
          () => dispatcher.dispatch('payment.createOrder', {'amount': 0}, context),
          throwsA(isA<BridgeError>().having((e) => e.code, 'code', BridgeErrorCode.invalidParams)),
        );

        expect(
          () => dispatcher.dispatch('payment.createOrder', {'amount': -500}, context),
          throwsA(isA<BridgeError>().having((e) => e.code, 'code', BridgeErrorCode.invalidParams)),
        );
      });

      testWidgets('payment.openCheckout displays native modal and completes transaction on approval', (tester) async {
        late BuildContext capturedContext;
        await tester.pumpWidget(MaterialApp(
          home: Builder(
            builder: (ctx) {
              capturedContext = ctx;
              return const Scaffold(body: Text('Host App'));
            },
          ),
        ));

        final actionContext = ActionContext(
          appId: manifest.id,
          manifest: manifest,
          buildContext: capturedContext,
          userInteractionQueue: dispatcher.userInteractionQueue,
        );

        // 1. Create order
        final order = await dispatcher.dispatch('payment.createOrder', {
          'amount': 45000,
          'description': 'Cà phê Phin',
          'currency': 'VND',
        }, actionContext);

        final orderId = order['orderId'] as String;

        // 2. Open native checkout UI
        final checkoutFuture = dispatcher.dispatch('payment.openCheckout', {
          'orderId': orderId,
        }, actionContext);

        await tester.pumpAndSettle();

        // Native bottom sheet should be rendered
        expect(find.byType(PaymentCheckoutBottomSheet), findsOneWidget);
        expect(find.text('Xác nhận thanh toán'), findsAtLeastNWidgets(1));
        expect(find.text('45.000 VND'), findsOneWidget);

        // Tap confirm payment button
        await tester.tap(find.text('Xác nhận thanh toán').last);
        await tester.pumpAndSettle();

        final result = await checkoutFuture;
        expect(result['status'], 'SUCCESS');
        expect(result['orderId'], orderId);
        expect(result['transactionId'], startsWith('tx_succ_'));
        expect(result['paymentMethod'], 'SUPERAPP_WALLET');

        // 3. Check status via payment.checkStatus
        final statusRes = await dispatcher.dispatch('payment.checkStatus', {
          'transactionId': result['transactionId'],
        }, actionContext);

        expect(statusRes['status'], 'SUCCESS');
        expect(statusRes['orderId'], orderId);

        // 4. Check status via payment.checkTransaction alias
        final aliasRes = await dispatcher.dispatch('payment.checkTransaction', {
          'transactionId': result['transactionId'],
        }, actionContext);

        expect(aliasRes['status'], 'SUCCESS');
      });

      testWidgets('payment.openCheckout returns CANCELLED when user cancels modal', (tester) async {
        late BuildContext capturedContext;
        await tester.pumpWidget(MaterialApp(
          home: Builder(
            builder: (ctx) {
              capturedContext = ctx;
              return const Scaffold(body: Text('Host App'));
            },
          ),
        ));

        final actionContext = ActionContext(
          appId: manifest.id,
          manifest: manifest,
          buildContext: capturedContext,
          userInteractionQueue: dispatcher.userInteractionQueue,
        );

        final order = await dispatcher.dispatch('payment.createOrder', {
          'amount': 99000,
          'description': 'Bữa trưa',
        }, actionContext);

        final checkoutFuture = dispatcher.dispatch('payment.openCheckout', {
          'orderId': order['orderId'],
        }, actionContext);

        await tester.pumpAndSettle();

        // User taps Cancel button
        await tester.tap(find.text('Huỷ bỏ'));
        await tester.pumpAndSettle();

        final result = await checkoutFuture;
        expect(result['status'], 'CANCELLED');
        expect(result['transactionId'], startsWith('tx_cancel_'));
      });

      test('payment.openCheckout headless fallback succeeds with autoApprove flag', () async {
        final context = ActionContext(
          appId: manifest.id,
          manifest: manifest,
        );

        final order = await dispatcher.dispatch('payment.createOrder', {
          'amount': 30000,
        }, context);

        final res = await dispatcher.dispatch('payment.openCheckout', {
          'orderId': order['orderId'],
          'autoApprove': true,
        }, context);

        expect(res['status'], 'SUCCESS');
        expect(res['transactionId'], startsWith('tx_succ_'));
      });
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
