import 'package:flutter/widgets.dart';
import 'package:webview_all/webview_all.dart';
import '../../../core/config/app_config.dart';
import 'bridge_dispatcher.dart';

class BridgeChannel {
  static const String webDebugChannelName = '__SuperAppWebDebug__';

  static void register({
    required WebViewController controller,
    required BridgeDispatcher dispatcher,
    required BuildContext Function() contextGetter,
    void Function(String message)? onWebDebugMessage,
  }) {
    controller.addJavaScriptChannel(
      AppConfig.bridgeChannelName,
      onMessageReceived: (JavaScriptMessage message) {
        dispatcher.handleMessage(message.message, contextGetter());
      },
    );

    if (onWebDebugMessage != null) {
      controller.addJavaScriptChannel(
        webDebugChannelName,
        onMessageReceived: (JavaScriptMessage message) {
          onWebDebugMessage(message.message);
        },
      );
    }
  }

  /// Injected script to intercept console logs, unhandled errors and rejections
  static const String webDebugPolyfillScript = '''
    (function() {
      if (window.__SUPERAPP_DEBUG_INJECTED__) return;
      window.__SUPERAPP_DEBUG_INJECTED__ = true;
      window.__WEBVIEW_LOGS__ = window.__WEBVIEW_LOGS__ || [];

      function sendToFlutter(entry) {
        window.__WEBVIEW_LOGS__.push(entry);
        try {
          if (window.__SuperAppWebDebug__ && window.__SuperAppWebDebug__.postMessage) {
            window.__SuperAppWebDebug__.postMessage(JSON.stringify(entry));
          }
        } catch(e) {}
      }

      var levels = ['log', 'info', 'warn', 'error', 'debug'];
      levels.forEach(function(lvl) {
        var orig = console[lvl];
        console[lvl] = function() {
          var args = Array.prototype.slice.call(arguments);
          var text = args.map(function(a) {
            if (typeof a === 'object') {
              try { return JSON.stringify(a); } catch(e) { return String(a); }
            }
            return String(a);
          }).join(' ');
          sendToFlutter({
            id: 'log_' + Date.now() + '_' + Math.random().toString(36).substr(2, 5),
            type: 'console',
            level: lvl,
            message: text,
            timeMs: Date.now()
          });
          if (orig) orig.apply(console, arguments);
        };
      });

      window.addEventListener('error', function(e) {
        var msg = (e.message || 'Uncaught Error');
        var stack = e.error && e.error.stack ? e.error.stack : null;
        if (e.filename) msg += ' at ' + e.filename + ':' + (e.lineno || '') + ':' + (e.colno || '');
        if (msg === 'Script error.' || msg === 'Script error') {
          msg = 'Script error: Lỗi runtime trong script (bị WebKit giới hạn chi tiết do CORS/file:// policy).';
          if (!stack) {
            stack = 'Gợi ý: Lỗi xảy ra trong quá trình thực thi mã JS hoặc evaluateJavaScript từ Native. Hãy bọc khối mã trong try...catch để xem chi tiết đầy đủ.';
          }
        }
        sendToFlutter({
          id: 'err_' + Date.now(),
          type: 'error',
          level: 'error',
          message: msg,
          stack: stack,
          timeMs: Date.now()
        });
      });

      window.addEventListener('unhandledrejection', function(e) {
        var reason = e.reason ? (e.reason.stack || e.reason.message || String(e.reason)) : 'Unknown rejection';
        sendToFlutter({
          id: 'rej_' + Date.now(),
          type: 'unhandledrejection',
          level: 'error',
          message: '[Unhandled Rejection] ' + reason,
          stack: e.reason && e.reason.stack ? e.reason.stack : null,
          timeMs: Date.now()
        });
      });
    })();
  ''';

