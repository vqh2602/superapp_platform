import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../../core/errors/bridge_error.dart';
import '../../authentication/data/mock_auth_repository.dart';
import '../../authentication/data/mock_auth_code_service.dart';
import '../../authentication/data/mock_token_service.dart';
import '../domain/action_definition.dart';
import '../domain/action_context.dart';

class AuthRequestCodeHandler implements NativeActionHandler {
  final MockAuthRepository authRepo;
  final MockAuthCodeService authCodeService;
  final http.Client? httpClient;
  final String? miniappUrl;

  AuthRequestCodeHandler({
    required this.authRepo,
    required this.authCodeService,
    this.httpClient,
    this.miniappUrl,
  });

  @override
  String get actionName => 'auth.requestCode';

  @override
  String? get requiredCapability => 'auth.requestCode';

  @override
  bool get requiresAuth => true;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    final user = authRepo.currentUser;
    if (user == null || !authRepo.isAuthenticated) {
      throw BridgeError.authRequired();
    }

    final session = authRepo.currentSession;
    final codeChallenge = payload['codeChallenge'] as String?;

    // If real Backend session and codeChallenge provided, request from Backend API
    if (miniappUrl != null &&
        session != null &&
        session.accessToken.isNotEmpty &&
        !session.accessToken.startsWith('master_mock_') &&
        codeChallenge != null &&
        codeChallenge.isNotEmpty) {
      try {
        final client = httpClient ?? http.Client();
        final url = Uri.parse('$miniappUrl/auth/code');
        final response = await client
            .post(
              url,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ${session.accessToken}',
              },
              body: jsonEncode({
                'appId': context.appId,
                'codeChallenge': codeChallenge,
                'codeChallengeMethod': 'S256',
                if (payload['scopes'] != null) 'scopes': payload['scopes'],
              }),
            )
            .timeout(const Duration(seconds: 4));

        if (response.statusCode == 201) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          return {
            'authCode': data['authCode'],
            'expiresIn': data['expiresIn'] ?? 60,
            'appId': data['appId'],
            'scopes': data['scopes'],
            'userId': user.id,
            'createdAt': DateTime.now().toIso8601String(),
          };
        }
      } catch (e) {
        debugPrint('[AuthRequestCodeHandler] Backend requestCode failed: $e');
      }
    }

    // Local / simulated code fallback
    final code = authCodeService.generateCode(
      userId: user.id,
      appId: context.appId,
    );

    return {
      'authCode': code,
      'expiresIn': 60,
      'userId': user.id,
      'createdAt': DateTime.now().toIso8601String(),
    };
  }
}

class AuthExchangeCodeHandler implements NativeActionHandler {
  final MockTokenService tokenService;
  final http.Client? httpClient;
  final String? miniappUrl;

  AuthExchangeCodeHandler({
    required this.tokenService,
    this.httpClient,
    this.miniappUrl,
  });

  @override
  String get actionName => 'auth.exchangeCode';

  @override
  String? get requiredCapability => null; // Open after obtaining code

  @override
  bool get requiresAuth => false; // Code itself validates

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    final authCode = payload['authCode'] as String?;
    if (authCode == null || authCode.isEmpty) {
      throw BridgeError.invalidParams('authCode is required');
    }

    final codeVerifier = payload['codeVerifier'] as String?;

    // If backend auth code format (code_...) and verifier provided
    if (miniappUrl != null &&
        authCode.startsWith('code_') &&
        codeVerifier != null &&
        codeVerifier.isNotEmpty) {
      try {
        final client = httpClient ?? http.Client();
        final url = Uri.parse('$miniappUrl/auth/token');
        final response = await client
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'appId': context.appId,
                'authCode': authCode,
                'codeVerifier': codeVerifier,
              }),
            )
            .timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          return jsonDecode(response.body);
        }
      } catch (e) {
        debugPrint('[AuthExchangeCodeHandler] Backend exchangeCode failed: $e');
      }
    }

    final result = await tokenService.exchangeCode(
      authCode: authCode,
      appId: context.appId,
    );

    return result.toJson();
  }
}

class AuthRefreshTokenHandler implements NativeActionHandler {
  final MockTokenService tokenService;
  final http.Client? httpClient;
  final String? authUrl;

  AuthRefreshTokenHandler({
    required this.tokenService,
    this.httpClient,
    this.authUrl,
  });

  @override
  String get actionName => 'auth.refreshToken';

  @override
  String? get requiredCapability => null;

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    final refreshToken = payload['refreshToken'] as String?;
    if (refreshToken == null || refreshToken.isEmpty) {
      throw BridgeError.invalidParams('refreshToken is required');
    }

    // Check if client simulated refresh failure
    if (payload['simulateError'] == true) {
      throw BridgeError.invalidParams('Simulated refresh token rejection from auth service');
    }

    // If backend refresh token format (refresh_...)
    if (authUrl != null && refreshToken.startsWith('refresh_')) {
      try {
        final client = httpClient ?? http.Client();
        final url = Uri.parse('$authUrl/refresh');
        final response = await client
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'refreshToken': refreshToken}),
            )
            .timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          return jsonDecode(response.body);
        }
      } catch (e) {
        debugPrint('[AuthRefreshTokenHandler] Backend refreshToken failed: $e');
      }
    }

    final result = await tokenService.refreshToken(
      refreshToken: refreshToken,
      appId: context.appId,
    );

    return result.toJson();
  }
}

class AuthLogoutHandler implements NativeActionHandler {
  final MockAuthRepository authRepo;

  AuthLogoutHandler({required this.authRepo});

  @override
  String get actionName => 'auth.logout';

  @override
  String? get requiredCapability => null;

  @override
  bool get requiresAuth => true;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    await authRepo.logout();
    return {
      'status': 'logged_out',
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}
