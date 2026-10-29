import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:superapp_platform/features/mini_app_runtime/domain/web_log_entry.dart';
import 'package:superapp_platform/features/mini_app_bridge/bridge_channel.dart';

void main() {
  group('WebView Debug Inspector Tests', () {
    test('WebLogEntry parses console info message correctly', () {
      final json = {
        'id': 'log_123',
        'type': 'console',
        'level': 'info',
        'message': '[React] App mounted successfully',
        'timeMs': 1700000000000,
      };

      final entry = WebLogEntry.fromJson(json);

      expect(entry.id, 'log_123');
      expect(entry.type, 'console');
      expect(entry.level, 'info');
      expect(entry.message, '[React] App mounted successfully');
      expect(entry.isError, false);
      expect(entry.isWarning, false);
    });

    test('WebLogEntry identifies error and unhandledrejection correctly', () {
      final errorJson = {
        'id': 'err_456',
        'type': 'error',
        'level': 'error',
        'message': 'Uncaught TypeError: Cannot read properties of null',
        'stack': 'TypeError: Cannot read properties of null\n    at mount (main.tsx:5:10)',
      };

      final errorEntry = WebLogEntry.fromJson(errorJson);
      expect(errorEntry.isError, true);
      expect(errorEntry.stack, contains('mount (main.tsx:5:10)'));

      final rejectionJson = {
        'id': 'rej_789',
        'type': 'unhandledrejection',
        'level': 'error',
        'message': '[Unhandled Rejection] NetworkError',
      };

      final rejectionEntry = WebLogEntry.fromJson(rejectionJson);
      expect(rejectionEntry.isError, true);
    });

    test('BridgeChannel exposes webDebugChannelName and polyfill script', () {
      expect(BridgeChannel.webDebugChannelName, '__SuperAppWebDebug__');
      expect(BridgeChannel.webDebugPolyfillScript, contains('window.__SuperAppWebDebug__'));
      expect(BridgeChannel.webDebugPolyfillScript, contains('unhandledrejection'));
      expect(BridgeChannel.webDebugPolyfillScript, contains('addEventListener(\'error\''));
    });

    test('Mini App built HTML integrity: schema_runtime and sdk_playground', () {
      final paths = [
        'mini_apps/schema_runtime/dist/index.html',
        'mini_apps/sdk_playground/dist/index.html',
      ];

      for (final p in paths) {
        final file = File(p);
        expect(file.existsSync(), isTrue, reason: 'File $p must exist');
        final content = file.readAsStringSync();

        // 1. Must contain #root div exactly once
        final rootDivCount = RegExp(r'<div id="root">\s*<\/div>').allMatches(content).length;
        expect(rootDivCount, 1, reason: '$p must contain exactly 1 <div id="root"></div>');

        // 2. Must not contain corrupted <div id="root"></div> inside JS code
        expect(content.contains('<div id="root"></div>/'), isFalse,
            reason: '$p must not have corrupted div inside JS');

        // 3. React $$typeof must be preserved (not converted to single $typeof)
        expect(RegExp(r'[^\$]\$typeof').hasMatch(content), isFalse,
            reason: '$p must not have corrupted \$typeof in React code');

        // 4. Must not have module script that could fail on WKWebView local file:// protocol
        expect(content.contains('type="module"'), isFalse,
            reason: '$p script must be inline classic script for file:// WKWebView support');

        // 5. Must have early error listener in head
        expect(content.contains('window.__WEBVIEW_LOGS__'), isTrue,
            reason: '$p must contain early error listener for inspector diagnostics');
      }
    });
  });
}
