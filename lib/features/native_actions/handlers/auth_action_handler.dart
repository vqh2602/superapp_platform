import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/errors/bridge_error.dart';
import '../../authentication/data/auth_repository_impl.dart';
import '../../authentication/data/auth_code_service_shim.dart';
import '../../authentication/data/token_service_shim.dart';
import '../domain/action_definition.dart';
import '../domain/action_context.dart';

Future<dynamic> _post(http.Client? provided, String url, Map<String, dynamic> body, {String? token}) async {
  final client = provided ?? http.Client();
  try {
    final r = await client.post(Uri.parse(url), headers: {'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token'}, body: jsonEncode(body)).timeout(const Duration(seconds: 30));
    if (r.statusCode == 200 || r.statusCode == 201) return jsonDecode(r.body);
    if (r.statusCode == 401) throw BridgeError.authRequired();
    if (r.statusCode == 403) throw BridgeError.permissionDenied('auth');
    throw BridgeError.invalidParams('Backend authentication failed (${r.statusCode})');
  } finally { if (provided == null) client.close(); }
}
class AuthRequestCodeHandler implements NativeActionHandler {
  final AuthRepositoryImpl authRepo;
  final AuthCodeServiceShim authCodeService;
  final http.Client? httpClient;
  final String? miniappUrl;
  AuthRequestCodeHandler({required this.authRepo, required this.authCodeService, this.httpClient, this.miniappUrl});
  @override String get actionName => 'auth.requestCode';
  @override String? get requiredCapability => 'auth.requestCode';
  @override bool get requiresAuth => true;
  @override Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    final session = authRepo.currentSession;
    if (session == null || !authRepo.isAuthenticated) throw BridgeError.authRequired();
    final challenge = payload['codeChallenge'];
    if (challenge is! String || challenge.isEmpty) throw BridgeError.invalidParams('PKCE codeChallenge is required');
    if (miniappUrl == null) throw BridgeError.unsupported('Backend authentication is not configured');
    return _post(httpClient, '$miniappUrl/auth/code', {'appId': context.appId,
      'codeChallenge': challenge, 'codeChallengeMethod': 'S256', if (payload['scopes'] != null) 'scopes': payload['scopes']}, token: session.accessToken);
  }
}
class AuthExchangeCodeHandler implements NativeActionHandler {
  final TokenServiceShim tokenService; final http.Client? httpClient; final String? miniappUrl;
  AuthExchangeCodeHandler({required this.tokenService, this.httpClient, this.miniappUrl});
  @override String get actionName => 'auth.exchangeCode';
  @override String? get requiredCapability => null;
  @override bool get requiresAuth => false;
  @override Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    if (payload['authCode'] is! String || payload['codeVerifier'] is! String) throw BridgeError.invalidParams('authCode and PKCE codeVerifier are required');
    if (miniappUrl == null) throw BridgeError.unsupported('Backend authentication is not configured');
    return _post(httpClient, '$miniappUrl/auth/token', {'appId': context.appId, 'authCode': payload['authCode'], 'codeVerifier': payload['codeVerifier']});
  }
}
class AuthRefreshTokenHandler implements NativeActionHandler {
  final TokenServiceShim tokenService; final http.Client? httpClient; final String? authUrl;
  AuthRefreshTokenHandler({required this.tokenService, this.httpClient, this.authUrl});
  @override String get actionName => 'auth.refreshToken';
  @override String? get requiredCapability => null;
  @override bool get requiresAuth => false;
  @override Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    if (payload['refreshToken'] is! String || (payload['refreshToken'] as String).isEmpty) throw BridgeError.invalidParams('refreshToken is required');
    if (authUrl == null) throw BridgeError.unsupported('Backend authentication is not configured');
    return _post(httpClient, '$authUrl/refresh', {'refreshToken': payload['refreshToken']});
  }
}
class AuthLogoutHandler implements NativeActionHandler {
  final AuthRepositoryImpl authRepo;
  AuthLogoutHandler({required this.authRepo});
  @override String get actionName => 'auth.logout';
  @override String? get requiredCapability => null;
  @override bool get requiresAuth => true;
  @override Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    await authRepo.logout(); return {'status': 'logged_out', 'timestamp': DateTime.now().toIso8601String()};
  }
}

class AuthLoginHandler implements NativeActionHandler {
  final AuthRepositoryImpl authRepo;

  AuthLoginHandler({required this.authRepo});

  @override
  String get actionName => 'auth.login';

  @override
  String? get requiredCapability => null;

  @override
  bool get requiresAuth => true;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    context.checkCancelled();
    final session = authRepo.currentSession;
    if (session == null || !authRepo.isAuthenticated) {
      throw BridgeError.authRequired();
    }
    final user = authRepo.currentUser ?? session.user;
    final scopes = (payload['scopes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final expiresIn = session.expiresAt.difference(DateTime.now()).inSeconds.clamp(0, 86400);

    return {
      'authCode': 'authcode_${DateTime.now().millisecondsSinceEpoch}_${context.appId}',
      'accessToken': session.accessToken,
      'expiresIn': expiresIn > 0 ? expiresIn : 3600,
      'user': {
        'id': user.id,
        'name': user.name.isNotEmpty
            ? user.name
            : (user.email.isNotEmpty ? user.email : 'Người dùng SuperApp'),
        'avatarUrl': user.avatarUrl,
        if (scopes.contains('user.phone') || scopes.contains('phone')) 'phone': user.phone,
        if (scopes.contains('user.email') || scopes.contains('email')) 'email': user.email,
      },
    };
  }
}

class AuthGetAccessTokenHandler implements NativeActionHandler {
  final AuthRepositoryImpl authRepo;

  AuthGetAccessTokenHandler({required this.authRepo});

  @override
  String get actionName => 'auth.getAccessToken';

  @override
  String? get requiredCapability => null;

  @override
  bool get requiresAuth => true;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    context.checkCancelled();
    final session = authRepo.currentSession;
    if (session == null || !authRepo.isAuthenticated) {
      throw BridgeError.authRequired();
    }
    final expiresIn = session.expiresAt.difference(DateTime.now()).inSeconds.clamp(0, 86400);
    return {
      'accessToken': session.accessToken,
      'tokenType': 'Bearer',
      'expiresIn': expiresIn > 0 ? expiresIn : 3600,
    };
  }
}

