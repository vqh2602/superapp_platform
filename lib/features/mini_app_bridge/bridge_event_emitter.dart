import 'dart:convert';
import 'package:webview_all/webview_all.dart';
import '../../../core/bridge_protocol/bridge_event.dart';

class BridgeEventEmitter {
  final WebViewController controller;

  BridgeEventEmitter(this.controller);

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

  Future<void> emitSessionChanged({required String state, String? userId}) async {
    await emit('auth.sessionChanged', {
      'state': state,
      'userId': userId,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<void> emitPaymentStatusChanged({
    required String orderId,
    required String status,
  }) async {
    await emit('payment.statusChanged', {
      'orderId': orderId,
      'status': status,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
}
