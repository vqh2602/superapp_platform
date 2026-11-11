// Quản lý HTTP Client của ứng dụng và cơ chế đánh chặn (Interceptor).
//
// Hỗ trợ tự động bắt lỗi 401 Unauthorized khi token hết hạn để kích hoạt điều hướng
// về màn hình đăng nhập, đồng thời tích hợp logging mạng tự động với SERP Debug Overlay.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:serp_debug_overlay/flutter_debug_overlay.dart';
import '../config/debug_mode_provider.dart';
import '../../features/authentication/presentation/controllers/auth_controller.dart';

/// Interceptor phát hiện mã lỗi 401 Unauthorized (token hết hạn)
/// và kích hoạt callback điều hướng người dùng về màn hình đăng nhập.
class AuthExpiredInterceptorClient extends http.BaseClient {
  final http.Client _inner;
  final VoidCallback onTokenExpired;

  AuthExpiredInterceptorClient(
    this._inner, {
    required this.onTokenExpired,
  });

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(request);

    // Kiểm tra nếu nhận mã phản hồi 401 Unauthorized
    if (response.statusCode == 401) {
      final path = request.url.path.toLowerCase();
      // Chỉ kích hoạt callback nếu request này KHÔNG PHẢI là thao tác login hoặc register trực tiếp
      final isAuthAttempt =
          path.endsWith('/login') || path.endsWith('/register');

      if (!isAuthAttempt) {
        debugPrint(
          '[AuthExpiredInterceptor] 401 Unauthorized on ${request.method} ${request.url}. Triggering redirect to login.',
        );
        onTokenExpired();
      }
    }

    return response;
  }

  @override
  void close() => _inner.close();
}

/// Hàm tạo đối tượng HTTP Client tổng hợp cho SuperApp
///
/// Kết hợp HttpLogClient để ghi log request/response vào SERP Debug Overlay
/// và AuthExpiredInterceptorClient để tự động xử lý token hết hạn.
http.Client createAppHttpClient({
  required VoidCallback onTokenExpired,
  http.Client? baseClient,
}) {
  final raw = baseClient ?? http.Client();
  // 1. Wrap với HttpLogClient của serp_debug_overlay để hiển thị trên overlay gỡ lỗi
  final loggingClient = HttpLogClient(globalHttpBucket, raw);
  // 2. Wrap với AuthExpiredInterceptorClient để xử lý lỗi 401
  return AuthExpiredInterceptorClient(
    loggingClient,
    onTokenExpired: onTokenExpired,
  );
}

/// Provider toàn cục cung cấp đối tượng http.Client dùng xuyên suốt ứng dụng
final appHttpClientProvider = Provider<http.Client>((ref) {
  final client = createAppHttpClient(
    onTokenExpired: () {
      ref.read(authStateProvider.notifier).handleTokenExpired();
    },
  );
  ref.onDispose(client.close);
  return client;
});

