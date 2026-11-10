import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';
import 'package:webview_all/webview_all.dart';
import '../../../core/bridge_protocol/bridge_request.dart';
import '../../../core/bridge_protocol/bridge_response.dart';
import '../../../core/config/endpoint_config.dart';
import '../../../core/errors/bridge_error.dart';
import '../../../core/security/mini_app_security_policy.dart';
import '../../../core/security/runtime_security_context.dart';
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
  final String? userId;
  final String runtimeSessionId;
  RuntimeSecurityContext? securityContext;
  bool _isDisposed = false;
  final Set<String> _inFlightRequestIds = {};

  BridgeDispatcher({
    required this.actionDispatcher,
    required this.debugLogRepo,
    required this.controller,
    required this.manifest,
    this.uiDelegate,
    String? backendBaseUrl,
    this.userId,
    String? runtimeSessionId,
    this.securityContext,
  })  : backendBaseUrl = backendBaseUrl ?? EndpointConfig.alwaysdataEndpoint,
        runtimeSessionId = runtimeSessionId ?? const Uuid().v4();

  /// Cho biết Dispatcher của phiên làm việc này đã bị hủy hay chưa.
  bool get isDisposed => _isDisposed;

  /// Danh sách các RPC request ID đang được thực thi trong phiên này.
  Set<String> get inFlightRequestIds => Set.unmodifiable(_inFlightRequestIds);

  /// Hủy Dispatcher, ngắt gửi response và hủy các RPC đang xử lý dở.
  void dispose() {
    _isDisposed = true;
    _inFlightRequestIds.clear();
  }

  Future<void> handleMessage(String rawJson, BuildContext? buildContext) async {
    if (_isDisposed) {
      debugPrint('[BridgeDispatcher] Bỏ qua request vì phiên $runtimeSessionId đã bị hủy');
      return;
    }

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

      if (_isDisposed) {
        debugPrint('[BridgeDispatcher] Bỏ qua request "$actionName" ($requestId) vì phiên đã bị hủy');
        return;
      }

      _inFlightRequestIds.add(requestId);

      // 1. Xác thực nguồn gốc (Origin Validation): Đảm bảo trang web đang gọi Bridge
      // phải nằm trong phạm vi domain và path được cấp phép của Mini App này.
      String? currentUrl;
      try {
        currentUrl = await controller.currentUrl();
      } catch (_) {
        // Fallback khi chạy trên môi trường test không có native webview
      }

      if (_isDisposed || !_inFlightRequestIds.contains(requestId)) return;
      if (buildContext != null && !buildContext.mounted) return;

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

      // 2. Khởi tạo / Đồng bộ RuntimeSecurityContext do Flutter Host quản lý
      final activeSecContext = (securityContext ??
          RuntimeSecurityContext.create(
            manifest: manifest,
            userId: userId,
            backendBaseUrl: backendBaseUrl,
            currentUrl: currentUrl,
            customSessionId: runtimeSessionId,
          )).copyWith(
        approvedOrigin: (currentUrl != null && currentUrl.isNotEmpty)
            ? currentUrl
            : null,
        userId: userId,
      );
      securityContext = activeSecContext;

      // 3. Thực thi kiểm tra bảo mật nghiêm ngặt qua RuntimeSecurityContext
      // Không tin cậy appId, origin, permissions hoặc sessionId do Mini App gửi.
      activeSecContext.validateBridgeCall(
        requestAppId: parsed['appId']?.toString(),
        requestOrigin: parsed['origin']?.toString(),
        currentWebViewUrl: currentUrl,
        requestSessionId: parsed['sessionId']?.toString() ?? payload['sessionId']?.toString(),
      );

      // 4. Tạo ActionContext với các giá trị đã được Host xác thực
      // origin lấy từ activeSecContext.approvedOrigin (WebView thực tế), tuyệt đối KHÔNG lấy request.origin từ JS
      final context = ActionContext(
        buildContext: buildContext,
        appId: activeSecContext.appId,
        origin: activeSecContext.approvedOrigin,
        manifest: manifest,
        uiDelegate: uiDelegate,
        securityContext: activeSecContext,
        runtimeSessionId: runtimeSessionId,
        isSessionActive: () => !_isDisposed && _inFlightRequestIds.contains(requestId),
      );

      final resultData = await actionDispatcher.dispatch(actionName, payload, context);
      stopwatch.stop();

      // Nếu phiên đã bị hủy trong lúc actionDispatcher đang xử lý bất đồng bộ, ngắt ngay lập tức
      if (_isDisposed || !_inFlightRequestIds.contains(requestId)) {
        debugPrint('[BridgeDispatcher] Bỏ qua gửi response cho "$actionName" vì phiên $runtimeSessionId đã bị hủy trong quá trình xử lý');
        return;
      }

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
      if (_isDisposed || (requestId != 'unknown' && !_inFlightRequestIds.contains(requestId))) {
        debugPrint('[BridgeDispatcher] Bỏ qua gửi response lỗi cho "$actionName" vì phiên $runtimeSessionId đã bị hủy trong quá trình xử lý');
        return;
      }
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
      if (_isDisposed || (requestId != 'unknown' && !_inFlightRequestIds.contains(requestId))) {
        debugPrint('[BridgeDispatcher] Bỏ qua gửi response lỗi cho "$actionName" vì phiên $runtimeSessionId đã bị hủy trong quá trình xử lý');
        return;
      }
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
    } finally {
      _inFlightRequestIds.remove(requestId);
    }
  }

  Future<void> _sendResponse(BridgeResponse response) async {
    if (_isDisposed) return;
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
