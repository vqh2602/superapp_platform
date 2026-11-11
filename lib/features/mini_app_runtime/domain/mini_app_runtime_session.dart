// Quản lý phiên thực thi WebView runtime cô lập (Mini App Runtime Session).
//
// Chịu trách nhiệm lưu trữ và dọn dẹp các tài nguyên thuộc về phiên thực thi WebView:
// controller, dispatcher, event emitter, các bộ đếm timer theo dõi tiến trình tải và kiểm tra màn hình trắng.
import 'dart:async';
import 'package:webview_all/webview_all.dart';
import '../../mini_app_bridge/bridge_dispatcher.dart';
import '../../mini_app_bridge/bridge_event_emitter.dart';
import '../../native_actions/application/native_action_dispatcher.dart';

/// Quản lý vòng đời và tập hợp tài nguyên cô lập của một phiên chạy Mini App WebView.
///
/// Mỗi phiên (khởi chạy lần đầu, chuyển đổi Mini App qua `onSwitchMiniApp`, hoặc reload) sở hữu một:
/// - `sessionId`: Định danh ngẫu nhiên (UUID v4) của phiên Host, dùng để xác thực session integrity.
/// - `appId`: Định danh Mini App đang thực thi trong phiên.
/// - `controller`: WebViewController riêng biệt của phiên.
/// - `dispatcher`: BridgeDispatcher riêng biệt, tự ngắt xử lý RPC khi phiên kết thúc.
/// - `eventEmitter`: BridgeEventEmitter riêng biệt gửi sự kiện vào WebView của phiên.
/// - Tập hợp các Timer riêng biệt (`loadTimeoutTimer`, `overlayDismissTimer`, `diagnosticTimer`, `progressTicker`).
///
/// Đảm bảo tính cô lập phiên:
/// - Khi chuyển Mini App hoặc hủy phiên, toàn bộ timer và RPC đang thực hiện được hủy ngay lập tức.
/// - Ngăn chặn triệt để race condition khi chuyển app nhanh hoặc mạng chậm.
/// - WebView cũ được giải phóng và hủy kết nối JS, ngăn rò rỉ response sang Mini App mới.
class MiniAppRuntimeSession {
  final String sessionId;
  final String appId;
  final DateTime createdAt;

  bool _isDisposed = false;

  WebViewController? controller;
  BridgeDispatcher? dispatcher;
  NativeActionDispatcher? actionDispatcher;
  BridgeEventEmitter? eventEmitter;

  Timer? progressTicker;
  Timer? loadTimeoutTimer;
  Timer? overlayDismissTimer;
  Timer? diagnosticTimer;

  final List<Timer> _activeTimers = [];

  MiniAppRuntimeSession({
    required this.sessionId,
    required this.appId,
  }) : createdAt = DateTime.now();

  /// Trạng thái phiên đã bị hủy / kết thúc hay chưa.
  bool get isDisposed => _isDisposed;

  /// Phiên vẫn đang hoạt động hợp lệ.
  bool get isActive => !_isDisposed;

  /// Đăng ký timer phát sinh vào phiên để tự động hủy khi phiên kết thúc.
  void registerTimer(Timer timer) {
    if (_isDisposed) {
      timer.cancel();
      return;
    }
    _activeTimers.add(timer);
  }

  /// Hủy phiên làm việc hiện tại, giải phóng toàn bộ timer, ngắt dispatcher và giải phóng WebView.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;

    // 1. Hủy toàn bộ timer thuộc phiên này
    progressTicker?.cancel();
    progressTicker = null;

    loadTimeoutTimer?.cancel();
    loadTimeoutTimer = null;

    overlayDismissTimer?.cancel();
    overlayDismissTimer = null;

    diagnosticTimer?.cancel();
    diagnosticTimer = null;

    for (final timer in _activeTimers) {
      timer.cancel();
    }
    _activeTimers.clear();

    // 2. Hủy Bridge Dispatcher và Action Dispatcher (ngắt gửi response và hủy hàng đợi UI)
    dispatcher?.dispose();
    dispatcher = null;
    actionDispatcher?.dispose();
    actionDispatcher = null;
    eventEmitter = null;

    // 3. Giải phóng WebViewController cũ
    if (controller != null) {
      try {
        controller!.loadRequest(Uri.parse('about:blank'));
      } catch (_) {}
      controller = null;
    }
  }
}
