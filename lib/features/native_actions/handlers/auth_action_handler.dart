import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/errors/bridge_error.dart';
import '../../authentication/data/mock_auth_repository.dart';
import '../../authentication/data/mock_auth_code_service.dart';
import '../../authentication/data/mock_token_service.dart';
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
  final MockAuthRepository authRepo;
  final MockAuthCodeService authCodeService;
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
  final MockTokenService tokenService; final http.Client? httpClient; final String? miniappUrl;
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
  final MockTokenService tokenService; final http.Client? httpClient; final String? authUrl;
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
  final MockAuthRepository authRepo;
  AuthLogoutHandler({required this.authRepo});
  @override String get actionName => 'auth.logout';
  @override String? get requiredCapability => null;
  @override bool get requiresAuth => true;
  @override Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    await authRepo.logout(); return {'status': 'logged_out', 'timestamp': DateTime.now().toIso8601String()};
  }
}
