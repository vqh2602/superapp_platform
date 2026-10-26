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
        'capabilities': ['payment.createOrder', 'payment.openCheckout'],
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
    test('Offline fallback returns seed apps', () async {
      // Mock client that simulates network failure
      final mockClient = MockClient((request) async {
        throw Exception('No network connectivity');
      });

      final repo = MiniAppRepository(
        httpClient: mockClient,
        catalogUrl: 'http://mock.catalog.local',
      );

      final apps = await repo.getPublishedMiniApps();
      expect(apps.length, greaterThanOrEqualTo(2));
      expect(apps.any((a) => a.id == 'sdk_playground'), isTrue);
      expect(apps.any((a) => a.id == 'sample_store'), isTrue);

      final single = repo.getAppById('sdk_playground');
      expect(single, isNotNull);
      expect(single?.name, equals('SDK Playground'));
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
            'capabilities': ['payment.createOrder'],
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
}
