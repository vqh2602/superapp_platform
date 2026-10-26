import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/auth_session.dart';
import '../../domain/models/mock_user.dart';
import '../../data/mock_auth_repository.dart';
import '../../data/mock_auth_code_service.dart';
import '../../data/mock_token_service.dart';

/// Core provider for MockAuthRepository
final mockAuthRepositoryProvider = Provider<MockAuthRepository>((ref) {
  final repo = MockAuthRepository();
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
  }) {
    return AuthState(
      session: clearSession ? null : (session ?? this.session),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
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

  Future<void> login(String userId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final session = await _repository.login(userId);
      state = state.copyWith(session: session, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    await _repository.logout();
    state = const AuthState();
  }
}

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repo = ref.watch(mockAuthRepositoryProvider);
  return AuthNotifier(repo);
});
