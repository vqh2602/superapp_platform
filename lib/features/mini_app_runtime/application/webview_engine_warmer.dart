// Quản lý và khởi tạo trước WebView engine (WebView Engine Warmer).
//
// Cho phép khởi tạo trước WebViewController (pre-warming) từ sớm
// (ví dụ: khi hiển thị danh mục Mini App Catalog) nhằm triệt tiêu thời gian
// cấp phát WebView Native (150-300ms) trên thiết bị di động.
//
// NGUYÊN TẮC BẢO MẬT BẮT BUỘC:
// Tuyệt đối KHÔNG nạp URL, mã HTML, JS, hay WASM của Mini App vào WebView engine
// đã chuẩn bị trước cho tới khi cả hai bước:
// 1. Xác thực thực thi (authorizeExecution)
// 2. Tải quyền truy cập (ensurePermissionsLoaded)
// đều hoàn tất thành công.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_all/webview_all.dart';

/// Quản lý vòng đời và bộ nhớ đệm của WebView Engine được chuẩn bị trước.
class WebViewEngineWarmer {
  WebViewController? _prewarmedController;

  /// Tạo một WebViewController mới với cấu hình nền tảng cơ bản
  /// (chưa nạp bất kỳ URL hay mã thực thi nào của Mini App).
  WebViewController createEngine() {
    return WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white);
  }

  /// Khởi tạo trước một WebViewController sạch vào bộ nhớ đệm
  void warmUp() {
    if (_prewarmedController != null) return;
    try {
      _prewarmedController = createEngine();
    } catch (e) {
      debugPrint('[WebViewEngineWarmer] Không thể khởi tạo trước WebViewController: $e');
    }
  }

  /// Lấy WebViewController đã được chuẩn bị trước (nếu có).
  ///
  /// Sau khi lấy, Warmer sẽ xóa tham chiếu để chuyển giao toàn bộ quyền sở hữu
  /// cho phiên thực thi (MiniAppRuntimeSession).
  WebViewController? consume() {
    final controller = _prewarmedController;
    _prewarmedController = null;
    return controller;
  }

  /// Kiểm tra xem hiện có WebViewController đang sẵn sàng trong đệm hay không
  bool get hasPrewarmedEngine => _prewarmedController != null;

  /// Giải phóng WebViewController trong đệm (nếu có)
  void clear() {
    if (_prewarmedController != null) {
      try {
        _prewarmedController!.loadRequest(Uri.parse('about:blank'));
      } catch (_) {}
      _prewarmedController = null;
    }
  }
}

/// Provider cung cấp WebViewEngineWarmer cho toàn ứng dụng
final webViewEngineWarmerProvider = Provider<WebViewEngineWarmer>((ref) {
  final warmer = WebViewEngineWarmer();
  ref.onDispose(warmer.clear);
  return warmer;
});
