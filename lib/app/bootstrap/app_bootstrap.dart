// Widget gốc cấu hình SuperApp Platform.
//
// Chịu trách nhiệm thiết lập MaterialApp với GoRouter, cấu hình theme hệ thống,
// và tích hợp DebugOverlay để hiển thị các công cụ gỡ lỗi khi ở chế độ phát triển.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:serp_debug_overlay/flutter_debug_overlay.dart';
import '../../core/config/app_config.dart';
import '../../core/config/app_theme.dart';
import '../../core/config/debug_mode_provider.dart';
import '../router/app_router.dart';

/// [SuperApp] là Root Widget của ứng dụng sử dụng ConsumerWidget của Riverpod.
///
/// Lắng nghe trạng thái debug thông qua [isDebugModeEnabledProvider] để kích hoạt
/// hoặc vô hiệu hóa bảng điều khiển [DebugOverlay].
class SuperApp extends ConsumerWidget {
  const SuperApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Theo dõi trạng thái bật/tắt debug mode (kết hợp chế độ thủ công và kDebugMode)
    final isDebugActive = ref.watch(isDebugModeEnabledProvider);
    DebugOverlay.enabled = isDebugActive;

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: appRouter,
      builder: (context, child) {
        // Bao bọc toàn bộ giao diện bằng DebugOverlay để hỗ trợ inspect log và request HTTP
        return DebugOverlay(
          logBucket: globalLogBucket,
          httpBucket: globalHttpBucket,
          isDevelop: isDebugActive,
          enableFloatingButton: false,
          pointers: 2,
          // hiddenFields: const [
          //   'Authorization',
          //   'token',
          //   'api-key',
          //   'password',
          // ],
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
