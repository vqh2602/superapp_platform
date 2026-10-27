import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/endpoint_config.dart';
import '../../domain/models/auth_session.dart';
import '../../domain/models/mock_user.dart';
import '../../data/mock_auth_repository.dart';
import '../../data/mock_auth_code_service.dart';
import '../../data/mock_token_service.dart';

/// Core provider for MockAuthRepository connected to backend endpoint
final mockAuthRepositoryProvider = Provider<MockAuthRepository>((ref) {
  final endpoint = ref.watch(backendEndpointProvider);
  final repo = MockAuthRepository(authUrl: endpoint.authUrl);
  ref.onDispose(() => repo.dispose());
  return repo;
});

/// Core provider for MockAuthCodeService
final mockAuthCodeServiceProvider = Provider<MockAuthCodeService>((ref) {
  return MockAuthCodeService();
});

/// Core provider for MockTokenService
final mockTokenServiceProvider = Provider<MockTokenService>((ref) {
  final authCodeService = ref.watch(mockAuthCodeServiceProvider);
  return MockTokenService(authCodeService: authCodeService);
});

/// Auth state holder
class AuthState {
  final AuthSession? session;
  final bool isLoading;
  final String? errorMessage;

  const AuthState({
    this.session,
    this.isLoading = false,
    this.errorMessage,
  });

  bool get isAuthenticated => session != null && !session!.isExpired;
  MockUser? get currentUser => session?.user;

  AuthState copyWith({
    AuthSession? session,
    bool? isLoading,
    String? errorMessage,
    bool clearSession = false,
    bool clearError = false,
  }) {
    return AuthState(
      session: clearSession ? null : (session ?? this.session),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final MockAuthRepository _repository;

  AuthNotifier(this._repository) : super(const AuthState()) {
    // Listen to repository stream
    _repository.sessionStream.listen((session) {
      state = state.copyWith(session: session, clearSession: session == null);
    });
  }

  /// Login with email and password to backend, or legacy mock login with userId
  Future<bool> login(String emailOrUserId, [String? password]) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final session = await _repository.login(emailOrUserId, password);
      state = state.copyWith(session: session, isLoading: false, clearError: true);
      return true;
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    }
  }

  /// Register new user account to backend
  Future<bool> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final session = await _repository.register(
        email: email,
        password: password,
        displayName: displayName,
      );
      state = state.copyWith(session: session, isLoading: false, clearError: true);
      return true;
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    await _repository.logout();
    state = const AuthState();
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repo = ref.watch(mockAuthRepositoryProvider);
  return AuthNotifier(repo);
});
