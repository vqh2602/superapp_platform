// Bộ điều khiển trạng thái xác thực người dùng (Auth Controller & State).
//
// Quản lý trạng thái phiên đăng nhập của người dùng toàn ứng dụng thông qua Riverpod Notifier,
// cung cấp các hàm login, register, logout và cơ chế tự động xử lý khi token hết hạn (401).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/router/app_router.dart';
import '../../../../core/config/endpoint_config.dart';
import '../../../../core/network/app_http_client.dart';
import '../../domain/models/auth_session.dart';
import '../../domain/models/platform_user.dart';
import '../../data/auth_repository_impl.dart';
import '../../data/auth_code_service_shim.dart';
import '../../data/token_service_shim.dart';
import '../../../storage/data/secure_storage_repository_impl.dart';

/// Provider cung cấp kho dữ liệu AuthRepositoryImpl kết nối với backend
final authRepositoryProvider = Provider<AuthRepositoryImpl>((ref) {
  final endpoint = ref.watch(backendEndpointProvider);
  final httpClient = ref.watch(appHttpClientProvider);
  final repo = AuthRepositoryImpl(
    authUrl: endpoint.authUrl,
    httpClient: httpClient,
  );
  ref.onDispose(() => repo.dispose());
  return repo;
});

/// Provider cung cấp AuthCodeServiceShim
final authCodeServiceProvider = Provider<AuthCodeServiceShim>((ref) {
  return AuthCodeServiceShim();
});

/// Provider cung cấp TokenServiceShim
final tokenServiceProvider = Provider<TokenServiceShim>((ref) {
  final authCodeService = ref.watch(authCodeServiceProvider);
  return TokenServiceShim(authCodeService: authCodeService);
});

/// Trạng thái xác thực (Auth State) lưu trữ thông tin phiên, loading và lỗi
class AuthState {
  /// Phiên làm việc hiện tại
  final AuthSession? session;
  /// Trạng thái đang xử lý API
  final bool isLoading;
  /// Thông báo lỗi nếu có
  final String? errorMessage;

  const AuthState({
    this.session,
    this.isLoading = false,
    this.errorMessage,
  });

  /// Kiểm tra người dùng đã đăng nhập và phiên còn hạn
  bool get isAuthenticated => session != null && !session!.isExpired;

  /// Lấy thông tin tài khoản người dùng hiện tại
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

/// Notifier quản lý và cập nhật trạng thái xác thực người dùng
class AuthNotifier extends Notifier<AuthState> {
  AuthRepositoryImpl get _repository => ref.read(authRepositoryProvider);
  bool _isHandlingTokenExpired = false;

  @override
  AuthState build() {
    final repo = ref.watch(authRepositoryProvider);
    final sub = repo.sessionStream.listen((session) {
      state = state.copyWith(session: session, clearSession: session == null);
    });
    ref.onDispose(sub.cancel);
    return const AuthState();
  }

  /// Đăng nhập tài khoản bằng email/userId và mật khẩu vào backend
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

  /// Đăng ký tài khoản người dùng mới trên hệ thống backend
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

  /// Đăng xuất khỏi hệ thống và tùy chọn xóa dữ liệu người dùng trong Secure Storage
  Future<void> logout({bool purgeUserData = true}) async {
    final currentUserId = state.currentUser?.id;
    state = state.copyWith(isLoading: true);
    await _repository.logout();
    if (purgeUserData && currentUserId != null && currentUserId.isNotEmpty) {
      try {
        await ref.read(secureStorageRepositoryProvider).clearUserData(currentUserId);
      } catch (_) {}
    }
    state = const AuthState();
  }

  /// Xử lý khi nhận mã lỗi 401 Unauthorized hoặc token hết hạn:
  /// Xóa phiên, điều hướng về màn hình đăng nhập và hiển thị thông báo.
  void handleTokenExpired([String? reason]) {
    if (_isHandlingTokenExpired) return;
    _isHandlingTokenExpired = true;

    final message = reason ?? 'Phiên đăng nhập đã hết hạn (401). Vui lòng đăng nhập lại.';

    // 1. Clear session state & set error message
    state = state.copyWith(
      clearSession: true,
      isLoading: false,
      errorMessage: message,
    );
    _repository.reset();

    // 2. Redirect to /login and present warning SnackBar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        appRouter.go('/login');

        final context = rootNavigatorKey.currentContext;
        if (context != null && context.mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.lock_clock_outlined, color: Colors.amberAccent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF0F172A),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } finally {
        Future.delayed(const Duration(milliseconds: 1000), () {
          _isHandlingTokenExpired = false;
        });
      }
    });
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

final authStateProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
