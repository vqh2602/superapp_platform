// Bộ điều phối yêu cầu Bridge (Bridge Dispatcher).
//
// Tiếp nhận chuỗi JSON từ kênh JavaScript Channel, kiểm tra bảo mật (kích thước payload,
// số lượng RPC đồng thời, rate limit, xác thực origin), nạp ngữ cảnh bảo mật RuntimeSecurityContext,
// chuyển tiếp tới NativeActionDispatcher và gửi kết quả BridgeResponse ngược vào WebView.
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
import 'bridge_load_config.dart';

/// Lớp điều phối các yêu cầu Bridge gửi từ Mini App WebView
class BridgeDispatcher {
  final NativeActionDispatcher actionDispatcher;
  final DebugLogRepository debugLogRepo;
  final WebViewController controller;
  final MiniAppManifest manifest;
  final MiniAppUiDelegate? uiDelegate;
  final String backendBaseUrl;
  final String? userId;
  final String? Function()? currentUserIdGetter;
  final String runtimeSessionId;
  final BridgeLoadConfig loadConfig;
  final BridgeRateLimiter _rateLimiter;
  RuntimeSecurityContext? securityContext;
  bool _isDisposed = false;
  int _activeCallCount = 0;
  final Set<String> _inFlightRequestIds = {};

  static final RegExp _idRegex = RegExp(r'"id"\s*:\s*"([^"]+)"');

  BridgeDispatcher({
    required this.actionDispatcher,
    required this.debugLogRepo,
    required this.controller,
    required this.manifest,
    this.uiDelegate,
    String? backendBaseUrl,
    this.userId,
    this.currentUserIdGetter,
    String? runtimeSessionId,
    this.securityContext,
    BridgeLoadConfig? loadConfig,
    BridgeRateLimiter? rateLimiter,
  })  : backendBaseUrl = backendBaseUrl ?? EndpointConfig.alwaysdataEndpoint,
        runtimeSessionId = runtimeSessionId ?? const Uuid().v4(),
        loadConfig = loadConfig ?? BridgeLoadConfig.defaultConfig,
        _rateLimiter = rateLimiter ??
            BridgeRateLimiter(
              maxRequestsPerWindow:
                  (loadConfig ?? BridgeLoadConfig.defaultConfig).maxRequestsPerWindow,
              windowDuration:
                  (loadConfig ?? BridgeLoadConfig.defaultConfig).rateLimitWindow,
            );

  /// Cho biết Dispatcher của phiên làm việc này đã bị hủy hay chưa.
  bool get isDisposed => _isDisposed;

  /// Số lượng RPC đang thực thi đồng thời trong phiên này.
  int get activeCallCount => _activeCallCount;

  /// Danh sách các RPC request ID đang được thực thi trong phiên này.
  Set<String> get inFlightRequestIds => Set.unmodifiable(_inFlightRequestIds);

  /// Bộ giới hạn tần suất gọi Bridge.
  BridgeRateLimiter get rateLimiter => _rateLimiter;

  /// Hủy Dispatcher, ngắt gửi response và hủy các RPC đang xử lý dở.
  void dispose() {
    _isDisposed = true;
    _inFlightRequestIds.clear();
    _activeCallCount = 0;
    _rateLimiter.reset();
  }

  String? _extractRequestId(String raw) {
    if (raw.length <= 1024) {
      final match = _idRegex.firstMatch(raw);
      return match?.group(1);
    }
    final match = _idRegex.firstMatch(raw.substring(0, 1024));
    return match?.group(1);
  }

  Future<void> _rejectFast(
    String requestId,
    String actionName,
    BridgeError error,
    Stopwatch stopwatch,
  ) async {
    stopwatch.stop();
    debugLogRepo.addLog(BridgeLogEntry(
      id: requestId,
      action: actionName,
      params: const {},
      success: false,
      errorMessage: error.message,
      executionTimeMs: stopwatch.elapsedMilliseconds,
      timestamp: DateTime.now(),
      appId: manifest.id,
    ));

    if (requestId != 'unknown' && !_isDisposed) {
      final response = BridgeResponse.failure(
        requestId,
        error,
        stopwatch.elapsedMilliseconds,
        actionName,
      );
      await _sendResponse(response);
    }
  }

