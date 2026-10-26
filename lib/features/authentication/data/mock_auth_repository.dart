import 'dart:async';
import 'package:uuid/uuid.dart';
import '../domain/models/auth_session.dart';
import '../domain/models/mock_user.dart';
import '../domain/repositories/auth_repository.dart';

class MockAuthRepository implements AuthRepository {
  final _uuid = const Uuid();
  AuthSession? _currentSession;
  final _sessionController = StreamController<AuthSession?>.broadcast();

  @override
  AuthSession? get currentSession => _currentSession;

  @override
  MockUser? get currentUser => _currentSession?.user;

  @override
  bool get isAuthenticated => _currentSession != null && !_currentSession!.isExpired;

  @override
  Stream<AuthSession?> get sessionStream => _sessionController.stream;

  @override
  Future<AuthSession> login(String userId) async {
    final user = MockUser.demoUsers.firstWhere(
      (u) => u.id == userId,
      orElse: () => MockUser.userA,
    );

    // Create simulated session with dummy tokens (NOT production credentials)
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

  @override
  Future<void> logout() async {
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
