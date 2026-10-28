import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Bridge client for Flutter Web Mini Apps running inside SuperApp WebView.
class SuperAppBridgeClient {
  static final SuperAppBridgeClient _instance = SuperAppBridgeClient._internal();
  factory SuperAppBridgeClient() => _instance;
  SuperAppBridgeClient._internal();

  static int _sequence = 0;
  static final Map<String, Completer<dynamic>> _callbacks = {};
  static final Map<String, List<Function(dynamic)>> _eventListeners = {};
  static bool _initialized = false;

  String _appId = 'flutter_web_demo';

  void init({required String appId}) {
    if (_initialized) return;
    _appId = appId;
    _initialized = true;
    _setupGlobalDispatcher();
  }

  void _setupGlobalDispatcher() {
    final jsBridge = JSObject();

    jsBridge['dispatchResponse'] = ((JSAny responseRaw) {
      try {
        final dartJson = jsonDecode(jsonEncode(responseRaw.dartify())) as Map<String, dynamic>;
        final String id = dartJson['id'] ?? '';
        final bool success = dartJson['success'] ?? false;
        final dynamic data = dartJson['data'];
        final dynamic error = dartJson['error'];

        final completer = _callbacks.remove(id);
        if (completer != null) {
          if (success) {
            completer.complete(data);
          } else {
            completer.completeError(error ?? {'message': 'Operation failed'});
          }
        }
      } catch (e) {
        web.console.error('[FlutterWebBridge] Failed to parse response: $e'.toJS);
      }
    }).toJS;

    jsBridge['dispatchEvent'] = ((JSAny eventRaw) {
      try {
        final dartJson = jsonDecode(jsonEncode(eventRaw.dartify())) as Map<String, dynamic>;
        final String eventName = dartJson['event'] ?? '';
        final dynamic payload = dartJson['payload'];

        final listeners = _eventListeners[eventName];
        if (listeners != null) {
          for (final callback in listeners) {
            callback(payload);
          }
        }
      } catch (e) {
        web.console.error('[FlutterWebBridge] Failed to parse event: $e'.toJS);
      }
    }).toJS;

    (web.window as JSObject)['SuperAppBridge'] = jsBridge;
  }

  bool isConnectedToSuperApp() {
    final win = web.window as JSObject;
    return win.hasProperty('FlutterBridge'.toJS).toDart;
  }

  Future<T> invoke<T>(String action, [Map<String, dynamic> payload = const {}, int timeoutSeconds = 10]) {
    final id = 'req_${DateTime.now().millisecondsSinceEpoch}_${++_sequence}';
    final completer = Completer<dynamic>();
    _callbacks[id] = completer;

    final requestMap = {
      'id': id,
      'action': action,
      'payload': payload,
      'appId': _appId,
      'origin': web.window.location.origin,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    final jsonPayload = jsonEncode(requestMap);

    if (isConnectedToSuperApp()) {
      final win = web.window as JSObject;
      final flutterBridge = win['FlutterBridge'] as JSObject;
      final postMessageFn = flutterBridge['postMessage'] as JSFunction;
      postMessageFn.callAsFunction(flutterBridge, jsonPayload.toJS);
    } else if (web.window.parent != null && web.window.parent != web.window) {
      web.window.parent!.postMessage(jsonPayload.toJS, '*'.toJS);
    } else {
      _handleLocalMockFallback(id, action, payload);
    }

    return completer.future.timeout(
      Duration(seconds: timeoutSeconds),
      onTimeout: () {
        _callbacks.remove(id);
        throw TimeoutException('Bridge call "$action" timed out after ${timeoutSeconds}s');
      },
    ).then((value) => value as T);
  }

  void on(String event, Function(dynamic) callback) {
    _eventListeners.putIfAbsent(event, () => []).add(callback);
  }

  void _handleLocalMockFallback(String id, String action, Map<String, dynamic> payload) {
    Timer(const Duration(milliseconds: 150), () {
      final completer = _callbacks.remove(id);
      if (completer == null) return;

      switch (action) {
        case 'device.getBatteryInfo':
          completer.complete({'batteryLevel': 90, 'isCharging': true});
          break;
        case 'user.getProfile':
          completer.complete({'id': 'dev_01', 'name': 'Demo User', 'role': 'DEVELOPER'});
          break;
        default:
          completer.complete({'status': 'OK', 'mock': true});
      }
    });
  }
}
