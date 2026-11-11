// Quản lý cấu hình tải trọng và bộ giới hạn tần suất (Rate Limiter) cho Bridge.
//
// Bảo vệ UI Isolate của Flutter không bị quá tải khi Mini App gửi lượng lớn dữ liệu
// hoặc gọi RPC với tần suất quá cao (Sliding Window Rate Limiter).
import 'dart:collection';

/// Bộ kiểm soát tần suất gọi Bridge (Rate Limiter) dựa trên thuật toán sliding window.
class BridgeRateLimiter {
  final int maxRequestsPerWindow;
  final Duration windowDuration;
  final Queue<DateTime> _requestTimestamps = Queue<DateTime>();

  BridgeRateLimiter({
    this.maxRequestsPerWindow = 50,
    this.windowDuration = const Duration(seconds: 1),
  });

  /// Kiểm tra xem request mới có được phép thực thi hay bị giới hạn tần suất.
  bool allowRequest([DateTime? now]) {
    final current = now ?? DateTime.now();
    final cutoff = current.subtract(windowDuration);

    while (_requestTimestamps.isNotEmpty && _requestTimestamps.first.isBefore(cutoff)) {
      _requestTimestamps.removeFirst();
    }

    if (_requestTimestamps.length >= maxRequestsPerWindow) {
      return false;
    }

    _requestTimestamps.add(current);
    return true;
  }

  /// Số lượng request đã ghi nhận trong cửa sổ hiện tại.
  int get currentCount => _requestTimestamps.length;

  /// Đặt lại bộ đếm rate limiter.
  void reset() {
    _requestTimestamps.clear();
  }
}

/// Cấu hình giới hạn tải an toàn cho Native Bridge nhằm bảo vệ UI isolate và hệ thống.
class BridgeLoadConfig {
  /// Kích thước tối đa cho phép của một message raw JSON (bytes). Mặc định 1MB (1,048,576 bytes).
  final int maxMessageSizeBytes;

  /// Số lượng RPC in-flight đồng thời tối đa cho một phiên Mini App. Mặc định 15.
  final int maxConcurrentRequests;

  /// Số lượng request tối đa trong một cửa sổ thời gian (Rate Limit). Mặc định 50 req/giây.
  final int maxRequestsPerWindow;

  /// Độ dài cửa sổ thời gian Rate Limit. Mặc định 1 giây.
  final Duration rateLimitWindow;

  /// Số lượng tối đa các tác vụ tương tác người dùng (dialog, prompt) được phép xếp hàng. Mặc định 5.
  final int maxQueuedUserInteractions;

  const BridgeLoadConfig({
    this.maxMessageSizeBytes = 1024 * 1024,
    this.maxConcurrentRequests = 15,
    this.maxRequestsPerWindow = 50,
    this.rateLimitWindow = const Duration(seconds: 1),
    this.maxQueuedUserInteractions = 5,
  });

  static const BridgeLoadConfig defaultConfig = BridgeLoadConfig();
}
