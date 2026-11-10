import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:webview_all/webview_all.dart';
import '../../../core/bridge_protocol/bridge_request.dart';
import '../../../core/bridge_protocol/bridge_response.dart';
import '../../../core/config/endpoint_config.dart';
import '../../../core/errors/bridge_error.dart';
import '../../../core/security/mini_app_security_policy.dart';
import '../debug_center/data/debug_log_repository.dart';
import '../debug_center/domain/bridge_log_entry.dart';
import '../mini_app_catalog/domain/mini_app_manifest.dart';
import '../native_actions/application/native_action_dispatcher.dart';
import '../native_actions/domain/action_context.dart';
import '../native_actions/domain/mini_app_ui_delegate.dart';

class BridgeDispatcher {
  final NativeActionDispatcher actionDispatcher;
  final DebugLogRepository debugLogRepo;
  final WebViewController controller;
  final MiniAppManifest manifest;
  final MiniAppUiDelegate? uiDelegate;
  final String backendBaseUrl;

  BridgeDispatcher({
    required this.actionDispatcher,
    required this.debugLogRepo,
    required this.controller,
    required this.manifest,
    this.uiDelegate,
    String? backendBaseUrl,
  }) : backendBaseUrl = backendBaseUrl ?? EndpointConfig.alwaysdataEndpoint;

  Future<void> handleMessage(String rawJson, BuildContext? buildContext) async {
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

      // 1. Kiểm tra tính toàn vẹn danh tính Mini App
      if (parsed['appId'] != null && parsed['appId'] != manifest.id) {
        throw BridgeError.permissionDenied(
          'Định danh Mini App không hợp lệ (${parsed['appId']} != ${manifest.id})',
        );
      }

      // 2. Xác thực nguồn gốc (Origin Validation): Đảm bảo trang web đang gọi Bridge
      // phải nằm trong phạm vi domain và path được cấp phép của Mini App này.
      String? currentUrl;
      try {
        currentUrl = await controller.currentUrl();
      } catch (_) {
        // Fallback khi chạy trên môi trường test không có native webview
      }

      final isOriginValid = MiniAppSecurityPolicy.validateCallerOrigin(
        currentUrl: currentUrl,
        manifest: manifest,
        backendBaseUrl: backendBaseUrl,
      );

      if (!isOriginValid) {
        throw BridgeError.permissionDenied(
          'Nguồn gọi Bridge ($currentUrl) không thuộc phạm vi Mini App hợp lệ của "${manifest.id}"',
        );
      }

      final context = ActionContext(
        buildContext: buildContext,
        appId: manifest.id,
        origin: currentUrl ?? request.origin,
        manifest: manifest,
        uiDelegate: uiDelegate,
      );

      final resultData = await actionDispatcher.dispatch(actionName, payload, context);
      stopwatch.stop();

      final response = BridgeResponse.ok(
        requestId,
        resultData,
        stopwatch.elapsedMilliseconds,
        actionName,
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
        actionName,
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
        actionName,
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