  /// Injected script to ensure window.SuperAppBridge is bound before JS SDK executes
  static const String bridgePolyfillScript = '''
    (function() {
      if (window.__SUPERAPP_BRIDGE_INJECTED__) return;
      window.__SUPERAPP_BRIDGE_INJECTED__ = true;

      window.SuperAppBridge = window.SuperAppBridge || {};
      window.SuperAppBridge._listeners = window.SuperAppBridge._listeners || {};
      window.SuperAppBridge._callbacks = window.SuperAppBridge._callbacks || {};

      if (!window.SuperAppBridge.postMessage) {
        window.SuperAppBridge.postMessage = function(msg) {
          if (window.FlutterBridge && window.FlutterBridge.postMessage) {
            window.FlutterBridge.postMessage(typeof msg === 'string' ? msg : JSON.stringify(msg));
          } else {
            console.warn('[Bridge] FlutterBridge not found on window');
          }
        };
      }

      if (!window.SuperAppBridge.dispatchResponse) {
        window.SuperAppBridge.dispatchResponse = function(res) {
          var cb = this._callbacks[res.id];
          if (cb) {
            delete this._callbacks[res.id];
            cb(res);
          }
        };
      }

      if (!window.SuperAppBridge.dispatchEvent) {
        window.SuperAppBridge.dispatchEvent = function(evt) {
          var list = this._listeners[evt.event] || [];
          for (var i = 0; i < list.length; i++) {
            try {
              list[i](evt.payload);
            } catch (e) {
              console.error('[Bridge dispatchEvent listener error]', e.message || e, e.stack || '');
            }
          }
        };
      }

      if (!window.SuperAppBridge.addEventListener) {
        window.SuperAppBridge.addEventListener = function(event, handler) {
          this._listeners[event] = this._listeners[event] || [];
          this._listeners[event].push(handler);
        };
      }

      if (!window.SuperAppBridge.removeEventListener) {
        window.SuperAppBridge.removeEventListener = function(event, handler) {
          if (!this._listeners[event]) return;
          this._listeners[event] = this._listeners[event].filter(function(h) { return h !== handler; });
        };
      }

      // Universal MiniApp Promise Invocation Channel
      var bridgeCallSeq = 1;
      function bridgeInvoke(action, payload) {
        payload = payload || {};
        return new Promise(function(resolve, reject) {
          var reqId = 'req_' + Date.now() + '_' + (bridgeCallSeq++);
          var timer = setTimeout(function() {
            if (window.SuperAppBridge && window.SuperAppBridge._callbacks && window.SuperAppBridge._callbacks[reqId]) {
              delete window.SuperAppBridge._callbacks[reqId];
            }
            reject({ code: 'TIMEOUT', message: 'Bridge request "' + action + '" timed out after 8000ms' });
          }, 8000);

          if (!window.SuperAppBridge._callbacks) window.SuperAppBridge._callbacks = {};
          window.SuperAppBridge._callbacks[reqId] = function(res) {
            clearTimeout(timer);
            if (res && res.success) {
              resolve(res.data);
            } else {
              reject((res && res.error) || { code: 'ERROR', message: 'Bridge invocation failed' });
            }
          };

          var req = {
            id: reqId,
            action: action,
            payload: payload,
            origin: (typeof window !== 'undefined' && window.location) ? window.location.origin : 'miniapp://runtime',
            timestamp: Date.now()
          };

          if (window.FlutterBridge && window.FlutterBridge.postMessage) {
            window.FlutterBridge.postMessage(JSON.stringify(req));
          } else {
            clearTimeout(timer);
            delete window.SuperAppBridge._callbacks[reqId];
            reject({ code: 'BRIDGE_UNAVAILABLE', message: 'FlutterBridge platform channel is not connected' });
          }
        });
      }

      var defaultBridgeApi = {
        invoke: bridgeInvoke,
        // UI & App View (Zalo-compatible)
        configAppView: function(options) { return bridgeInvoke('ui.configAppView', options || {}); },
        setNavigationBarTitle: function(options) {
          var p = typeof options === 'string' ? { title: options } : (options || {});
          return bridgeInvoke('ui.setNavigationBarTitle', p);
        },
        setTitle: function(title) { return bridgeInvoke('ui.setNavigationBarTitle', { title: title }); },
        setNavigationBarColor: function(options) {
          var p = typeof options === 'string' ? { color: options } : (options || {});
          return bridgeInvoke('ui.setNavigationBarColor', p);
        },
        setStatusBarColor: function(color) { return bridgeInvoke('ui.setStatusBarColor', { color: color }); },
        setStatusBarStyle: function(style) { return bridgeInvoke('ui.setStatusBarStyle', { style: style }); },
        showToast: function(options) {
          var p = typeof options === 'string' ? { message: options } : (options || {});
          return bridgeInvoke('ui.showToast', p);
        },
        showAlert: function(options) { return bridgeInvoke('ui.showAlert', options || {}); },
        showConfirm: function(options) { return bridgeInvoke('ui.showConfirm', options || {}); },
        showMiniappMenu: function() { return bridgeInvoke('ui.showMiniappMenu', {}); },

        // Device & Screen
        keepScreen: function(options) {
          var p = typeof options === 'boolean' ? { keepScreenOn: options } : (options || { keepScreenOn: true });
          return bridgeInvoke('device.keepScreen', p);
        },
        setBrightness: function(brightness) { return bridgeInvoke('device.setBrightness', { brightness: brightness }); },
        vibrate: function(style) { return bridgeInvoke('device.vibrate', { style: style || 'medium' }); },
        copyToClipboard: function(text) { return bridgeInvoke('device.copyToClipboard', { text: text }); },
        getSystemInfo: function() { return bridgeInvoke('device.getSystemInfo', {}); },
        getNetworkInfo: function() { return bridgeInvoke('device.getNetworkInfo', {}); },
        getBatteryInfo: function() { return bridgeInvoke('device.getBatteryInfo', {}); },
        getLocation: function(options) { return bridgeInvoke('device.getLocation', options || {}); },

        // Notification & System
        requestSendNotification: function(options) { return bridgeInvoke('ui.requestSendNotification', options || {}); },
        getAppInfo: function() { return bridgeInvoke('app.getAppInfo', {}); },
        getSuperAppSettings: function() { return bridgeInvoke('app.getSuperAppSettings', {}); },
        getDeviceLanguage: function() { return bridgeInvoke('device.getDeviceLanguage', {}); },

        // Navigation
        minimizeApp: function() { return bridgeInvoke('navigation.minimizeApp', {}); },
        closeApp: function() { return bridgeInvoke('navigation.closeApp', {}); },

        // Media
        scanQr: function(options) { return bridgeInvoke('media.scanQRCode', options || {}); },
        scanQRCode: function(options) { return bridgeInvoke('media.scanQRCode', options || {}); },
        chooseImage: function(options) { return bridgeInvoke('media.chooseImage', options || {}); },
        getPhoto: function(options) { return bridgeInvoke('media.getPhoto', options || {}); },
        pickImages: function(options) { return bridgeInvoke('media.pickImages', options || {}); },
        saveImageToGallery: function(uri) { return bridgeInvoke('media.saveImageToGallery', { uri: uri }); },

        // Events
        on: function(event, handler) { window.SuperAppBridge.addEventListener(event, handler); },
        off: function(event, handler) { window.SuperAppBridge.removeEventListener(event, handler); }
      };

      // Wrap in Proxy if supported to transparently forward any bridge.anyAction(payload)
      var universalBridge = (typeof Proxy !== 'undefined') ? new Proxy(defaultBridgeApi, {
        get: function(target, prop) {
          if (prop in target) return target[prop];
          return function(payload) {
            return bridgeInvoke(prop, payload || {});
          };
        }
      }) : defaultBridgeApi;

      window.bridge = window.bridge || universalBridge;
      window.superApp = window.superApp || universalBridge;
    })();
  ''';
}
