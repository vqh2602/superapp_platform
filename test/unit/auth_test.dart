import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:superapp_platform/core/config/endpoint_config.dart';
import 'package:superapp_platform/core/errors/bridge_error.dart';
import 'package:superapp_platform/features/authentication/data/mock_auth_repository.dart';
import 'package:superapp_platform/features/authentication/data/mock_auth_code_service.dart';
import 'package:superapp_platform/features/authentication/data/mock_token_service.dart';
import 'package:superapp_platform/features/authentication/domain/models/mock_user.dart';

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
      repo = MockAuthRepository();
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
      final session = await repo.login(MockUser.userA.id);
      expect(repo.isAuthenticated, isTrue);
      expect(repo.currentUser?.id, equals(MockUser.userA.id));
      expect(repo.currentUser?.name, equals('Nguyễn Văn A'));
      expect(session.accessToken.startsWith('master_mock_at_'), isTrue);
    });

    test('Login with User B creates valid session', () async {
      final session = await repo.login(MockUser.userB.id);
      expect(repo.isAuthenticated, isTrue);
      expect(repo.currentUser?.id, equals(MockUser.userB.id));
      expect(repo.currentUser?.name, equals('Trần Thị B'));
      expect(session.accessToken.startsWith('master_mock_at_'), isTrue);
    });

    test('Logout clears session', () async {
      await repo.login(MockUser.userA.id);
      expect(repo.isAuthenticated, isTrue);

      await repo.logout();
      expect(repo.isAuthenticated, isFalse);
      expect(repo.currentUser, isNull);
    });
  });

  group('MockAuthCodeService Tests', () {
    late MockAuthCodeService codeService;

    setUp(() {
      codeService = MockAuthCodeService();
    });

    test('Generates single-use 60s auth code', () {
      final code = codeService.generateCode(userId: 'user_001', appId: 'sdk_playground');
      expect(code.startsWith('AUTH_SDK_PLAYGROUND_'), isTrue);

      // First validation succeeds and burns the code
      final entry = codeService.validateAndBurn(code, 'sdk_playground');
      expect(entry.userId, equals('user_001'));
      expect(entry.isUsed, isTrue);

      // Second validation throws because code is single-use
      expect(
        () => codeService.validateAndBurn(code, 'sdk_playground'),
        throwsA(isA<BridgeError>()),
      );
    });

    test('Rejects code for wrong appId', () {
      final code = codeService.generateCode(userId: 'user_001', appId: 'sdk_playground');
      expect(
        () => codeService.validateAndBurn(code, 'other_app'),
        throwsA(isA<BridgeError>()),
      );
    });
  });

  group('MockTokenService Tests', () {
    late MockAuthCodeService codeService;
    late MockTokenService tokenService;

    setUp(() {
      codeService = MockAuthCodeService();
      tokenService = MockTokenService(authCodeService: codeService);
    });

    test('Exchange code for mini app token pair', () async {
      final code = codeService.generateCode(userId: 'user_001', appId: 'sdk_playground');
      final result = await tokenService.exchangeCode(authCode: code, appId: 'sdk_playground');

      expect(result.accessToken.startsWith('mini_at_'), isTrue);
      expect(result.refreshToken.startsWith('mini_rt_'), isTrue);
      expect(result.userId, equals('user_001'));
      expect(result.tokenType, equals('Bearer'));
      expect(tokenService.validateMiniAppAccessToken(result.accessToken), isTrue);
    });

    test('Refresh token returns new tokens and burns old token', () async {
      final code = codeService.generateCode(userId: 'user_001', appId: 'sdk_playground');
      final original = await tokenService.exchangeCode(authCode: code, appId: 'sdk_playground');

      final refreshed = await tokenService.refreshToken(
        refreshToken: original.refreshToken,
        appId: 'sdk_playground',
      );

      expect(refreshed.accessToken, isNot(equals(original.accessToken)));
      expect(tokenService.validateMiniAppAccessToken(original.accessToken), isFalse);
      expect(tokenService.validateMiniAppAccessToken(refreshed.accessToken), isTrue);
    });
  });
}
