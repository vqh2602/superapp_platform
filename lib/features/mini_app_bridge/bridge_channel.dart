import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/config/app_config.dart';
import 'bridge_dispatcher.dart';

class BridgeChannel {
  static void register({
    required WebViewController controller,
    required BridgeDispatcher dispatcher,
    required BuildContext Function() contextGetter,
  }) {
    controller.addJavaScriptChannel(
      AppConfig.bridgeChannelName,
      onMessageReceived: (JavaScriptMessage message) {
        dispatcher.handleMessage(message.message, contextGetter());
      },
    );
  }

  /// Injected script to ensure window.SuperAppBridge is bound before JS SDK executes
  static const String bridgePolyfillScript = '''
    (function() {
      if (window.__SUPERAPP_BRIDGE_INJECTED__) return;
      window.__SUPERAPP_BRIDGE_INJECTED__ = true;

      window.SuperAppBridge = window.SuperAppBridge || {
        _listeners: {},
        _callbacks: {},

        postMessage: function(msg) {
          if (window.FlutterBridge && window.FlutterBridge.postMessage) {
            window.FlutterBridge.postMessage(typeof msg === 'string' ? msg : JSON.stringify(msg));
          } else {
            console.warn('[Bridge] FlutterBridge not found on window');
          }
        },

        dispatchResponse: function(res) {
          var cb = this._callbacks[res.id];
          if (cb) {
            delete this._callbacks[res.id];
            cb(res);
          }
        },

        dispatchEvent: function(evt) {
          var list = this._listeners[evt.event] || [];
          for (var i = 0; i < list.length; i++) {
            try { list[i](evt.payload); } catch (e) { console.error(e); }
          }
        },

        addEventListener: function(event, handler) {
          this._listeners[event] = this._listeners[event] || [];
          this._listeners[event].push(handler);
        },

        removeEventListener: function(event, handler) {
          if (!this._listeners[event]) return;
          this._listeners[event] = this._listeners[event].filter(function(h) { return h !== handler; });
        }
      };
    })();
  ''';
}
