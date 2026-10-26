import 'package:flutter_test/flutter_test.dart';
import 'package:superapp_platform/core/errors/bridge_error.dart';
import 'package:superapp_platform/features/authentication/data/mock_auth_repository.dart';
import 'package:superapp_platform/features/authentication/data/mock_auth_code_service.dart';
import 'package:superapp_platform/features/authentication/data/mock_token_service.dart';
import 'package:superapp_platform/features/authentication/domain/models/mock_user.dart';

void main() {
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
