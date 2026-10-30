import '../support/auth_fixtures.dart';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:superapp_platform/core/config/endpoint_config.dart';
import 'package:superapp_platform/core/errors/bridge_error.dart';
import 'package:superapp_platform/features/authentication/data/mock_auth_repository.dart';
import 'package:superapp_platform/features/authentication/data/mock_auth_code_service.dart';
import 'package:superapp_platform/features/authentication/data/mock_token_service.dart';

void main() {
  group('EndpointConfig Tests', () {
    test('Normalizes URL by stripping trailing slashes and api prefix', () {
      expect(EndpointConfig.normalize('http://localhost:3000/'), equals('http://localhost:3000'));
      expect(EndpointConfig.normalize('http://localhost:3000/api/v1'), equals('http://localhost:3000'));
      expect(EndpointConfig.normalize('http://localhost:3000/api/v1/'), equals('http://localhost:3000'));
      expect(EndpointConfig.normalize('  http://192.168.1.5:3000  '), equals('http://192.168.1.5:3000'));
      expect(EndpointConfig.normalize(''), equals('http://localhost:3000'));

      const config = EndpointConfig(baseUrl: 'http://localhost:3000');
      expect(config.catalogUrl, equals('http://localhost:3000/api/v1/catalog'));
      expect(config.authUrl, equals('http://localhost:3000/api/v1/auth'));
      expect(config.miniappUrl, equals('http://localhost:3000/api/v1/miniapp'));
    });
  });

  group('MockAuthRepository HTTP Backend Tests', () {
    test('Login with email & password succeeds when backend returns 200', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/auth/login')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['email'], equals('alice@example.com'));
          expect(body['password'], equals('password123'));
          return http.Response(
            jsonEncode({
              'user': {
                'id': 'user_alice_uuid',
                'email': 'alice@example.com',
                'displayName': 'Alice',
                'avatarUrl': '',
                'createdAt': '2026-10-27T00:00:00.000Z',
              },
              'accessToken': 'access_alice_token',
              'refreshToken': 'refresh_alice_token',
              'tokenType': 'Bearer',
              'expiresIn': 3600,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final repo = MockAuthRepository(
        httpClient: mockClient,
        authUrl: 'http://localhost:3000/api/v1/auth',
      );

      final session = await repo.login('alice@example.com', 'password123');
      expect(repo.isAuthenticated, isTrue);
      expect(session.user.id, equals('user_alice_uuid'));
      expect(session.user.name, equals('Alice'));
      expect(session.accessToken, equals('access_alice_token'));
    });

    test('Login fails when backend returns 401', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'Invalid email or password', 'statusCode': 401}),
          401,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = MockAuthRepository(
        httpClient: mockClient,
        authUrl: 'http://localhost:3000/api/v1/auth',
      );

      expect(
        () => repo.login('alice@example.com', 'wrongpassword'),
        throwsA(isA<Exception>()),
      );
    });

    test('Register new account succeeds when backend returns 201', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/auth/register')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['email'], equals('bob@example.com'));
          expect(body['password'], equals('bobpassword123'));
          expect(body['displayName'], equals('Bob Builder'));

          return http.Response(
            jsonEncode({
              'user': {
                'id': 'user_bob_uuid',
                'email': 'bob@example.com',
                'displayName': 'Bob Builder',
                'avatarUrl': '',
                'createdAt': '2026-10-27T00:00:00.000Z',
              },
              'accessToken': 'access_bob_token',
              'refreshToken': 'refresh_bob_token',
              'tokenType': 'Bearer',
              'expiresIn': 3600,
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final repo = MockAuthRepository(
        httpClient: mockClient,
        authUrl: 'http://localhost:3000/api/v1/auth',
      );

      final session = await repo.register(
        email: 'bob@example.com',
        password: 'bobpassword123',
        displayName: 'Bob Builder',
      );

      expect(repo.isAuthenticated, isTrue);
      expect(session.user.id, equals('user_bob_uuid'));
      expect(session.user.name, equals('Bob Builder'));
      expect(session.user.email, equals('bob@example.com'));
    });

    test('Register fails when email is duplicate (409)', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'Email already registered', 'statusCode': 409}),
          409,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = MockAuthRepository(
        httpClient: mockClient,
        authUrl: 'http://localhost:3000/api/v1/auth',
      );

      expect(
        () => repo.register(
          email: 'duplicate@example.com',
          password: 'password123',
          displayName: 'Duplicate',
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('MockAuthRepository Tests', () {
    late MockAuthRepository repo;

    setUp(() {
      repo = TestAuthRepository();
    });

    tearDown(() {
      repo.dispose();
    });

    test('Initial state is unauthenticated', () {
      expect(repo.isAuthenticated, isFalse);
      expect(repo.currentUser, isNull);
      expect(repo.currentSession, isNull);
    });

    test('Login with User A creates valid session', () async {
      final session = await repo.login(TestUsers.userA.id);
      expect(repo.isAuthenticated, isTrue);
      expect(repo.currentUser?.id, equals(TestUsers.userA.id));
      expect(repo.currentUser?.name, equals('Nguyễn Văn A'));
      expect(session.accessToken.startsWith('fixture-access-'), isTrue);
    });

    test('Login with User B creates valid session', () async {
      final session = await repo.login(TestUsers.userB.id);
      expect(repo.isAuthenticated, isTrue);
      expect(repo.currentUser?.id, equals(TestUsers.userB.id));
      expect(repo.currentUser?.name, equals('Trần Thị B'));
      expect(session.accessToken.startsWith('fixture-access-'), isTrue);
    });

    test('Logout clears session', () async {
      await repo.login(TestUsers.userA.id);
      expect(repo.isAuthenticated, isTrue);

      await repo.logout();
      expect(repo.isAuthenticated, isFalse);
      expect(repo.currentUser, isNull);
    });
  });

  test('production auth cannot manufacture local codes or tokens', () async {
    final codes = MockAuthCodeService();
    expect(() => codes.generateCode(userId: 'u', appId: 'app'), throwsA(isA<BridgeError>()));
    final tokens = MockTokenService(authCodeService: codes);
    await expectLater(tokens.exchangeCode(authCode: 'local', appId: 'app'), throwsA(isA<BridgeError>()));
    final real = MockAuthRepository();
    addTearDown(real.dispose);
    await expectLater(real.login('u'), throwsArgumentError);
  });
}
