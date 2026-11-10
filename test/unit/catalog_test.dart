import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:superapp_platform/features/mini_app_catalog/data/mini_app_repository.dart';
import 'package:superapp_platform/features/mini_app_catalog/domain/mini_app_manifest.dart';

void main() {
  group('MiniAppManifest Tests', () {
    test('Maintains backward compatibility with default parameters', () {
      const manifest = MiniAppManifest(
        id: 'test_app',
        name: 'Test App',
        description: 'Description',
        version: '1.0.0',
        icon: 'code',
        entryUrl: 'assets/index.html',
        capabilities: ['user.getBasicInfo'],
      );

      expect(manifest.appRuntimeType, equals('web'));
      expect(manifest.isWebApp, isTrue);
      expect(manifest.isSchemaApp, isFalse);
      expect(manifest.status, equals('PUBLISHED'));
      expect(manifest.schemaVersion, equals(1));
    });

    test('Serializes and deserializes correctly with JSON', () {
      final json = {
        'id': 'coffee_shop',
        'name': 'Coffee Shop',
        'description': 'Delicious coffee',
        'version': '1.2.0',
        'icon': 'coffee',
        'entryUrl': '',
        'isAsset': false,
        'capabilities': ['ui.showToast', 'navigation.close'],
        'runtimeType': 'schema',
        'category': 'Food & Beverage',
        'status': 'PUBLISHED',
        'schemaVersion': 1,
        'schema': {
          'pages': [
            {'id': 'home', 'title': 'Welcome'}
          ]
        },
      };

      final parsed = MiniAppManifest.fromJson(json);
      expect(parsed.id, equals('coffee_shop'));
      expect(parsed.name, equals('Coffee Shop'));
      expect(parsed.appRuntimeType, equals('schema'));
      expect(parsed.isSchemaApp, isTrue);
      expect(parsed.category, equals('Food & Beverage'));
      expect(parsed.schema?['pages'], isNotEmpty);

      final encoded = parsed.toJson();
      expect(encoded['runtimeType'], equals('schema'));
      expect(encoded['category'], equals('Food & Beverage'));
    });
  });

  group('MiniAppRepository Dynamic & Offline Tests', () {
    test('Offline network failure throws error and does not return seed apps', () async {
      // Mock client that simulates network failure
      final mockClient = MockClient((request) async {
        throw Exception('No network connectivity');
      });

      final repo = MiniAppRepository(
        httpClient: mockClient,
        catalogUrl: 'http://mock.catalog.local',
      );

      expect(() => repo.getPublishedMiniApps(), throwsA(isA<Exception>()));
      expect(repo.getAllApps(), isEmpty);
      expect(repo.getAppById('sdk_playground'), isNull);
    });

    test('Empty remote catalog stays empty instead of restoring seed apps', () async {
      final repo = MiniAppRepository(
        httpClient: MockClient((_) async => http.Response('{"items":[]}', 200)),
        catalogUrl: 'http://mock.catalog.local',
      );
      expect(await repo.getPublishedMiniApps(), isEmpty);
      expect(repo.getAllApps(), isEmpty);
      expect(repo.getAppById('sdk_playground'), isNull);
    });

    for (final status in [403, 404]) {
      test('Remote $status blocks launch even for a bundled seed app', () async {
        final repo = MiniAppRepository(
          httpClient: MockClient((_) async => http.Response('{}', status)),
          catalogUrl: 'http://mock.catalog.local',
        );
        expect(await repo.fetchRemoteManifest('sdk_playground'), isNull);
      });
    }

    test('Refreshing an empty catalog removes previously visible apps', () async {
      var hidden = false;
      final repo = MiniAppRepository(
        httpClient: MockClient((_) async => http.Response(jsonEncode({
          'items': hidden ? [] : [{
            'id': 'sdk_playground', 'name': 'SDK Playground', 'version': '1.0.0',
            'description': '', 'icon': 'code', 'entryUrl': 'assets/index.html',
            'isAsset': true, 'capabilities': [],
          }],
        }), 200)),
        catalogUrl: 'http://mock.catalog.local',
      );
      expect(await repo.getPublishedMiniApps(), hasLength(1));
      hidden = true;
      expect(await repo.getPublishedMiniApps(forceRefresh: true), isEmpty);
      expect(repo.getAppById('sdk_playground'), isNull);
    });

    test('Resolves packaged entry and icon paths using the configured backend', () async {
      final repo = MiniAppRepository(
        httpClient: MockClient((_) async => http.Response(jsonEncode({
          'id': 'web_demo', 'name': 'Web Demo', 'version': '1.0.0',
          'description': '', 'icon': '/api/v1/miniapps/web_demo/1.0.0/icon.png',
          'entryUrl': '/api/v1/miniapps/web_demo/1.0.0/dist/index.html',
          'isAsset': false, 'capabilities': [],
        }), 200)),
        catalogUrl: 'http://192.168.1.20:3000/api/v1/catalog',
      );
      final manifest = await repo.fetchRemoteManifest('web_demo');
      expect(manifest?.entryUrl, 'http://192.168.1.20:3000/api/v1/miniapps/web_demo/1.0.0/dist/index.html');
      expect(manifest?.icon, 'http://192.168.1.20:3000/api/v1/miniapps/web_demo/1.0.0/icon.png');
    });

    test('Fetches published apps from catalog API successfully', () async {
      final mockPayload = {
        'items': [
          {
            'id': 'coffee_shop',
            'name': 'Coffee Shop',
            'description': 'Online Cafe',
            'icon': 'coffee',
            'category': 'Food & Beverage',
            'runtimeType': 'schema',
            'version': '1.0.0',
            'entryUrl': '',
            'isAsset': false,
            'capabilities': ['navigation.close'],
          },
          {
            'id': 'sdk_playground',
            'name': 'SDK Playground',
            'description': 'Test bed',
            'icon': 'code',
            'category': 'Developer Tools',
            'runtimeType': 'web',
            'version': '1.0.0',
            'entryUrl': 'assets/index.html',
            'isAsset': true,
            'capabilities': [],
          }
        ],
        'total': 2,
        'page': 1,
        'limit': 20,
      };

      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/apps')) {
          return http.Response(jsonEncode(mockPayload), 200);
        }
        return http.Response('Not Found', 404);
      });

      final repo = MiniAppRepository(
        httpClient: mockClient,
        catalogUrl: 'http://mock.catalog.local',
      );

      final apps = await repo.getPublishedMiniApps(forceRefresh: true);
      expect(apps.length, equals(2));
      expect(apps.first.id, equals('coffee_shop'));
      expect(apps.first.isSchemaApp, isTrue);

      // Test filter by category
      final foodApps = await repo.getPublishedMiniApps(category: 'Food & Beverage');
      expect(foodApps.length, equals(1));
      expect(foodApps.first.id, equals('coffee_shop'));

      // Test search
      final searchResults = await repo.getPublishedMiniApps(search: 'Playground');
      expect(searchResults.length, equals(1));
      expect(searchResults.first.id, equals('sdk_playground'));
    });
  });

  group('Execution Authorization vs Catalog Cache Tests', () {
    test('Catalog cache exists for UI display but cannot authorize execution if unverified', () async {
      // 1. Initial successful catalog query puts app into Catalog Cache (_dynamicApps)
      final repo = MiniAppRepository(
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/apps')) {
            return http.Response(jsonEncode({
              'items': [
                {
                  'id': 'promo_app',
                  'name': 'Promo App',
                  'version': '1.0.0',
                  'entryUrl': 'https://example.com/promo.html',
                  'category': 'Shopping',
                  'capabilities': [],
                }
              ]
            }), 200);
          }
          // Single app authorization endpoint fails with 500 / Network Error
          return http.Response('Server Internal Error', 500);
        }),
        catalogUrl: 'http://mock.catalog.local',
      );

      // Populate catalog cache
      final apps = await repo.getPublishedMiniApps();
      expect(apps, hasLength(1));
      // Catalog cache can be read for UI display
      expect(repo.getAppById('promo_app'), isNotNull);

      // But execution authorization MUST fail and reject launch
      final auth = await repo.authorizeExecution('promo_app');
      expect(auth, isNull);
      expect(await repo.fetchRemoteManifest('promo_app'), isNull);
    });

    test('Execution authorization has valid TTL and expires accurately', () async {
      final repo = MiniAppRepository(
        httpClient: MockClient((request) async {
          return http.Response(jsonEncode({
            'id': 'verified_app',
            'name': 'Verified App',
            'version': '2.1.0',
            'entryUrl': 'https://example.com/v2.html',
            'capabilities': ['device.getDeviceInfo'],
            'authorizationToken': 'jwt_auth_proof_999',
          }), 200);
        }),
        catalogUrl: 'http://mock.catalog.local',
      );

      // Authorize with short 50ms TTL
      final auth = await repo.authorizeExecution(
        'verified_app',
        ttl: const Duration(milliseconds: 50),
      );

      expect(auth, isNotNull);
      expect(auth!.isValid, isTrue);
      expect(auth.isExpired, isFalse);
      expect(auth.authorizationToken, 'jwt_auth_proof_999');
      expect(auth.version, '2.1.0');

      // Wait for TTL expiration
      await Future.delayed(const Duration(milliseconds: 60));

      expect(auth.isExpired, isTrue);
      expect(auth.isValid, isFalse);
    });

    test('Immediate revocation: Backend 403 or 404 destroys cached authorization and catalog entry', () async {
      var isRevoked = false;
      final repo = MiniAppRepository(
        httpClient: MockClient((request) async {
          if (isRevoked) {
            return http.Response('Forbidden: App Revoked', 403);
          }
          return http.Response(jsonEncode({
            'id': 'revocable_app',
            'name': 'Revocable App',
            'version': '1.0.0',
            'entryUrl': 'https://example.com/app.html',
            'capabilities': [],
          }), 200);
        }),
        catalogUrl: 'http://mock.catalog.local',
      );

      // 1. App is authorized initially
      final initialAuth = await repo.authorizeExecution('revocable_app');
      expect(initialAuth, isNotNull);
      expect(repo.getAppById('revocable_app'), isNotNull);

      // 2. Developer / SuperApp admin revokes app on backend
      isRevoked = true;
      final revokedAuth = await repo.authorizeExecution('revocable_app', forceRevalidate: true);

      expect(revokedAuth, isNull);
      // Both execution authorization and catalog cache are immediately purged
      expect(repo.getActiveAuthorization('revocable_app'), isNull);
      expect(repo.getAppById('revocable_app'), isNull);
    });

    test('Revocation via status payload (status: "revoked" or published: false) terminates authorization', () async {
      final repo = MiniAppRepository(
        httpClient: MockClient((request) async {
          return http.Response(jsonEncode({
            'id': 'banned_app',
            'name': 'Banned App',
            'version': '1.0.0',
            'entryUrl': 'https://example.com/banned.html',
            'published': false, // Uninstalled or suspended
            'status': 'revoked',
            'capabilities': [],
          }), 200);
        }),
        catalogUrl: 'http://mock.catalog.local',
      );

      final auth = await repo.authorizeExecution('banned_app');
      expect(auth, isNull);
      expect(repo.getAppById('banned_app'), isNull);
    });
  });
}
