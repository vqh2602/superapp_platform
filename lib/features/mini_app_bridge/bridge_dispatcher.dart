import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:webview_all/webview_all.dart';
import '../../../core/bridge_protocol/bridge_request.dart';
import '../../../core/bridge_protocol/bridge_response.dart';
import '../../../core/errors/bridge_error.dart';
import '../debug_center/data/debug_log_repository.dart';
import '../debug_center/domain/bridge_log_entry.dart';
import '../mini_app_catalog/domain/mini_app_manifest.dart';
import '../native_actions/application/native_action_dispatcher.dart';
import '../native_actions/domain/action_context.dart';

class BridgeDispatcher {
  final NativeActionDispatcher actionDispatcher;
  final DebugLogRepository debugLogRepo;
  final WebViewController controller;
  final MiniAppManifest manifest;

  BridgeDispatcher({
    required this.actionDispatcher,
    required this.debugLogRepo,
    required this.controller,
    required this.manifest,
  });

  Future<void> handleMessage(String rawJson, BuildContext buildContext) async {
    final stopwatch = Stopwatch()..start();
    String requestId = 'unknown';
    String actionName = 'unknown';
    Map<String, dynamic> payload = {};

    try {
      final parsed = jsonDecode(rawJson) as Map<String, dynamic>;
      final request = BridgeRequest.fromJson(parsed, defaultAppId: manifest.id);
      requestId = request.id;
      actionName = request.action;
      payload = request.payload;

      final context = ActionContext(
        buildContext: buildContext,
        appId: manifest.id,
        origin: request.origin,
        manifest: manifest,
      );

      final resultData = await actionDispatcher.dispatch(actionName, payload, context);
      stopwatch.stop();

      final response = BridgeResponse.ok(
        requestId,
        resultData,
        stopwatch.elapsedMilliseconds,
      );

      // Record log
      debugLogRepo.addLog(BridgeLogEntry(
        id: requestId,
        action: actionName,
        params: BridgeLogEntry.sanitize(payload),
        success: true,
        responseData: resultData,
        executionTimeMs: stopwatch.elapsedMilliseconds,
        timestamp: DateTime.now(),
        appId: manifest.id,
      ));

      await _sendResponse(response);
    } on BridgeError catch (err) {
      stopwatch.stop();
      final response = BridgeResponse.failure(
        requestId,
        err,
        stopwatch.elapsedMilliseconds,
      );

      debugLogRepo.addLog(BridgeLogEntry(
        id: requestId,
        action: actionName,
        params: BridgeLogEntry.sanitize(payload),
        success: false,
        errorMessage: err.message,
        executionTimeMs: stopwatch.elapsedMilliseconds,
        timestamp: DateTime.now(),
        appId: manifest.id,
      ));

      await _sendResponse(response);
    } catch (e) {
      stopwatch.stop();
      final bridgeErr = BridgeError.internal(e.toString());
      final response = BridgeResponse.failure(
        requestId,
        bridgeErr,
        stopwatch.elapsedMilliseconds,
      );

      debugLogRepo.addLog(BridgeLogEntry(
        id: requestId,
        action: actionName,
        params: BridgeLogEntry.sanitize(payload),
        success: false,
        errorMessage: e.toString(),
        executionTimeMs: stopwatch.elapsedMilliseconds,
        timestamp: DateTime.now(),
        appId: manifest.id,
      ));

      await _sendResponse(response);
    }
  }

  Future<void> _sendResponse(BridgeResponse response) async {
    final jsonStr = jsonEncode(response.toJson());
    final script = '''
      try {
        if (window.SuperAppBridge && typeof window.SuperAppBridge.dispatchResponse === 'function') {
          window.SuperAppBridge.dispatchResponse($jsonStr);
        }
      } catch (err) {
        console.error('[Bridge Dispatcher] Failed to dispatch response for "${response.id}":', err.message || err, err.stack || '');
      }
    ''';
    try {
      await controller.runJavaScript(script);
    } catch (_) {
      // WebView unmounted
    }
  }
}
