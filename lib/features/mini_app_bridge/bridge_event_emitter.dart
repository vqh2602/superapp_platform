// Bộ phát sự kiện bất đồng bộ từ Flutter xuống WebView (Bridge Event Emitter).
//
// Chuyển đổi các sự kiện Native thành JavaScript Event thông qua hàm
// `window.SuperAppBridge.dispatchEvent` để Mini App lắng nghe và phản hồi.
import 'dart:convert';
import 'package:webview_all/webview_all.dart';
import '../../../core/bridge_protocol/bridge_event.dart';

/// Lớp phát sự kiện từ tầng Native sang Mini App
class BridgeEventEmitter {
  final WebViewController controller;

  BridgeEventEmitter(this.controller);

  /// Phát một sự kiện tùy ý kèm payload dữ liệu xuống Mini App
  Future<void> emit(String eventName, [Map<String, dynamic>? payload]) async {
    final event = BridgeEvent.create(eventName, payload);
    final eventJson = jsonEncode(event.toJson());
    final script = '''
      try {
        if (window.SuperAppBridge && typeof window.SuperAppBridge.dispatchEvent === 'function') {
          window.SuperAppBridge.dispatchEvent($eventJson);
        }
      } catch (err) {
        console.error('[Bridge EventEmitter] Failed to dispatch event "$eventName":', err.message || err, err.stack || '');
      }
    ''';
    try {
      await controller.runJavaScript(script);
    } catch (_) {
      // WebView might not be ready or page destroyed
    }
  }

  /// Phát sự kiện thay đổi trạng thái phiên đăng nhập của người dùng (`auth.sessionChanged`)
  Future<void> emitSessionChanged({required String state, String? userId}) async {
    await emit('auth.sessionChanged', {
      'state': state,
      'userId': userId,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
}
