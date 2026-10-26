import '../../../../core/errors/bridge_error.dart';
import '../../authentication/data/mock_auth_repository.dart';
import '../../authentication/data/mock_auth_code_service.dart';
import '../../authentication/data/mock_token_service.dart';
import '../domain/action_definition.dart';
import '../domain/action_context.dart';

class AuthRequestCodeHandler implements NativeActionHandler {
  final MockAuthRepository authRepo;
  final MockAuthCodeService authCodeService;

  AuthRequestCodeHandler({
    required this.authRepo,
    required this.authCodeService,
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

  AuthExchangeCodeHandler({required this.tokenService});

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

    final result = await tokenService.exchangeCode(
      authCode: authCode,
      appId: context.appId,
    );

    return result.toJson();
  }
}

class AuthRefreshTokenHandler implements NativeActionHandler {
  final MockTokenService tokenService;

  AuthRefreshTokenHandler({required this.tokenService});

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
      throw BridgeError.invalidParams('Simulated refresh token rejection from mock auth service');
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
