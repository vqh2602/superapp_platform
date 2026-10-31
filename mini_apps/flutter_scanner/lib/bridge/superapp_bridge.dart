import 'dart:async';
import 'dart:convert';
import 'dart:js_util' as js_util;

/// SuperApp JavaScript Bridge Wrapper for Flutter Web Mini Apps.
/// Communicates directly with `window.SuperAppBridge` injected by the host shell.
class SuperAppBridge {
  SuperAppBridge._();

  static dynamic _hostBridge() {
    for (final name in ['bridge', 'SuperAppBridge']) {
      final bridge = js_util.getProperty<dynamic>(js_util.globalThis, name);
      if (bridge != null && js_util.getProperty<dynamic>(bridge, 'invoke') != null) return bridge;
    }
    return null;
  }

  static bool isAvailable() {
    try {
      final channel = js_util.getProperty<dynamic>(js_util.globalThis, 'FlutterBridge');
      return channel != null && _hostBridge() != null;
    } catch (_) { return false; }
  }

  static Map<String, dynamic> _mapResponse(dynamic response, String action) {
    if (response is Map) return response.cast<String, dynamic>();
    throw StateError('Invalid native response for $action');
  }

  /// Low-level bridge invoke method: sends action name & payload to SuperApp Native Container
  static Future<dynamic> invoke(String action, [Map<String, dynamic>? payload]) async {
    try {
      final bridge = _hostBridge();
      if (bridge == null) {
        throw StateError('SuperAppBridge không tồn tại trên window object');
      }

      final jsPayload = js_util.jsify(payload ?? {});
      final promise = js_util.callMethod(bridge, 'invoke', [action, jsPayload]);
      final rawResult = await js_util.promiseToFuture(promise);

      if (rawResult == null) return null;

      // Safely serialize JS object into standard Dart Map/List/Primitive
      final jsonHelper = js_util.getProperty(js_util.globalThis, 'JSON');
      final jsonStr = js_util.callMethod(jsonHelper, 'stringify', [rawResult]) as String?;
      if (jsonStr != null && jsonStr.isNotEmpty) {
        return jsonDecode(jsonStr);
      }
      return rawResult;
    } catch (e) {
      // If error is a JS Error or BridgeError object
      try {
        final jsonHelper = js_util.getProperty(js_util.globalThis, 'JSON');
        final errStr = js_util.callMethod(jsonHelper, 'stringify', [e]) as String?;
        if (errStr != null && errStr.isNotEmpty) {
          final errMap = jsonDecode(errStr);
          throw Exception(errMap['message'] ?? errMap['code'] ?? e.toString());
        }
      } catch (_) {}
      rethrow;
    }
  }

  /// Quét mã QR / Barcode bằng Camera Native của SuperApp
  static Future<Map<String, dynamic>> scanQr({String? prompt}) async {
    final res = await invoke('media.scanQRCode', {
      if (prompt != null) 'prompt': prompt,
    });
    return _mapResponse(res, 'media.scanQRCode');
  }

  /// Chọn ảnh từ thư viện
  static Future<Map<String, dynamic>> chooseImage() async {
    final res = await invoke('media.chooseImage', {'count': 1});
    return _mapResponse(res, 'media.chooseImage');
  }

  /// Hiển thị thông báo Toast nhanh
  static Future<void> showToast(String message) async {
    await invoke('ui.showToast', {'message': message});
  }

  /// Kích hoạt rung phản hồi xúc giác
  static Future<void> vibrate([String style = 'medium']) async {
    await invoke('vibrate', {'style': style});
  }

  /// Sao chép văn bản vào bộ nhớ tạm
  static Future<void> copyToClipboard(String text) async {
    await invoke('copyToClipboard', {'text': text});
  }

  /// Mở liên kết trình duyệt ngoài
  static Future<void> openExternalUrl(String url) async {
    await invoke('phone.openExternalBrowser', {'url': url});
  }

  /// Đóng Mini App và quay lại màn hình SuperApp Launcher
  static Future<void> closeApp() async {
    await invoke('navigation.close');
  }

  /// Lấy thông tin pin thiết bị
  static Future<Map<String, dynamic>> getBatteryInfo() async {
    final res = await invoke('getBatteryInfo');
    return _mapResponse(res, 'getBatteryInfo');
  }

  /// Lấy thông tin mạng hiện tại
  static Future<Map<String, dynamic>> getNetworkInfo() async {
    final res = await invoke('getNetworkInfo');
    return _mapResponse(res, 'getNetworkInfo');
  }
}
