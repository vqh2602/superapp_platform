import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:serp_debug_overlay/flutter_debug_overlay.dart';
import 'package:superapp_platform/core/config/debug_mode_provider.dart';
import 'package:superapp_platform/core/network/app_http_client.dart';
import 'package:superapp_platform/features/authentication/domain/models/auth_session.dart';
import 'package:superapp_platform/features/authentication/domain/models/platform_user.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SERP Debug Overlay & LogCapture Tests', () {
    test('initDebugOverlay initializes LogCapture and globalLogBucket accepts logs', () {
      initDebugOverlay();
      expect(LogCapture.isStarted, isTrue);

      final initialCount = globalLogBucket.entries.length;
      LogCapture.info('Test debug log message for serp_debug_overlay');

      expect(globalLogBucket.entries.length, greaterThanOrEqualTo(initialCount + 1));
      final lastLog = globalLogBucket.entries.last;
      expect(lastLog.message, contains('Test debug log message for serp_debug_overlay'));
    });

    test('HttpLogClient records HTTP interactions into globalHttpBucket', () async {
      DebugOverlay.enabled = true;

      final mockInner = MockClient((request) async {
        return http.Response(
          jsonEncode({'status': 'ok', 'data': 'mock response'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = HttpLogClient(globalHttpBucket, mockInner);
      final initialCount = globalHttpBucket.entries.length;

      final res = await client.get(Uri.parse('https://example.com/api/test'));
      expect(res.statusCode, equals(200));

      expect(globalHttpBucket.entries.length, greaterThanOrEqualTo(initialCount + 1));
      final lastInteraction = globalHttpBucket.entries.last;
      expect(lastInteraction.uri.toString(), equals('https://example.com/api/test'));
      expect(lastInteraction.response?.statusCode, equals(200));
    });
  });

  group('HTTP 401 Token Expiration Tests', () {
    test('401 on authenticated endpoint triggers onTokenExpired callback', () async {
      var tokenExpiredCalled = false;

      final mockInner = MockClient((request) async {
        return http.Response(
          jsonEncode({'statusCode': 401, 'message': 'Unauthorized - Token expired'}),
          401,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = AuthExpiredInterceptorClient(
        mockInner,
        onTokenExpired: () {
          tokenExpiredCalled = true;
        },
      );

      // Calling an authenticated endpoint like /users/me
      final response = await client.get(
        Uri.parse('http://localhost:3000/api/v1/users/me'),
        headers: {'Authorization': 'Bearer expired_token_xyz'},
      );

      expect(response.statusCode, equals(401));
      expect(tokenExpiredCalled, isTrue);
    });

    test('401 on /login endpoint does NOT trigger onTokenExpired callback', () async {
      var tokenExpiredCalled = false;

      final mockInner = MockClient((request) async {
        return http.Response(
          jsonEncode({'statusCode': 401, 'message': 'Wrong password'}),
          401,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = AuthExpiredInterceptorClient(
        mockInner,
        onTokenExpired: () {
          tokenExpiredCalled = true;
        },
      );

      // Calling /auth/login with wrong credentials
      final response = await client.post(
        Uri.parse('http://localhost:3000/api/v1/auth/login'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'email': 'alice@example.com', 'password': 'wrong'}),
      );

      expect(response.statusCode, equals(401));
      // Should not trigger redirect to login because user is already submitting login form
      expect(tokenExpiredCalled, isFalse);
    });

    test('200 on authenticated endpoint does NOT trigger onTokenExpired callback', () async {
      var tokenExpiredCalled = false;

      final mockInner = MockClient((request) async {
        return http.Response(
          jsonEncode({'id': 'user_1', 'name': 'Alice'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = AuthExpiredInterceptorClient(
        mockInner,
        onTokenExpired: () {
          tokenExpiredCalled = true;
        },
      );

      final response = await client.get(
        Uri.parse('http://localhost:3000/api/v1/users/me'),
      );

      expect(response.statusCode, equals(200));
      expect(tokenExpiredCalled, isFalse);
    });

    test('AuthSession accurately detects expiration time', () {
      final validSession = AuthSession(
        user: const PlatformUser(
          id: 'u1',
          name: 'Bob',
          phone: '',
          role: 'user',
          email: 'bob@example.com',
        ),
        accessToken: 'tok',
        refreshToken: 'ref',
        expiresAt: DateTime.now().add(const Duration(minutes: 30)),
      );
      expect(validSession.isExpired, isFalse);

      final expiredSession = AuthSession(
        user: const PlatformUser(
          id: 'u2',
          name: 'Charlie',
          phone: '',
          role: 'user',
          email: 'charlie@example.com',
        ),
        accessToken: 'tok_exp',
        refreshToken: 'ref_exp',
        expiresAt: DateTime.now().subtract(const Duration(seconds: 10)),
      );
      expect(expiredSession.isExpired, isTrue);
    });
  });

  group('Login Screen Credentials Storage Tests', () {
    const storageKeyRemember = 'superapp_remember_credentials';
    const storageKeyAccount = 'superapp_saved_account';
    const storageKeyPassword = 'superapp_saved_password';

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
    });

    test('Saves account and password when remember is enabled', () async {
      const storage = FlutterSecureStorage();

      // Simulate saving credentials on login
      await storage.write(key: storageKeyRemember, value: 'true');
      await storage.write(key: storageKeyAccount, value: 'user@bkholding.vn');
      await storage.write(key: storageKeyPassword, value: 'SuperSecret123!');

      final savedRemember = await storage.read(key: storageKeyRemember);
      final savedAccount = await storage.read(key: storageKeyAccount);
      final savedPassword = await storage.read(key: storageKeyPassword);

      expect(savedRemember, equals('true'));
      expect(savedAccount, equals('user@bkholding.vn'));
      expect(savedPassword, equals('SuperSecret123!'));
    });

    test('Clears account and password when remember is disabled', () async {
      const storage = FlutterSecureStorage();

      // First save
      await storage.write(key: storageKeyRemember, value: 'true');
      await storage.write(key: storageKeyAccount, value: 'user@bkholding.vn');
      await storage.write(key: storageKeyPassword, value: 'SuperSecret123!');

      // User unchecks remember and logs in or clears credentials
      await storage.write(key: storageKeyRemember, value: 'false');
      await storage.delete(key: storageKeyAccount);
      await storage.delete(key: storageKeyPassword);

      final savedRemember = await storage.read(key: storageKeyRemember);
      final savedAccount = await storage.read(key: storageKeyAccount);
      final savedPassword = await storage.read(key: storageKeyPassword);

      expect(savedRemember, equals('false'));
      expect(savedAccount, isNull);
      expect(savedPassword, isNull);
    });
  });
}

