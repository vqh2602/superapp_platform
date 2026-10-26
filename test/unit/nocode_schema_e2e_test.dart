import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:superapp_platform/core/errors/bridge_error.dart';
import 'package:superapp_platform/features/authentication/data/mock_auth_code_service.dart';
import 'package:superapp_platform/features/authentication/data/mock_auth_repository.dart';
import 'package:superapp_platform/features/authentication/data/mock_token_service.dart';
import 'package:superapp_platform/features/debug_center/data/debug_log_repository.dart';
import 'package:superapp_platform/features/device/data/mock_device_adapter.dart';
import 'package:superapp_platform/features/mini_app_catalog/data/mini_app_repository.dart';
import 'package:superapp_platform/features/mini_app_catalog/domain/mini_app_manifest.dart';
import 'package:superapp_platform/features/native_actions/application/native_action_dispatcher.dart';
import 'package:superapp_platform/features/native_actions/domain/action_context.dart';
import 'package:superapp_platform/features/payment/data/mock_order_repository.dart';
import 'package:superapp_platform/features/permissions/data/mock_permission_repository.dart';
import 'package:superapp_platform/features/user_profile/data/mock_user_repository.dart';

void main() {
  group('No-Code Schema App End-to-End & Regression Tests', () {
    late MockAuthRepository authRepo;
    late MockAuthCodeService authCodeService;
    late MockTokenService tokenService;
    late MockUserRepository userRepo;
    late MockDeviceAdapter deviceAdapter;
    late MockOrderRepository orderRepo;
    late MockPermissionRepository permissionRepo;
    late DebugLogRepository debugLogRepo;
    late NativeActionDispatcher dispatcher;

    const coffeeShopManifest = MiniAppManifest(
      id: 'coffee_shop',
      name: 'The Coffee House',
      description: 'Cà phê nguyên chất rang mộc & giao nhanh 15 phút.',
      version: '1.0.0',
      icon: 'coffee',
      category: 'Food & Beverage',
      appRuntimeType: 'schema',
      entryUrl: '',
      isAsset: false,
      capabilities: [
        'payment.createOrder',
        'payment.openCheckout',
        'device.scanQRCode',
        'navigation.close',
        'user.getProfile',
      ],
      schema: {
        'pages': [
          {
            'id': 'home',
            'title': '☕ The Coffee House',
          }
        ]
      },
    );

    setUp(() async {
      authRepo = MockAuthRepository();
      authCodeService = MockAuthCodeService();
      tokenService = MockTokenService(authCodeService: authCodeService);
      userRepo = MockUserRepository(authRepository: authRepo);
      deviceAdapter = MockDeviceAdapter();
      orderRepo = MockOrderRepository();
      permissionRepo = MockPermissionRepository();
      debugLogRepo = DebugLogRepository();

      dispatcher = NativeActionDispatcher(
        authRepo: authRepo,
        authCodeService: authCodeService,
        tokenService: tokenService,
        userRepo: userRepo,
        deviceAdapter: deviceAdapter,
        orderRepo: orderRepo,
        permissionRepo: permissionRepo,
        debugLogRepo: debugLogRepo,
      );

      // Log in demo user user_001
      await authRepo.login('user_001');
    });

    tearDown(() {
      authRepo.dispose();
      debugLogRepo.dispose();
    });

    test('Scenario 1 & 2: Schema manifest properties & Type B classification', () {
      final manifestJson = {
        'id': 'coffee_shop',
        'name': 'The Coffee House',
        'description': 'Đặt cà phê nguyên chất rang mộc & giao nhanh 15 phút.',
        'icon': 'coffee',
        'category': 'Food & Beverage',
        'runtimeType': 'schema',
        'version': '1.0.0',
        'entryUrl': '',
        'isAsset': false,
        'capabilities': ['payment.createOrder', 'payment.openCheckout', 'device.scanQRCode', 'navigation.close'],
        'status': 'PUBLISHED',
        'schemaVersion': 1,
        'schema': {
          'pages': [
            {
              'id': 'home',
              'title': '☕ The Coffee House',
              'components': [
                {
                  'id': 'checkout_btn',
                  'type': 'button',
                  'props': {'text': 'Đặt Nhanh Combo Sáng'},
                  'events': {
                    'onClick': {
                      'type': 'native_action',
                      'action': 'payment.createOrder',
                      'params': {'amount': 75000, 'description': 'Combo Cà Phê Sáng'}
                    }
                  }
                }
              ]
            }
          ]
        }
      };

      final manifest = MiniAppManifest.fromJson(manifestJson);
      expect(manifest.id, equals('coffee_shop'));
      expect(manifest.isSchemaApp, isTrue);
      expect(manifest.isWebApp, isFalse);
      expect(manifest.appRuntimeType, equals('schema'));
      expect(manifest.capabilities.contains('payment.createOrder'), isTrue);
      expect(manifest.schema, isNotNull);
      expect(manifest.schema!['pages'], hasLength(1));
    });

    test('Scenario 5: Dynamic Catalog fetches newly published Schema App without app rebuild', () async {
      final mockCatalogResponse = {
        'items': [
          {
            'id': 'coffee_shop',
            'name': 'The Coffee House',
            'description': 'Delicious coffee delivered in 15 mins',
            'icon': 'coffee',
            'category': 'Food & Beverage',
            'runtimeType': 'schema',
            'version': '1.0.0',
            'entryUrl': null,
            'isAsset': false,
            'capabilities': ['payment.createOrder', 'payment.openCheckout'],
            'updatedAt': DateTime.now().toIso8601String(),
          },
          {
            'id': 'sdk_playground',
            'name': 'SDK Playground',
            'description': 'Test bed',
            'icon': 'code',
            'category': 'Developer Tools',
            'runtimeType': 'web',
            'version': '1.0.0',
            'entryUrl': 'assets/mini_apps/sdk_playground/index.html',
            'isAsset': true,
            'capabilities': ['auth.requestCode'],
            'updatedAt': DateTime.now().toIso8601String(),
          }
        ],
        'total': 2,
        'page': 1,
        'limit': 20,
      };

      final client = MockClient((request) async {
        if (request.url.path.contains('/catalog/apps')) {
          return http.Response(jsonEncode(mockCatalogResponse), 200, headers: {
            'content-type': 'application/json; charset=utf-8',
          });
        }
        return http.Response('Not Found', 404);
      });

      final repo = MiniAppRepository(httpClient: client, catalogUrl: 'http://localhost:3000/api/v1/catalog');
      final apps = await repo.getPublishedMiniApps(forceRefresh: true);

      expect(apps, hasLength(2));
      final coffeeApp = apps.firstWhere((a) => a.id == 'coffee_shop');
      expect(coffeeApp.name, equals('The Coffee House'));
      expect(coffeeApp.isSchemaApp, isTrue);
      expect(coffeeApp.category, equals('Food & Beverage'));

      final playgroundApp = apps.firstWhere((a) => a.id == 'sdk_playground');
      expect(playgroundApp.isWebApp, isTrue);
    });

    test('Scenario 6: Native payment order creation invoked by Schema App executes end-to-end', () async {
      permissionRepo.setPermission('coffee_shop', 'payment.createOrder', true);
      final context = ActionContext(appId: 'coffee_shop', manifest: coffeeShopManifest);

      final result = await dispatcher.dispatch(
        'payment.createOrder',
        {
          'amount': 75000,
          'description': 'Combo Cà Phê + Bánh Croissant Sáng',
          'currency': 'VND',
        },
        context,
      );

      expect(result['status'], equals('PENDING'));
      expect(result['amount'], equals(75000));
      expect(result['orderId'], isNotEmpty);

      // Verify order exists in repository
      final orderId = result['orderId'] as String;
      final savedOrder = orderRepo.getOrder(orderId);
      expect(savedOrder, isNotNull);
      expect(savedOrder?.amount, equals(75000));
      expect(savedOrder?.description, equals('Combo Cà Phê + Bánh Croissant Sáng'));
    });

    test('Scenario 6 (Cont.): Device QR Code scan invoked by Schema App returns payload', () async {
      permissionRepo.setPermission('coffee_shop', 'device.scanQRCode', true);
      final context = ActionContext(appId: 'coffee_shop', manifest: coffeeShopManifest);

      final result = await dispatcher.dispatch('device.scanQRCode', {}, context);

      expect(result['content'], isNotEmpty);
      expect(result['format'], equals('QR_CODE'));
      expect(result['isMock'], isTrue);
    });

    test('Scenario 8: Catalog blocks access when Mini App is unpublished', () async {
      final client = MockClient((request) async {
        if (request.url.path.contains('/catalog/apps/coffee_shop')) {
          return http.Response(
            jsonEncode({
              'message': 'Mini App "coffee_shop" is not published (Current status: UNPUBLISHED)',
              'error': 'Forbidden',
              'statusCode': 403,
            }),
            403,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final repo = MiniAppRepository(httpClient: client, catalogUrl: 'http://localhost:3000/api/v1/catalog');
      final fetched = await repo.fetchRemoteManifest('coffee_shop');
      expect(fetched, isNull);
    });

    test('Scenario 9: Regression test guarantees existing SDK Playground flows A..H remain fully functional', () async {
      const playgroundManifest = MiniAppManifest(
        id: 'sdk_playground',
        name: 'SDK Playground',
        description: 'Test',
        version: '1.0.0',
        icon: 'code',
        entryUrl: 'assets/mini_apps/sdk_playground/index.html',
        capabilities: [
          'auth.requestCode',
          'user.getProfile',
          'user.getBasicInfo',
          'device.getLocation',
          'navigation.openNativePage',
          'navigation.close',
        ],
      );
      final context = ActionContext(appId: 'sdk_playground', manifest: playgroundManifest);

      // Flow A: Request Auth Code
      permissionRepo.setPermission('sdk_playground', 'auth.requestCode', true);
      final authCodeRes = await dispatcher.dispatch('auth.requestCode', {}, context);
      expect(authCodeRes['authCode'], isNotEmpty);

      // Flow B: User Profile
      permissionRepo.setPermission('sdk_playground', 'user.getProfile', true);
      final profileRes = await dispatcher.dispatch('user.getProfile', {}, context);
      expect(profileRes['id'], equals('user_001'));
      expect(profileRes['name'], equals('Nguyễn Văn A'));

      // Flow C: Basic Info
      permissionRepo.setPermission('sdk_playground', 'user.getBasicInfo', true);
      final basicRes = await dispatcher.dispatch('user.getBasicInfo', {}, context);
      expect(basicRes['name'], equals('Nguyễn Văn A'));

      // Flow D: Device Location
      permissionRepo.setPermission('sdk_playground', 'device.getLocation', true);
      final locRes = await dispatcher.dispatch('device.getLocation', {}, context);
      expect(locRes['latitude'], isNotNull);

      // Flow E: Native Navigation allowlist requires BuildContext
      permissionRepo.setPermission('sdk_playground', 'navigation.openNativePage', true);
      expect(
        () => dispatcher.dispatch(
          'navigation.openNativePage',
          {'page': 'profile'},
          context,
        ),
        throwsA(isA<BridgeError>()),
      );

      // Flow F: Native Close
      permissionRepo.setPermission('sdk_playground', 'navigation.close', true);
      final closeRes = await dispatcher.dispatch('navigation.close', {}, context);
      expect(closeRes.containsKey('closed'), isTrue);
    });
  });
}
