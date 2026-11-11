// Quản lý trạng thái chế độ gỡ lỗi (Debug Mode) và cấu hình SERP Debug Overlay.
//
// Cho phép bật/tắt thủ công overlay gỡ lỗi ngay cả trên release build nếu người dùng
// kích hoạt, đồng thời tự động kích hoạt khi ở môi trường phát triển (kDebugMode).
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:serp_debug_overlay/flutter_debug_overlay.dart';

/// Bộ lưu trữ nhật ký Log toàn cục cho bảng điều khiển SERP Debug Overlay (tối đa 500 bản ghi)
final globalLogBucket = LogBucket(maxStoredEntries: 500);

/// Bộ lưu trữ nhật ký HTTP toàn cục cho bảng điều khiển SERP Debug Overlay (tối đa 100 request)
final globalHttpBucket = HttpBucket(maxStoredEntries: 100);

/// Khởi tạo hệ thống bắt nhật ký và lỗi cho SERP Debug Overlay.
/// Bắt log print, lỗi Flutter framework và lỗi unhandled platform.
void initDebugOverlay() {
  if (!LogCapture.isStarted) {
    LogCapture.start(
      globalLogBucket,
      captureDebugPrint: true,
      captureFlutterErrors: true,
      capturePlatformErrors: true,
    );
  }
}

/// Notifier quản lý trạng thái bật/tắt chế độ debug thủ công và lưu vào bộ nhớ an toàn.
class DebugModeNotifier extends Notifier<bool> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _storageKey = 'superapp_debug_mode_enabled';

  @override
  bool build() {
    _loadState();
    DebugOverlay.enabled = kDebugMode;
    return false;
  }

  /// Tải cấu hình debug đã lưu trước đó từ secure storage
  Future<void> _loadState() async {
    try {
      final val = await _storage.read(key: _storageKey);
      if (val == 'true') {
        state = true;
        DebugOverlay.enabled = true;
      }
    } catch (_) {}
  }

  /// Kích hoạt chế độ debug và lưu vào bộ nhớ
  Future<void> enableDebug() async {
    state = true;
    DebugOverlay.enabled = true;
    try {
      await _storage.write(key: _storageKey, value: 'true');
    } catch (_) {}
  }

  /// Tắt chế độ debug thủ công và khôi phục về trạng thái kDebugMode mặc định
  Future<void> disableDebug() async {
    state = false;
    DebugOverlay.enabled = kDebugMode;
    try {
      await _storage.write(key: _storageKey, value: 'false');
    } catch (_) {}
  }

  /// Đảo ngược trạng thái kích hoạt debug
  Future<void> toggleDebug() async {
    if (state) {
      await disableDebug();
    } else {
      await enableDebug();
    }
  }
}

/// Provider cung cấp controller quản lý bật/tắt Debug Mode
final debugModeNotifierProvider =
    NotifierProvider<DebugModeNotifier, bool>(DebugModeNotifier.new);

/// Provider kiểm tra trạng thái Debug Mode đang hoạt động.
/// Trả về true nếu người dùng chủ động bật HOẶC ứng dụng đang chạy ở chế độ debug Flutter (`kDebugMode`).
final isDebugModeEnabledProvider = Provider<bool>((ref) {
  final userEnabled = ref.watch(debugModeNotifierProvider);
  final isEnabled = userEnabled || kDebugMode;
  DebugOverlay.enabled = isEnabled;
  return isEnabled;
});
