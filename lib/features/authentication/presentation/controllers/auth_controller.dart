import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/endpoint_config.dart';
import '../../domain/models/auth_session.dart';
import '../../domain/models/platform_user.dart';
import '../../data/auth_repository_impl.dart';
import '../../data/auth_code_service_shim.dart';
import '../../data/token_service_shim.dart';

/// Core provider for AuthRepositoryImpl connected to backend endpoint
final authRepositoryProvider = Provider<AuthRepositoryImpl>((ref) {
  final endpoint = ref.watch(backendEndpointProvider);
  final repo = AuthRepositoryImpl(authUrl: endpoint.authUrl);
  ref.onDispose(() => repo.dispose());
  return repo;
});

/// Core provider for AuthCodeServiceShim
final authCodeServiceProvider = Provider<AuthCodeServiceShim>((ref) {
  return AuthCodeServiceShim();
});

/// Core provider for TokenServiceShim
final tokenServiceProvider = Provider<TokenServiceShim>((ref) {
  final authCodeService = ref.watch(authCodeServiceProvider);
  return TokenServiceShim(authCodeService: authCodeService);
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
  PlatformUser? get currentUser => session?.user;

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
  final AuthRepositoryImpl _repository;

  AuthNotifier(this._repository) : super(const AuthState()) {
    // Listen to repository stream
    _repository.sessionStream.listen((session) {
      state = state.copyWith(session: session, clearSession: session == null);
    });
  }

  /// Login with email and password to backend
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
  final repo = ref.watch(authRepositoryProvider);
  return AuthNotifier(repo);
});
