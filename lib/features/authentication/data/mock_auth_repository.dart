import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../domain/models/auth_session.dart';
import '../domain/models/mock_user.dart';
import '../domain/repositories/auth_repository.dart';

class MockAuthRepository implements AuthRepository {
  final http.Client? httpClient;
  final String _authUrl;
  final _uuid = const Uuid();

  AuthSession? _currentSession;
  final _sessionController = StreamController<AuthSession?>.broadcast();

  MockAuthRepository({
    this.httpClient,
    String? authUrl,
  }) : _authUrl = authUrl ?? 'http://localhost:3000/api/v1/auth';

  @override
  AuthSession? get currentSession => _currentSession;

  @override
  MockUser? get currentUser => _currentSession?.user;

  @override
  bool get isAuthenticated =>
      _currentSession != null && !_currentSession!.isExpired;

  @override
  Stream<AuthSession?> get sessionStream => _sessionController.stream;

  @override
  Future<AuthSession> login(String emailOrUserId, [String? password]) async {
    // If password is provided, perform real HTTP login against Backend API
    if (password != null) {
      return _loginToBackend(email: emailOrUserId, password: password);
    }

    // Fallback for mock unit tests where only userId was supplied
    final user = MockUser.demoUsers.firstWhere(
      (u) => u.id == emailOrUserId,
      orElse: () => MockUser(
        id: emailOrUserId,
        name: 'Demo User',
        phone: '0900000000',
        role: 'customer',
        email: emailOrUserId.contains('@') ? emailOrUserId : '$emailOrUserId@example.com',
      ),
    );

    final session = AuthSession(
      user: user,
      accessToken: 'master_mock_at_${_uuid.v4()}',
      refreshToken: 'master_mock_rt_${_uuid.v4()}',
      expiresAt: DateTime.now().add(const Duration(hours: 8)),
    );

    _currentSession = session;
    _sessionController.add(_currentSession);
    return session;
  }

  Future<AuthSession> _loginToBackend({
    required String email,
    required String password,
  }) async {
    final client = httpClient ?? http.Client();
    final url = Uri.parse('$_authUrl/login');

    try {
      final response = await client
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email.trim(),
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final session = AuthSession.fromBackendJson(data);
        _currentSession = session;
        _sessionController.add(_currentSession);
        return session;
      }

      if (response.statusCode == 401) {
        throw Exception('Sai email hoặc mật khẩu. Vui lòng kiểm tra lại.');
      }

      final errorBody = _parseErrorMessage(response.body);
      throw Exception(errorBody.isNotEmpty ? errorBody : 'Đăng nhập thất bại (${response.statusCode})');
    } catch (e) {
      if (e is Exception && !e.toString().contains('ClientException') && !e.toString().contains('SocketException') && !e.toString().contains('TimeoutException')) {
        rethrow;
      }
      debugPrint('[MockAuthRepository] Network error connecting to $_authUrl: $e');
      throw Exception('Không thể kết nối đến máy chủ Backend tại $_authUrl. Vui lòng kiểm tra lại Endpoint.');
    }
  }

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final client = httpClient ?? http.Client();
    final url = Uri.parse('$_authUrl/register');

    try {
      final response = await client
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email.trim(),
              'password': password,
              'displayName': displayName.trim(),
            }),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final session = AuthSession.fromBackendJson(data);
        _currentSession = session;
        _sessionController.add(_currentSession);
        return session;
      }

      if (response.statusCode == 409) {
        throw Exception('Email này đã được sử dụng. Vui lòng chọn email khác.');
      }

      final errorBody = _parseErrorMessage(response.body);
      throw Exception(errorBody.isNotEmpty ? errorBody : 'Đăng ký thất bại (${response.statusCode})');
    } catch (e) {
      if (e is Exception && !e.toString().contains('ClientException') && !e.toString().contains('SocketException') && !e.toString().contains('TimeoutException')) {
        rethrow;
      }
      debugPrint('[MockAuthRepository] Network error connecting to $_authUrl: $e');
      throw Exception('Không thể kết nối đến máy chủ Backend tại $_authUrl. Vui lòng kiểm tra lại Endpoint.');
    }
  }

  String _parseErrorMessage(String raw) {
    try {
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) {
        final msg = map['message'];
        if (msg is List) {
          return msg.join(', ');
        }
        if (msg is String) return msg;
        if (map['error'] is String) return map['error'];
      }
    } catch (_) {}
    return raw;
  }

  @override
  Future<void> logout() async {
    final session = _currentSession;
    if (session != null && session.accessToken.isNotEmpty && !session.accessToken.startsWith('master_mock_')) {
      try {
        final client = httpClient ?? http.Client();
        final url = Uri.parse('$_authUrl/logout');
        await client.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${session.accessToken}',
          },
        ).timeout(const Duration(seconds: 2));
      } catch (_) {}
    }

    _currentSession = null;
    _sessionController.add(null);
  }

  void reset() {
    _currentSession = null;
    _sessionController.add(null);
  }

  void dispose() {
    _sessionController.close();
  }
}
