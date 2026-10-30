import '../models/platform_user.dart';
import '../models/auth_session.dart';

abstract class AuthRepository {
  AuthSession? get currentSession;
  PlatformUser? get currentUser;
  bool get isAuthenticated;

  Future<AuthSession> login(String emailOrUserId, [String? password]);
  Future<AuthSession> register({
    required String email,
    required String password,
    required String displayName,
  });
  Future<void> logout();
  Stream<AuthSession?> get sessionStream;
}