  /// Xử lý thông điệp chuỗi nhận được từ JavaScript Channel của WebView.
  ///
  /// Thực hiện tuần tự các bước:
  /// 1. Kiểm tra giới hạn kích thước chuỗi JSON đầu vào
  /// 2. Kiểm tra số lượng request đồng thời trong phiên
  /// 3. Kiểm tra tần suất gọi (Rate Limiting)
  /// 4. Xác thực nguồn gốc gọi Bridge (Origin Validation)
  /// 5. Thiết lập RuntimeSecurityContext và xác thực token/session
  /// 6. Điều phối hành động qua NativeActionDispatcher
  /// 7. Ghi log kiểm toán và phản hồi kết quả về WebView
  Future<void> handleMessage(String rawJson, BuildContext? buildContext) async {
    if (_isDisposed) {
      debugPrint('[BridgeDispatcher] Bỏ qua request vì phiên $runtimeSessionId đã bị hủy');
      return;
    }

    final stopwatch = Stopwatch()..start();

    // 1. Message Size Limit check (trước khi parse JSON để bảo vệ UI isolate)
    if (rawJson.length > loadConfig.maxMessageSizeBytes) {
      final reqId = _extractRequestId(rawJson) ?? 'unknown';
      final err = BridgeError.payloadTooLarge(
        'Kích thước tin nhắn (${rawJson.length} bytes) vượt quá giới hạn cho phép (${loadConfig.maxMessageSizeBytes} bytes)',
      );
      debugPrint('[BridgeDispatcher] Từ chối request vì payload quá lớn: ${rawJson.length} bytes');
      await _rejectFast(reqId, 'unknown', err, stopwatch);
      return;
    }

    // 2. Concurrency Limit check (theo Mini App session sử dụng bộ đếm active calls độc lập)
    if (_activeCallCount >= loadConfig.maxConcurrentRequests) {
      final reqId = _extractRequestId(rawJson) ?? 'unknown';
      final err = BridgeError.rateLimitExceeded(
        'Số lượng RPC đang thực thi vượt quá giới hạn (tối đa ${loadConfig.maxConcurrentRequests} RPC đồng thời)',
      );
      debugPrint('[BridgeDispatcher] Từ chối request vì vượt giới hạn RPC đồng thời ($_activeCallCount/${loadConfig.maxConcurrentRequests})');
      await _rejectFast(reqId, 'unknown', err, stopwatch);
      return;
    }

    // 3. Rate Limit check (tần suất gọi theo Mini App)
    if (!_rateLimiter.allowRequest()) {
      final reqId = _extractRequestId(rawJson) ?? 'unknown';
      final err = BridgeError.rateLimitExceeded(
        'Tần suất gọi Bridge vượt quá giới hạn cho phép (${loadConfig.maxRequestsPerWindow} req / ${loadConfig.rateLimitWindow.inSeconds}s)',
      );
      debugPrint('[BridgeDispatcher] Từ chối request vì vượt tần suất gọi');
      await _rejectFast(reqId, 'unknown', err, stopwatch);
      return;
    }

    _activeCallCount++;
    String requestId = 'unknown';
    String actionName = 'unknown';
    Map<String, dynamic> payload = {};
    bool addedToInFlight = false;

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

      // Kiểm tra trùng lặp request ID đang thực thi (Duplicate In-Flight Request ID)
      if (_inFlightRequestIds.contains(requestId)) {
        final err = BridgeError.invalidParams(
          'Request ID "$requestId" đang được thực thi. Không được phép gửi các RPC trùng lặp ID đồng thời.',
        );
        debugPrint('[BridgeDispatcher] Từ chối request vì trùng lặp request ID đang chạy: $requestId');
        await _rejectFast(requestId, actionName, err, stopwatch);
        return;
      }

      // Xác nhận phiên hiện tại vẫn thuộc đúng userId đã dùng để tạo ngữ cảnh
      if (currentUserIdGetter != null) {
        final currentActiveUserId = currentUserIdGetter!();
        if (currentActiveUserId != userId) {
          debugPrint('[BridgeDispatcher] Hủy phiên $runtimeSessionId vì userId thay đổi: phiên=$userId, hiện tại=$currentActiveUserId');
          final err = BridgeError.authRequired(
            'Phiên làm việc Mini App đã hết hạn hoặc tài khoản người dùng đã thay đổi.',
          );
          await _rejectFast(requestId, actionName, err, stopwatch);
          dispose();
          return;
        }
      }

      _inFlightRequestIds.add(requestId);
      addedToInFlight = true;

      // 4. Xác thực nguồn gốc (Origin Validation): Đảm bảo trang web đang gọi Bridge
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

      // 5. Khởi tạo / Đồng bộ RuntimeSecurityContext do Flutter Host quản lý
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

      // 6. Thực thi kiểm tra bảo mật nghiêm ngặt qua RuntimeSecurityContext
      activeSecContext.validateBridgeCall(
        requestAppId: parsed['appId']?.toString(),
        requestOrigin: parsed['origin']?.toString(),
        currentWebViewUrl: currentUrl,
        requestSessionId: parsed['sessionId']?.toString() ?? payload['sessionId']?.toString(),
      );

      // 7. Tạo ActionContext với các giá trị đã được Host xác thực
      final context = ActionContext(
        buildContext: buildContext,
        appId: activeSecContext.appId,
        origin: activeSecContext.approvedOrigin,
        manifest: manifest,
        uiDelegate: uiDelegate,
        securityContext: activeSecContext,
        runtimeSessionId: runtimeSessionId,
        userInteractionQueue: actionDispatcher.userInteractionQueue,
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
      if (addedToInFlight) {
        _inFlightRequestIds.remove(requestId);
      }
      _activeCallCount = (_activeCallCount > 0) ? _activeCallCount - 1 : 0;
    }
  }

  /// Gửi kết quả BridgeResponse vào WebView thông qua hàm JavaScript `window.SuperAppBridge.dispatchResponse`.
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
