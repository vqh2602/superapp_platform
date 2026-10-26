import '../models/mock_user.dart';
import '../models/auth_session.dart';

abstract class AuthRepository {
  AuthSession? get currentSession;
  MockUser? get currentUser;
  bool get isAuthenticated;

  Future<AuthSession> login(String userId);
  Future<void> logout();
  Stream<AuthSession?> get sessionStream;
}
