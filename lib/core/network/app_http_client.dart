import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:serp_debug_overlay/flutter_debug_overlay.dart';
import '../config/debug_mode_provider.dart';
import '../../features/authentication/presentation/controllers/auth_controller.dart';

/// HTTP Client Interceptor that detects 401 Unauthorized errors (expired token)
/// and triggers the redirection callback to the login screen.
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

    // If 401 Unauthorized received
    if (response.statusCode == 401) {
      final path = request.url.path.toLowerCase();
      // Only trigger if this is NOT a direct login/register attempt
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

/// Helper function to create the composite app HTTP client
http.Client createAppHttpClient({
  required VoidCallback onTokenExpired,
  http.Client? baseClient,
}) {
  final raw = baseClient ?? http.Client();
  // 1. Wrap with serp_debug_overlay HttpLogClient to capture HTTP traffic
  final loggingClient = HttpLogClient(globalHttpBucket, raw);
  // 2. Wrap with AuthExpiredInterceptorClient to handle 401 token expiration
  return AuthExpiredInterceptorClient(
    loggingClient,
    onTokenExpired: onTokenExpired,
  );
}

/// Global Riverpod Provider for the application HTTP client
final appHttpClientProvider = Provider<http.Client>((ref) {
  final client = createAppHttpClient(
    onTokenExpired: () {
      ref.read(authStateProvider.notifier).handleTokenExpired();
    },
  );
  ref.onDispose(client.close);
  return client;
});

