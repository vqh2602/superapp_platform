// Triển khai kho dữ liệu xác thực thực tế (Auth Repository Implementation).
//
// Gửi request đăng nhập, đăng ký và đăng xuất lên máy chủ Backend,
// đồng thời phát sự kiện thay đổi phiên thông qua [sessionStream].
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../domain/models/auth_session.dart';
import '../domain/models/platform_user.dart';
import '../domain/repositories/auth_repository.dart';

/// Lớp thực thi giao diện [AuthRepository] kết nối với máy chủ Backend
class AuthRepositoryImpl implements AuthRepository {
  final http.Client? httpClient;
  final String _authUrl;
  final FlutterSecureStorage? secureStorage;
  static const String _sessionStorageKey = 'superapp:auth:session_v2';

  AuthSession? _currentSession;
  final _sessionController = StreamController<AuthSession?>.broadcast();

  AuthRepositoryImpl({
    this.httpClient,
    String? authUrl,
    FlutterSecureStorage? secureStorage,
  })  : _authUrl = authUrl ?? 'http://localhost:3000/api/v1/auth',
        secureStorage = secureStorage ?? const FlutterSecureStorage();

  @override
  AuthSession? get currentSession => _currentSession;

  @override
  PlatformUser? get currentUser => _currentSession?.user;

  @override
  bool get isAuthenticated =>
      _currentSession != null && !_currentSession!.isExpired;

  @override
  Stream<AuthSession?> get sessionStream => _sessionController.stream;

  Future<void> _persistSession(AuthSession session) async {
    try {
      await secureStorage?.write(
        key: _sessionStorageKey,
        value: jsonEncode(session.toStorageJson()),
      );
    } catch (_) {}
  }

  Future<void> _clearPersistedSession() async {
    try {
      await secureStorage?.delete(key: _sessionStorageKey);
    } catch (_) {}
  }

  /// Khôi phục phiên đăng nhập đã lưu trong Keychain/Keystore an toàn
  Future<AuthSession?> restorePersistedSession() async {
    try {
      final raw = await secureStorage?.read(key: _sessionStorageKey);
      if (raw != null && raw.isNotEmpty) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final session = AuthSession.fromStorageJson(data);
        if (!session.isExpired && session.accessToken.isNotEmpty) {
          _currentSession = session;
          _sessionController.add(_currentSession);
          return session;
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<AuthSession> login(String emailOrUserId, [String? password]) async {
    if (password == null || password.isEmpty) {
      throw ArgumentError('Email and password are required for backend login');
    }
    return _loginToBackend(email: emailOrUserId, password: password);
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
            body: jsonEncode({'email': email.trim(), 'password': password}),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final session = AuthSession.fromBackendJson(data);
        _currentSession = session;
        _sessionController.add(_currentSession);
        await _persistSession(session);
        return session;
      }

      if (response.statusCode == 401) {
        throw Exception('Sai email hoặc mật khẩu. Vui lòng kiểm tra lại.');
      }

      final errorBody = _parseErrorMessage(response.body);
      throw Exception(
        errorBody.isNotEmpty
            ? errorBody
            : 'Đăng nhập thất bại (${response.statusCode})',
      );
    } catch (e) {
      if (e is Exception &&
          !e.toString().contains('ClientException') &&
          !e.toString().contains('SocketException') &&
          !e.toString().contains('TimeoutException')) {
        rethrow;
      }
      debugPrint(
        '[AuthRepositoryImpl] Network error connecting to $_authUrl: $e',
      );
      throw Exception(
        'Không thể kết nối đến máy chủ Backend tại $_authUrl. Vui lòng kiểm tra lại Endpoint.',
      );
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
        await _persistSession(session);
        return session;
      }

      if (response.statusCode == 409) {
        throw Exception('Email này đã được sử dụng. Vui lòng chọn email khác.');
      }

      final errorBody = _parseErrorMessage(response.body);
      throw Exception(
        errorBody.isNotEmpty
            ? errorBody
            : 'Đăng ký thất bại (${response.statusCode})',
      );
    } catch (e) {
      if (e is Exception &&
          !e.toString().contains('ClientException') &&
          !e.toString().contains('SocketException') &&
          !e.toString().contains('TimeoutException')) {
        rethrow;
      }
      debugPrint(
        '[AuthRepositoryImpl] Network error connecting to $_authUrl: $e',
      );
      throw Exception(
        'Không thể kết nối đến máy chủ Backend tại $_authUrl. Vui lòng kiểm tra lại Endpoint.',
      );
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
    if (session != null && session.accessToken.isNotEmpty) {
      try {
        final client = httpClient ?? http.Client();
        final url = Uri.parse('$_authUrl/logout');
        await client
            .post(
              url,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ${session.accessToken}',
              },
            )
            .timeout(const Duration(seconds: 2));
      } catch (_) {}
    }

    _currentSession = null;
    _sessionController.add(null);
    await _clearPersistedSession();
  }

  void reset() {
    _currentSession = null;
    _sessionController.add(null);
    _clearPersistedSession();
  }

  void dispose() {
    _sessionController.close();
  }
}
