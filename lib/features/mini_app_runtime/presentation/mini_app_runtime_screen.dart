// Màn hình môi trường thực thi Mini App (Mini App Runtime Host Screen).
//
// Chịu trách nhiệm khởi tạo WebView, xác thực giấy phép thực thi với Backend,
// thiết lập bảo mật cô lập RuntimeSecurityContext, đăng ký kênh Bridge Channel,
// quản lý thanh trạng thái/tiêu đề động (Dynamic UI Container) và giao tiếp hai chiều với Mini App.
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_all/webview_all.dart';
import '../../authentication/presentation/controllers/auth_controller.dart';
import '../../debug_center/data/debug_log_repository.dart';
import '../../mini_app_catalog/data/mini_app_repository.dart';
import '../../mini_app_catalog/domain/mini_app_manifest.dart';
import '../../mini_app_bridge/bridge_channel.dart';
import '../../mini_app_bridge/bridge_dispatcher.dart';
import '../../mini_app_bridge/bridge_event_emitter.dart';
import '../../native_actions/application/native_action_dispatcher.dart';
import '../../user_profile/data/user_repository_impl.dart';
import '../../device/data/device_adapter_impl.dart';
import '../../permissions/data/permission_repository_impl.dart';
import '../../storage/data/secure_storage_repository_impl.dart';
import '../../native_actions/domain/mini_app_ui_delegate.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../domain/mini_app_runtime_session.dart';
import '../domain/web_log_entry.dart';
import 'widgets/mini_app_action_bottom_sheet.dart';
import 'widgets/webview_debug_bottom_sheet.dart';
import '../../../../core/animations/app_motion.dart';
import '../../../../core/config/debug_mode_provider.dart';
import '../../../../core/config/endpoint_config.dart';
import '../../../../core/security/mini_app_security_policy.dart';
import '../../../../core/security/runtime_security_context.dart';

/// Widget màn hình chứa môi trường thực thi WebView của Mini App
class MiniAppRuntimeScreen extends ConsumerStatefulWidget {
  /// Mã định danh Mini App cần khởi chạy
  final String appId;

  const MiniAppRuntimeScreen({super.key, required this.appId});

  @override
  ConsumerState<MiniAppRuntimeScreen> createState() =>
      _MiniAppRuntimeScreenState();
}

class _MiniAppRuntimeScreenState extends ConsumerState<MiniAppRuntimeScreen>
    with WidgetsBindingObserver
    implements MiniAppUiDelegate {
  late String _currentAppId;
  MiniAppRuntimeSession? _currentSession;
  WebViewController? _webViewController;
  BridgeEventEmitter? _eventEmitter;
  bool _isLoading = true;
  bool _showLoadingOverlay = true;
  double _displayedProgress = 0.0;
  double _targetProgress = 15.0;
  double _stageCeiling = 25.0;
  String _statusMessage = 'Đang kiểm tra Mini App...';
  final ValueNotifier<double> _progressNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<String> _statusNotifier =
      ValueNotifier<String>('Đang kiểm tra Mini App...');
  bool _isFinished = false;
  String? _loadError;
  final List<WebLogEntry> _webLogs = [];
  final ValueNotifier<int> _webLogRevision = ValueNotifier(0);
  bool _hasBlankScreenWarning = false;

  // Dynamic UI & Container state from configAppView / setNavigationBarTitle / setNavigationBarColor
  String? _overrideTitle;
  String? _titleAlignment;
  Color? _overrideHeaderColor;
  String? _overrideTextColor; // 'white' | 'black'
  Color? _overrideStatusBarColor;
  String? _statusBarStyle; // 'transparent' | 'hidden' | 'light' | 'dark'
  bool _isActionBarHidden = false;
  bool _isStatusBarHidden = false;
  bool _hideBottomNav = false;
  bool _hasPadding = true;
  bool _hasPaddingTop = true;
  bool _hasPaddingBottom = true;
  Color? _bottomNavColor;
  bool _isKeepScreenOn = false;

  @visibleForTesting
  MiniAppRuntimeSession? get currentSession => _currentSession;

  @visibleForTesting
  String get runtimeSessionId => _currentSession?.sessionId ?? '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentAppId = widget.appId;
    _startNewSession(_currentAppId);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _webLogRevision.dispose();
    _progressNotifier.dispose();
    _statusNotifier.dispose();
    _currentSession?.dispose();
    _currentSession = null;
    if (_isKeepScreenOn) {
      try {
        WakelockPlus.disable();
      } catch (_) {}
    }
    try {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    } catch (_) {}
    _eventEmitter?.emit('miniapp.close');
    super.dispose();
  }

  @override
  void setTitle(String title, {String? align}) {
    if (mounted) {
      setState(() {
        _overrideTitle = title;
        if (align != null) _titleAlignment = align;
      });
    }
  }

  @override
  void setNavigationBarColor({
    required Color color,
    String? textColor,
    Color? statusBarColor,
  }) {
    if (mounted) {
      setState(() {
        _overrideHeaderColor = color;
        if (textColor != null) _overrideTextColor = textColor;
        if (statusBarColor != null) _overrideStatusBarColor = statusBarColor;
      });
    }
  }

  @override
  void configAppView({
    Color? headerColor,
    String? headerTitle,
    String? textColor,
    String? statusBar,
    Color? statusBarColor,
    bool? actionBarHidden,
    bool? hideAndroidBottomNavigationBar,
    bool? hasPadding,
    bool? hasPaddingTop,
    bool? hasPaddingBottom,
    Color? bottomNavColor,
    String? titleAlign,
  }) {
    if (mounted) {
      setState(() {
        if (headerColor != null) _overrideHeaderColor = headerColor;
        if (headerTitle != null) _overrideTitle = headerTitle;
        if (textColor != null) _overrideTextColor = textColor;
        if (titleAlign != null) _titleAlignment = titleAlign;
        if (statusBar != null) {
          _statusBarStyle = statusBar;
          _isStatusBarHidden = statusBar == 'hidden';
        }
        if (statusBarColor != null) _overrideStatusBarColor = statusBarColor;
        if (actionBarHidden != null) _isActionBarHidden = actionBarHidden;
        if (hideAndroidBottomNavigationBar != null) {
          _hideBottomNav = hideAndroidBottomNavigationBar;
        }
        if (hasPadding != null) {
          _hasPadding = hasPadding;
          _hasPaddingTop = hasPadding;
          _hasPaddingBottom = hasPadding;
        }
        if (hasPaddingTop != null) _hasPaddingTop = hasPaddingTop;
        if (hasPaddingBottom != null) _hasPaddingBottom = hasPaddingBottom;
        if (bottomNavColor != null) _bottomNavColor = bottomNavColor;
      });
    }
  }

  @override
  void keepScreen({required bool keepScreenOn}) {
    _isKeepScreenOn = keepScreenOn;
  }

  @override
  void minimizeApp() {
    _eventEmitter?.emit('miniapp.hide');
    _eventEmitter?.emit('miniapp.minimize', {'appId': _currentAppId});
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_eventEmitter == null) return;
    if (state == AppLifecycleState.resumed) {
      _eventEmitter!.emit('miniapp.resume');
      _eventEmitter!.emit('miniapp.show');
    } else if (state == AppLifecycleState.paused) {
      _eventEmitter!.emit('miniapp.hide');
    }
  }

  Future<void> _safeRunScript(
    WebViewController? controller,
    String script,
  ) async {
    if (controller == null) return;
    try {
      await controller.runJavaScript(script);
    } catch (e) {
      _recordWebLog(
        WebLogEntry(
          id: 'eval_${DateTime.now().microsecondsSinceEpoch}',
          type: 'eval',
          level: 'error',
          message: 'Native script injection failed: $e',
        ),
      );
    }
  }

  void _recordWebLog(WebLogEntry entry) {
    if (!mounted) return;
    _webLogs.insert(0, entry);
    if (_webLogs.length > 500) _webLogs.removeLast();
    _webLogRevision.value++;
  }

  void _failStartup(MiniAppRuntimeSession session, String message) {
    if (!mounted || session.isDisposed || _currentSession != session) return;
    session.dispose();
    _recordWebLog(
      WebLogEntry(
        id: 'startup_${DateTime.now().microsecondsSinceEpoch}',
        type: 'error',
        level: 'error',
        message: message,
      ),
    );
    setState(() {
      _isLoading = false;
      _showLoadingOverlay = false;
      _loadError = message;
    });
  }

  void _startLoadDeadline(MiniAppRuntimeSession session) {
    session.loadTimeoutTimer?.cancel();
    session.loadTimeoutTimer = Timer(const Duration(minutes: 2), () {
      if (mounted &&
          session.isActive &&
          _currentSession == session &&
          _isLoading &&
          _loadError == null) {
        _failStartup(
          session,
          'Mini App chưa khởi tạo sau 120 giây. Mở Web Debug để xem lỗi tải JS / WASM, hoặc thử tải lại.',
        );
      }
    });
  }

  Future<void> _checkPageStartup(
    MiniAppRuntimeSession session,
    BridgeEventEmitter emitter,
    MiniAppManifest manifest,
  ) async {
    if (session.isDisposed || _currentSession != session || !mounted) return;
    final result = await session.controller?.runJavaScriptReturningResult(
      'JSON.stringify(window.__SUPERAPP_STARTUP__ || null)',
    );
    if (session.isDisposed || _currentSession != session || !mounted) return;
    var value = jsonDecode(result.toString());
    if (value is String) value = jsonDecode(value);
    if (!mounted || session.isDisposed || _currentSession != session) return;
    if (value is Map) {
      if (value['stage'] == 'error') {
        _failStartup(session, 'Flutter Web: ${value['error']}');
      } else if (value['stage'] == 'ready') {
        await _finishLoading(session, emitter, manifest);
      } else {
        _updateProgressTarget(
          96,
          newCeiling: 98,
          status: 'Flutter Web: ${value['stage']}...',
        );
      }
    } else {
      await _finishLoading(session, emitter, manifest);
    }
  }

  Color _parseColor(String? hexString, {Color defaultColor = Colors.white}) {
    if (hexString == null || hexString.isEmpty) return defaultColor;
    final str = hexString.trim();
    if (str.toLowerCase() == 'transparent') return Colors.transparent;

    // rgb(r, g, b) or rgba(r, g, b, a)
    if (str.toLowerCase().startsWith('rgb')) {
      try {
        final inside = str.substring(str.indexOf('(') + 1, str.indexOf(')'));
        final parts = inside.split(',').map((p) => p.trim()).toList();
        if (parts.length >= 3) {
          final r = int.parse(parts[0]);
          final g = int.parse(parts[1]);
          final b = int.parse(parts[2]);
          final a = parts.length >= 4 ? double.parse(parts[3]) : 1.0;
          return Color.fromRGBO(r, g, b, a);
        }
      } catch (_) {}
    }

    try {
      String hex = str.replaceAll('#', '').trim();
      if (hex.length == 6) {
        hex = 'FF$hex';
      } else if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      } else if (hex.length == 3) {
        hex = 'FF${hex[0]}${hex[0]}${hex[1]}${hex[1]}${hex[2]}${hex[2]}';
      }
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return defaultColor;
    }
  }

  bool _isColorDark(Color color) {
    if (color == Colors.transparent || color.a < 0.2) {
      return false;
    }
    return color.computeLuminance() < 0.5;
  }

  void _startProgressTicker({
    required MiniAppRuntimeSession session,
    required double initialProgress,
    required double initialTarget,
    required double initialCeiling,
    required String initialStatus,
  }) {
    session.progressTicker?.cancel();
    _isFinished = false;
    _displayedProgress = initialProgress;
    _targetProgress = initialTarget;
    _stageCeiling = initialCeiling;
    _statusMessage = initialStatus;
    _progressNotifier.value = initialProgress;
    _statusNotifier.value = initialStatus;

    session.progressTicker =
        Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (!mounted || session.isDisposed || _currentSession != session) {
        timer.cancel();
        return;
      }

      if (_displayedProgress < _targetProgress) {
        // Smooth exponential convergence towards target milestone
        final diff = _targetProgress - _displayedProgress;
        final step = _isFinished
            ? math.max(1.5, diff * 0.25)
            : math.max(0.35, diff * 0.12);
        _displayedProgress = math.min(
          _targetProgress,
          _displayedProgress + step,
        );
        _progressNotifier.value = _displayedProgress;
      } else if (_displayedProgress < _stageCeiling && !_isFinished) {
        // While waiting for asynchronous response, gently advance so progress is active
        final remaining = _stageCeiling - _displayedProgress;
        final creepStep = math.max(0.04, remaining * 0.04);
        _displayedProgress = math.min(
          _stageCeiling,
          _displayedProgress + creepStep,
        );
        _progressNotifier.value = _displayedProgress;
      }
    });
  }

  void _updateProgressTarget(
    double target, {
    double? newCeiling,
    String? status,
  }) {
    if (!mounted || _currentSession?.isDisposed == true) return;
    if (newCeiling != null && newCeiling > _stageCeiling) {
      _stageCeiling = newCeiling;
    }
    if (target > _targetProgress) {
      _targetProgress = target.clamp(0.0, 100.0);
    }
    if (_targetProgress > _stageCeiling) {
      _stageCeiling = _targetProgress;
    }
    if (status != null && status != _statusMessage) {
      _statusMessage = status;
      _statusNotifier.value = status;
    }
  }

  Future<void> _finishLoading(
    MiniAppRuntimeSession session,
    BridgeEventEmitter emitter,
    MiniAppManifest manifest,
  ) async {
    if (!mounted ||
        session.isDisposed ||
        _currentSession != session ||
        !_isLoading ||
        _isFinished) {
      return;
    }
    session.loadTimeoutTimer?.cancel();

    _isFinished = true;
    _updateProgressTarget(
      100.0,
      newCeiling: 100.0,
      status: 'Đang khởi chạy...',
    );

    // Give visual time for progress animation to smoothly hit 100%
    final start = DateTime.now();
    while (mounted &&
        session.isActive &&
        _currentSession == session &&
        _displayedProgress < 99.5 &&
        DateTime.now().difference(start).inMilliseconds < 450) {
      await Future.delayed(const Duration(milliseconds: 25));
    }

    if (!mounted || session.isDisposed || _currentSession != session) return;
    session.progressTicker?.cancel();

    _displayedProgress = 100.0;
    _progressNotifier.value = 100.0;
    setState(() {
      _isLoading = false;
    });

    emitter.emit('miniapp.ready', {
      'appId': manifest.id,
      'version': manifest.version,
    });
    emitter.emit('miniapp.show');

    // Fade out overlay completely after transition
    session.overlayDismissTimer?.cancel();
    session.overlayDismissTimer = Timer(const Duration(milliseconds: 350), () {
      if (mounted &&
          session.isActive &&
          _currentSession == session &&
          !_isLoading) {
        setState(() {
          _showLoadingOverlay = false;
        });
      }
    });

    // Check if root element mounted (diagnostic alert)
    session.diagnosticTimer?.cancel();
    session.diagnosticTimer =
        Timer(const Duration(milliseconds: 2500), () async {
      if (!mounted ||
          session.isDisposed ||
          _currentSession != session ||
          session.controller == null) {
        return;
      }
      try {
        final res = await session.controller!.runJavaScriptReturningResult(
          '(function() { var r = document.getElementById("root"); return !!((r && (r.childElementCount > 0 || r.innerHTML.length > 0)) || document.querySelector("flutter-view, flt-glass-pane, canvas") || (!r && document.body && document.body.innerText.trim())); })()',
        );
        if (session.isDisposed || _currentSession != session) return;
        final isRendered = res.toString() == 'true';
        if (!isRendered && mounted) {
          setState(() {
            _hasBlankScreenWarning = true;
          });
        }
      } catch (_) {}
    });
  }

  void _initMiniApp([String? appId]) {
    if (!mounted) return;
    _startNewSession(appId ?? _currentAppId, isReload: true);
  }

  void _reloadMiniApp(MiniAppManifest? manifest) {
    _initMiniApp(_currentAppId);
  }

  void _startNewSession(String appId, {bool isReload = false}) {
    // 1. Hủy phiên làm việc cũ ngay lập tức (hủy timers, ngắt dispatcher RPCs, dọn controller)
    _currentSession?.dispose();
    _currentSession = null;

    // 2. Cập nhật state UI và unmount WebView cũ
    if (mounted) {
      setState(() {
        _currentAppId = appId;
        _webViewController = null;
        _eventEmitter = null;
        _isLoading = true;
        _showLoadingOverlay = true;
        _hasBlankScreenWarning = false;
        _loadError = null;
      });
    }

    // 3. Khởi tạo phiên cô lập mới với session ID ngẫu nhiên
    final session = MiniAppRuntimeSession(
      sessionId: const Uuid().v4(),
      appId: appId,
    );
    _currentSession = session;

    // 4. Bắt đầu tiến độ tiến trình gắn liền với phiên mới
    _startProgressTicker(
      session: session,
      initialProgress: isReload ? 10.0 : 0.0,
      initialTarget: isReload ? 40.0 : 22.0,
      initialCeiling: isReload ? 68.0 : 28.0,
      initialStatus: isReload
          ? 'Đang làm mới giao diện...'
          : 'Đang kiểm tra Mini App...',
    );

    // 5. Khởi tạo tài nguyên phiên
    _initSession(session);
  }

  Future<void> _initSession(MiniAppRuntimeSession session) async {
    if (session.isDisposed || _currentSession != session || !mounted) return;

    // Revalidate execution authorization & active version with backend on every launch.
    final repo = ref.read(miniAppRepositoryProvider);
    final authorization = await repo.authorizeExecution(session.appId);
    if (!mounted || session.isDisposed || _currentSession != session) return;

    if (authorization == null || !authorization.isValid) {
      if (!mounted || session.isDisposed || _currentSession != session) return;
      session.dispose();
      setState(() {
        _isLoading = false;
        _showLoadingOverlay = false;
        _loadError =
            'Mini App "${session.appId}" chưa được cấp phép thực thi hoặc đã bị thu hồi quyền';
      });
      return;
    }

    final manifest = authorization.manifest;

    // Stage 2: Validating permissions & security environment
    _updateProgressTarget(
      38.0,
      newCeiling: 48.0,
      status: 'Đang xác thực quyền & bảo mật...',
    );

    // Refresh saved consent on every launch, before WebView startup actions run.
    final permissionRepo = ref.read(permissionRepositoryProvider);
    try {
      await permissionRepo.fetchPermissionsFromBackend(session.appId);
    } catch (_) {
      if (!mounted || session.isDisposed || _currentSession != session) return;
      session.dispose();
      setState(() {
        _isLoading = false;
        _showLoadingOverlay = false;
        _loadError = 'Không thể tải quyền Mini App đã lưu. Vui lòng thử lại.';
      });
      return;
    }
    if (!mounted || session.isDisposed || _currentSession != session) return;

    // Stage 3: Initializing Runtime & Bridge
    _updateProgressTarget(
      55.0,
      newCeiling: 68.0,
      status: 'Đang khởi tạo môi trường Runtime...',
    );

    final validManifest = manifest;
    final themeHex =
        validManifest.schema?['theme']?['backgroundColor'] as String?;
    final themeBg = _parseColor(themeHex, defaultColor: Colors.white);

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(themeBg);

    final endpoint = ref.read(backendEndpointProvider);
    final actionDispatcher = NativeActionDispatcher(
      authRepo: ref.read(authRepositoryProvider),
      authCodeService: ref.read(authCodeServiceProvider),
      tokenService: ref.read(tokenServiceProvider),
      userRepo: ref.read(userRepositoryProvider),
      deviceAdapter: ref.read(deviceAdapterProvider),
      permissionRepo: permissionRepo,
      debugLogRepo: ref.read(debugLogRepositoryProvider),
      secureStorageRepo: ref.read(secureStorageRepositoryProvider),
      miniappUrl: endpoint.miniappUrl,
      authUrl: endpoint.authUrl,
      onSwitchMiniApp: (targetAppId) {
        if (!mounted || session.isDisposed || _currentSession != session) return;
        _startNewSession(targetAppId);
      },
    );

    final String initialApprovedOrigin;
    if (validManifest.entryUrl.startsWith('assets/mini_apps/')) {
      final isWeb = validManifest.isWebApp;
      final targetApp = isWeb ? validManifest.id : 'schema_runtime';
      initialApprovedOrigin =
          '${endpoint.baseUrl}/api/v1/miniapps/$targetApp/${validManifest.version}/dist/index.html';
    } else {
      initialApprovedOrigin = validManifest.entryUrl;
    }

    final currentUserId = ref.read(authStateProvider).currentUser?.id;
    final secContext = RuntimeSecurityContext.create(
      manifest: validManifest,
      userId: currentUserId,
      backendBaseUrl: endpoint.baseUrl,
      currentUrl: initialApprovedOrigin,
      customSessionId: session.sessionId,
    );

    final dispatcher = BridgeDispatcher(
      actionDispatcher: actionDispatcher,
      debugLogRepo: ref.read(debugLogRepositoryProvider),
      controller: controller,
      manifest: validManifest,
      uiDelegate: this,
      backendBaseUrl: endpoint.baseUrl,
      userId: currentUserId,
      currentUserIdGetter: () => ref.read(authStateProvider).currentUser?.id,
      runtimeSessionId: session.sessionId,
      securityContext: secContext,
    );

    final emitter = BridgeEventEmitter(controller);

    // Gắn tài nguyên vào session để giải phóng đồng bộ
    session.controller = controller;
    session.dispatcher = dispatcher;
    session.actionDispatcher = actionDispatcher;
    session.eventEmitter = emitter;

    await BridgeChannel.register(
      controller: controller,
      dispatcher: dispatcher,
      contextGetter: () => context,
      onWebDebugMessage: (rawMessage) {
        if (session.isDisposed || _currentSession != session || !mounted) return;
        try {
          final data = jsonDecode(rawMessage) as Map<String, dynamic>;
          final entry = WebLogEntry.fromJson(data);
          _recordWebLog(entry);
          if (entry.type == 'startup' &&
              mounted &&
              session.isActive &&
              _currentSession == session &&
              _isLoading &&
              _loadError == null) {
            if (entry.message == 'ready') {
              _finishLoading(session, emitter, validManifest);
            } else if (entry.message == 'error') {
              _failStartup(session, 'Flutter Web: ${entry.stack ?? entry.message}');
            } else {
              _updateProgressTarget(
                96,
                newCeiling: 98,
                status: 'Flutter Web: ${entry.message}...',
              );
            }
          }
        } catch (e) {
          debugPrint('[WebDebug] Failed to parse message: $rawMessage');
        }
      },
    );

    if (session.isDisposed || _currentSession != session || !mounted) return;

    await controller.setOnConsoleMessage((JavaScriptConsoleMessage message) {
      if (session.isDisposed || _currentSession != session || !mounted) return;
      debugPrint(
        '[MiniApp Web Console] (${message.level.name}): ${message.message}',
      );
      // The JS hook carries richer details; only suppress its immediate native echo.
      final duplicate =
          _webLogs.isNotEmpty &&
          _webLogs.first.message == message.message &&
          DateTime.now().difference(_webLogs.first.timestamp).inMilliseconds <
              100;
      if (!duplicate) {
        _recordWebLog(
          WebLogEntry(
            id: 'console_${DateTime.now().microsecondsSinceEpoch}',
            type: 'console',
            level: message.level.name.toLowerCase(),
            message: message.message,
          ),
        );
      }
    });

    if (session.isDisposed || _currentSession != session || !mounted) return;

    if (await controller.isUserScriptInjectionSupported(
      WebViewUserScriptInjectionTime.documentStart,
    )) {
      await controller.addUserScript(
        WebViewUserScript(
          source:
              '${BridgeChannel.webDebugPolyfillScript}\n${BridgeChannel.bridgePolyfillScript}',
        ),
      );
    }

    if (session.isDisposed || _currentSession != session || !mounted) return;

    const resetScript = '''
      (function() {
        if (!document.getElementById('__superapp_runtime_reset__')) {
          var style = document.createElement('style');
          style.id = '__superapp_runtime_reset__';
          style.innerHTML = '*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; } html, body { width: 100% !important; min-height: 100% !important; margin: 0 !important; padding: 0 !important; background-color: transparent !important; overflow-x: hidden !important; } #root { width: 100% !important; min-height: 100% !important; }';
          (document.head || document.documentElement).appendChild(style);
        }
      })();
    ''';

    await controller.setNavigationDelegate(
      NavigationDelegate(
        onNavigationRequest: (NavigationRequest request) async {
          if (session.isDisposed || _currentSession != session) {
            return NavigationDecision.prevent;
          }
          final rawUrl = request.url;
          final uri = Uri.tryParse(rawUrl);

          // 1. Chặn đứng các scheme nguy hiểm (javascript:, data:, file:, ...)
          if (uri == null || MiniAppSecurityPolicy.isBlockedScheme(uri)) {
            debugPrint('[Security] Đã chặn điều hướng scheme nguy hiểm: $rawUrl');
            _recordWebLog(
              WebLogEntry(
                id: 'sec_${DateTime.now().microsecondsSinceEpoch}',
                type: 'error',
                level: 'error',
                message: 'Chặn điều hướng tới URL không an toàn: $rawUrl',
              ),
            );
            return NavigationDecision.prevent;
          }

          // 2. Cho phép in-page anchor navigation (ví dụ: #section)
          if (uri.hasFragment && (!uri.hasScheme || uri.scheme.isEmpty) && uri.host.isEmpty) {
            return NavigationDecision.navigate;
          }

          // 3. Kiểm tra xem URL đích có thuộc phạm vi phân phối tin cậy của Mini App không
          final isTrusted = MiniAppSecurityPolicy.isTrustedMiniAppUrl(
            uri,
            manifest: validManifest,
            backendBaseUrl: endpoint.baseUrl,
          );

          if (isTrusted) {
            return NavigationDecision.navigate;
          }

          // 4. Nếu là liên kết ngoài: CHẶN trong WebView, mở bằng trình duyệt hệ thống
          debugPrint(
            '[Security] Chặn liên kết ngoài trong WebView, mở trình duyệt hệ thống: $rawUrl',
          );
          _recordWebLog(
            WebLogEntry(
              id: 'nav_${DateTime.now().microsecondsSinceEpoch}',
              type: 'navigation',
              level: 'warn',
              message: 'Liên kết ngoài được mở bằng trình duyệt hệ thống: $rawUrl',
            ),
          );

          await MiniAppSecurityPolicy.openExternalUrl(uri);
          return NavigationDecision.prevent;
        },
        onProgress: (int progress) {
          if (session.isDisposed || _currentSession != session) return;
          if (mounted && _isLoading) {
            // Map webview resource loading (0..100) to progress range (70..95)
            final mapped = 70.0 + (progress.clamp(0, 100) / 100.0) * 25.0;
            _updateProgressTarget(
              mapped,
              newCeiling: 96.0,
              status: 'Đang tải tài nguyên ($progress%)...',
            );
          }
        },
        onPageStarted: (url) {
          if (session.isDisposed || _currentSession != session) return;
          _updateProgressTarget(
            68.0,
            newCeiling: 92.0,
            status: 'Đang nạp dữ liệu giao diện...',
          );
          if (!kIsWeb) {
            _safeRunScript(controller, resetScript);
            _safeRunScript(controller, BridgeChannel.webDebugPolyfillScript);
            _safeRunScript(controller, BridgeChannel.bridgePolyfillScript);
            if (validManifest.isSchemaApp && validManifest.schema != null) {
              final schemaJson = jsonEncode(validManifest.schema);
              _safeRunScript(
                controller,
                '''try {
                  window.__MINIAPP_SCHEMA__ = $schemaJson;
                  window.__MINIAPP_APP_ID__ = "${validManifest.id}";
                  window.dispatchEvent(new CustomEvent("miniapp.schema_loaded", { detail: { schema: $schemaJson, appId: "${validManifest.id}" } }));
                } catch(e) { console.error("[Schema Inject Error]", e.message || e); }''',
              );
            }
          }
        },
        onPageFinished: (url) async {
          if (session.isDisposed || _currentSession != session) return;
          await _safeRunScript(controller, resetScript);
          await _safeRunScript(
            controller,
            BridgeChannel.webDebugPolyfillScript,
          );
          await _safeRunScript(controller, BridgeChannel.bridgePolyfillScript);
          if (validManifest.isSchemaApp && validManifest.schema != null) {
            final schemaJson = jsonEncode(validManifest.schema);
            await _safeRunScript(
              controller,
              '''try {
                if (!window.__MINIAPP_SCHEMA__) {
                  window.__MINIAPP_SCHEMA__ = $schemaJson;
                  window.__MINIAPP_APP_ID__ = "${validManifest.id}";
                }
                window.dispatchEvent(new CustomEvent("miniapp.schema_loaded", { detail: { schema: $schemaJson, appId: "${validManifest.id}" } }));
              } catch(e) { console.error("[Schema Inject Error]", e.message || e); }''',
            );
          }
          try {
            await _checkPageStartup(session, emitter, validManifest);
          } catch (error) {
            _failStartup(session, 'Không thể kiểm tra khởi tạo Mini App: $error');
          }
        },
        onWebResourceError: (error) {
          if (session.isDisposed || _currentSession != session) return;
          final message =
              'WebView ${error.errorCode}: ${error.description} (${error.url ?? "unknown URL"})';
          _recordWebLog(
            WebLogEntry(
              id: 'resource_${DateTime.now().microsecondsSinceEpoch}',
              type: 'error',
              level: 'error',
              message: message,
            ),
          );
          if (error.isForMainFrame == true) _failStartup(session, message);
        },
      ),
    );

    if (session.isDisposed || _currentSession != session || !mounted) return;

    if (mounted) {
      setState(() {
        _webViewController = controller;
        _eventEmitter = emitter;
      });
    } else {
      _webViewController = controller;
      _eventEmitter = emitter;
    }

    _updateProgressTarget(
      62.0,
      newCeiling: 88.0,
      status: 'Đang kết nối tài nguyên...',
    );

    _startLoadDeadline(session);

    // Load entry point: remote Backend URL is the primary runtime loader
    if (validManifest.isAsset &&
        validManifest.entryUrl.startsWith('assets/') &&
        !validManifest.entryUrl.startsWith('assets/mini_apps/')) {
      try {
        controller.loadFlutterAsset(validManifest.entryUrl);
      } catch (e) {
        debugPrint('[MiniAppRuntimeScreen] loadFlutterAsset error: $e');
        controller.loadRequest(Uri.parse(validManifest.entryUrl));
      }
    } else {
      var targetUri = validManifest.entryUrl;
      if (targetUri.startsWith('assets/mini_apps/')) {
        final isWeb = validManifest.isWebApp;
        final targetApp = isWeb ? validManifest.id : 'schema_runtime';
        targetUri =
            '${endpoint.baseUrl}/api/v1/miniapps/$targetApp/${validManifest.version}/dist/index.html';
      }

      // Xác thực bảo mật URL khởi chạy (Entry URL Verification)
      final validation = MiniAppSecurityPolicy.validateEntryUrl(
        targetUri,
        manifest: validManifest,
        backendBaseUrl: endpoint.baseUrl,
      );

      if (!validation.isValid) {
        _failStartup(session, 'Bảo mật: ${validation.errorMessage}');
        return;
      }

      controller.loadRequest(validation.uri ?? Uri.parse(targetUri));
    }
  }

  void _openWebDebugModal([MiniAppManifest? manifest]) {
    final activeManifest =
        manifest ??
        ref.read(miniAppRepositoryProvider).getAppById(_currentAppId);
    WebViewDebugBottomSheet.show(
      context,
      controller: _webViewController,
      logs: _webLogs,
      logsRevision: _webLogRevision,
      onClearLogs: () {
        _webLogs.clear();
        _webLogRevision.value++;
      },
      appId: _currentAppId,
      appTitle: activeManifest?.name ?? _currentAppId,
    );
  }

  void _showMiniAppActionBottomSheet(MiniAppManifest? manifest) {
    MiniAppActionBottomSheet.show(
      context,
      manifest: manifest,
      appId: _currentAppId,
      onWebDebug: () => _openWebDebugModal(manifest),
      onReload: () {
        _reloadMiniApp(manifest);
      },
      onMinimize: () {
        _eventEmitter?.emit('miniapp.hide');
        Navigator.of(context).pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final manifest = ref
        .watch(miniAppRepositoryProvider)
        .getAppById(_currentAppId);

    final themeHex = manifest?.schema?['theme']?['backgroundColor'] as String?;
    final defaultBgColor = _parseColor(themeHex, defaultColor: Colors.white);
    final themeBgColor = defaultBgColor;
    final isDarkTheme = _isColorDark(themeBgColor);
    final headerBgColor = _overrideHeaderColor ?? defaultBgColor;
    final isDarkHeader = _overrideTextColor == 'white'
        ? true
        : (_overrideTextColor == 'black' ? false : _isColorDark(headerBgColor));
    final headerTextColor = isDarkHeader
        ? Colors.white
        : const Color(0xFF0F172A);
    final displayTitle = _overrideTitle ?? manifest?.name ?? 'Mini App';

    Color brandColor;
    final themePrimaryHex =
        manifest?.schema?['theme']?['primaryColor'] as String? ??
        manifest?.schema?['theme']?['accentColor'] as String?;
    if (themePrimaryHex != null && themePrimaryHex.isNotEmpty) {
      brandColor = _parseColor(
        themePrimaryHex,
        defaultColor: const Color(0xFF2563EB),
      );
    } else {
      switch (_currentAppId) {
        case 'tiktok':
          brandColor = const Color(0xFF010101);
          break;
        case 'youtube':
          brandColor = const Color(0xFFFF0000);
          break;
        case 'messenger':
          brandColor = const Color(0xFF0084FF);
          break;
        case 'facebook':
          brandColor = const Color(0xFF1877F2);
          break;
        case 'zalo':
          brandColor = const Color(0xFF0068FF);
          break;
        case 'shopee':
          brandColor = const Color(0xFFEE4D2D);
          break;
        case 'sample_store':
        case 'coffee_shop':
          brandColor = const Color(0xFFD97706);
          break;
        case 'sdk_playground':
          brandColor = const Color(0xFF2563EB);
          break;
        case 'flutter_scanner':
          brandColor = const Color(0xFF0068FF);
          break;
        case 'free_fire':
          brandColor = const Color(0xFFF59E0B);
          break;
        case 'fc_mobile':
          brandColor = const Color(0xFF10B981);
          break;
        case 'capcut':
          brandColor = const Color(0xFF06B6D4);
          break;
        case 'viettel_tammi':
          brandColor = const Color(0xFFDC2626);
          break;
        default:
          brandColor = isDarkTheme
              ? const Color(0xFFF59E0B)
              : const Color(0xFF00BA52);
      }
    }

    ref.listen(authStateProvider, (prev, next) {
      final prevUserId = prev?.currentUser?.id;
      final nextUserId = next.currentUser?.id;
      if (prev != null && prevUserId != nextUserId) {
        if (_eventEmitter != null) {
          _eventEmitter!.emitSessionChanged(
            state: next.isAuthenticated ? 'account_switched' : 'logged_out',
          );
        }
        // Hủy ngay phiên làm việc của tài khoản trước để bảo vệ dữ liệu và ngăn rò rỉ namespace
        _currentSession?.dispose();
        _currentSession = null;
        if (mounted) {
          if (next.isAuthenticated) {
            // Tái khởi tạo runtime mới cô lập cho tài khoản vừa đăng nhập/chuyển đổi
            _startNewSession(_currentAppId);
          } else {
            // Đã đăng xuất: hủy WebView và thoát khỏi màn hình Mini App runtime
            setState(() {
              _webViewController = null;
              _eventEmitter = null;
              _isLoading = false;
              _showLoadingOverlay = false;
              _loadError = 'Phiên làm việc đã kết thúc do tài khoản đã đăng xuất.';
            });
            Navigator.of(context).maybePop();
          }
        }
      }
    });

    final safeTopInset = MediaQuery.of(context).padding.top;
    final safeBottomInset = MediaQuery.of(context).padding.bottom;
    final bool enableSafeAreaTop = _hasPaddingTop && _hasPadding;
    final bool enableSafeAreaBottom = _hasPaddingBottom && _hasPadding;

    final isHeaderTransparent =
        headerBgColor == Colors.transparent ||
        headerBgColor.a < 0.95 ||
        _statusBarStyle == 'transparent';
    const headerBarHeight = 48.0;
    final totalHeaderHeight =
        (_isStatusBarHidden ? 0.0 : safeTopInset) + headerBarHeight;

    // Effective background tint for frosted glass / transparent header
    final effectiveHeaderBgColor = headerBgColor == Colors.transparent
        ? (isDarkHeader
              ? Colors.black.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.65))
        : (isHeaderTransparent
              ? headerBgColor.withValues(alpha: 0.8)
              : headerBgColor);

    final statusBarColor = _overrideStatusBarColor ?? Colors.transparent;
    final statusBarIconBrightness = _statusBarStyle == 'light'
        ? Brightness.dark
        : (_statusBarStyle == 'dark'
              ? Brightness.light
              : (isDarkHeader ? Brightness.light : Brightness.dark));
    final statusBarBrightness = statusBarIconBrightness == Brightness.light
        ? Brightness.dark
        : Brightness.light;

    // Mini App Content Top & Bottom
    final contentTop =
        (isHeaderTransparent || !enableSafeAreaTop || _isActionBarHidden)
        ? (enableSafeAreaTop && !_isStatusBarHidden ? safeTopInset : 0.0)
        : totalHeaderHeight;
    final contentBottom = enableSafeAreaBottom ? safeBottomInset : 0.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: statusBarColor,
        statusBarIconBrightness: statusBarIconBrightness,
        statusBarBrightness: statusBarBrightness,
        systemNavigationBarColor:
            _bottomNavColor ?? (_hideBottomNav ? Colors.transparent : null),
      ),
      child: Scaffold(
        backgroundColor: defaultBgColor,
        body: Stack(
          children: [
            // Mini App Content: Edge-to-Edge with dynamic offset based on header transparency & safe area
            Positioned(
              top: contentTop,
              left: 0,
              right: 0,
              bottom: contentBottom,
              child: Stack(
                children: [
                  if (_webViewController != null && _loadError == null)
                    SizedBox(
                      width: double.infinity,
                      height: double.infinity,
                      child: WebViewWidget(controller: _webViewController!),
                    ),

                  // Diagnostic Alert Banner for blank screen (Only in debug mode)
                  if (ref.watch(isDebugModeEnabledProvider) &&
                      _hasBlankScreenWarning &&
                      !_isLoading &&
                      _loadError == null)
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 20,
                      child: Material(
                        elevation: 8,
                        borderRadius: BorderRadius.circular(12),
                        color: const Color(0xFF1E293B),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.amber,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Màn hình có thể bị trắng hoặc chưa mount được React DOM.',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF38BDF8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                ),
                                onPressed: () => _openWebDebugModal(manifest),
                                child: const Text(
                                  'DEBUG NGAY',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white54,
                                  size: 16,
                                ),
                                onPressed: () => setState(
                                  () => _hasBlankScreenWarning = false,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  if (_showLoadingOverlay)
                    AnimatedOpacity(
                      opacity: _isLoading ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: IgnorePointer(
                        ignoring: !_isLoading,
                        child: Container(
                          color: themeBgColor,
                          child: Center(
                            child: _buildLoadingView(
                              manifest,
                              isDarkTheme,
                              themeBgColor,
                              brandColor,
                            ),
                          ),
                        ),
                      ),
                    ),

                  if (_loadError != null)
                    Container(
                      color: themeBgColor,
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              size: 48,
                              color: Colors.red,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _loadError!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isDarkTheme
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ElevatedButton(
                                  onPressed: () {
                                    _initMiniApp();
                                  },
                                  child: const Text('Thử lại'),
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton.icon(
                                  icon: const Icon(
                                    Icons.terminal_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Xem Web Debug'),
                                  onPressed: () => _openWebDebugModal(manifest),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Dynamic Top Navigation Bar (with frosted glass / blur and auto-contrast capsule)
            if (!_isActionBarHidden)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildAdaptiveAppBar(
                  context: context,
                  manifest: manifest,
                  topInset: _isStatusBarHidden ? 0.0 : safeTopInset,
                  displayTitle: displayTitle,
                  headerBgColor: effectiveHeaderBgColor,
                  isDarkHeader: isDarkHeader,
                  headerTextColor: headerTextColor,
                  isHeaderTransparent: isHeaderTransparent,
                ),
              )
            else
              // Khi tắt/ẩn AppBar, riêng nút action capsule [ ••• | ⊙ ] vẫn luôn được bảo toàn Safe Area góc phải
              Positioned(
                top: (_isStatusBarHidden ? 0.0 : safeTopInset) + 8.0,
                right: 14.0,
                child: _buildCapsuleButton(
                  context: context,
                  manifest: manifest,
                  isDarkHeader: isDarkHeader,
                  isHeaderTransparent: true,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapsuleButton({
    required BuildContext context,
    required MiniAppManifest? manifest,
    required bool isDarkHeader,
    required bool isHeaderTransparent,
  }) {
    // Dynamic Auto-contrast capsule styling:
    // Mini App CANNOT edit/remove this button (SuperApp host security invariant).
    // The button automatically calculates contrast to remain clearly visible on any background.
    final bool useGlassCapsule = isHeaderTransparent;
    final Color capsuleBg = useGlassCapsule
        ? (isDarkHeader
              ? Colors.black.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.75))
        : (isDarkHeader
              ? Colors.white.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.95));

    final Color capsuleBorderColor = isDarkHeader
        ? Colors.white.withValues(alpha: 0.35)
        : const Color(0xFFCBD5E1);

    final Color capsuleIconColor = isDarkHeader
        ? Colors.white
        : const Color(0xFF0F172A);

    final Color capsuleDividerColor = isDarkHeader
        ? Colors.white.withValues(alpha: 0.3)
        : const Color(0xFFE2E8F0);

    Widget capsuleButton = Container(
      height: 32,
      decoration: BoxDecoration(
        color: capsuleBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: capsuleBorderColor, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkHeader ? 0.3 : 0.06),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Nút thông tin miniapp (•••)
          InkWell(
            onTap: () => _showMiniAppActionBottomSheet(manifest),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              bottomLeft: Radius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Icon(
                Icons.more_horiz_rounded,
                size: 20,
                color: capsuleIconColor,
              ),
            ),
          ),
          // Capsule Divider
          Container(width: 0.8, height: 16, color: capsuleDividerColor),
          // Nút đóng miniapp (⊙)
          InkWell(
            onTap: () {
              _eventEmitter?.emit('miniapp.close');
              Navigator.of(context).pop();
            },
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Icon(
                Icons.adjust_rounded,
                size: 18,
                color: capsuleIconColor,
              ),
            ),
          ),
        ],
      ),
    );

    if (useGlassCapsule) {
      capsuleButton = ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: capsuleButton,
        ),
      );
    }

    return capsuleButton;
  }

  Widget _buildAdaptiveAppBar({
    required BuildContext context,
    required MiniAppManifest? manifest,
    required double topInset,
    required String displayTitle,
    required Color headerBgColor,
    required bool isDarkHeader,
    required Color headerTextColor,
    required bool isHeaderTransparent,
  }) {
    final capsuleButton = _buildCapsuleButton(
      context: context,
      manifest: manifest,
      isDarkHeader: isDarkHeader,
      isHeaderTransparent: isHeaderTransparent,
    );

    final barContent = Container(
      height: _isStatusBarHidden ? 48.0 : (topInset + 48.0),
      padding: EdgeInsets.only(
        top: _isStatusBarHidden ? 0.0 : topInset,
        left: 14,
        right: 14,
      ),
      decoration: BoxDecoration(
        color: headerBgColor,
        border: Border(
          bottom: BorderSide(
            color: isDarkHeader
                ? Colors.white.withValues(alpha: 0.1)
                : const Color(0xFFE2E8F0),
            width: 0.8,
          ),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Title: Defaults to left-aligned when unchanged, centered when overridden/updated
          Builder(
            builder: (context) {
              final isTitleChanged = _overrideTitle != null;
              final isLeft =
                  _titleAlignment == 'left' ||
                  (_titleAlignment == null && !isTitleChanged);

              return Align(
                alignment: isLeft ? Alignment.centerLeft : Alignment.center,
                child: Padding(
                  padding: isLeft
                      ? const EdgeInsets.only(left: 2, right: 90)
                      : const EdgeInsets.symmetric(horizontal: 90),
                  child: Text(
                    displayTitle,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: headerTextColor,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            },
          ),

          // Right Capsule Bar: [ ••• | ⊙ ] (Host-Controlled, Cannot be removed or edited)
          Align(alignment: Alignment.centerRight, child: capsuleButton),
        ],
      ),
    );

    if (isHeaderTransparent) {
      return ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: barContent,
        ),
      );
    }

    return barContent;
  }

  Widget _buildAppLogo(MiniAppManifest? manifest, Color brandColor) {
    final appId = manifest?.id ?? _currentAppId;
    final iconStr = manifest?.icon ?? '';
    final endpoint = ref.read(backendEndpointProvider);

    String? fullNetworkUrl;
    if (iconStr.startsWith('http://') || iconStr.startsWith('https://')) {
      fullNetworkUrl = iconStr;
    } else if (iconStr.startsWith('/')) {
      fullNetworkUrl = '${endpoint.baseUrl}$iconStr';
    }

    IconData fallbackIcon = Icons.apps_rounded;
    final iconName = iconStr.toLowerCase();
    if (iconName == 'video' ||
        iconName == 'movie' ||
        appId == 'capcut' ||
        appId == 'youtube') {
      fallbackIcon = Icons.movie_filter_rounded;
    } else if (iconName == 'games' ||
        iconName == 'game' ||
        appId == 'free_fire') {
      fallbackIcon = Icons.sports_esports_rounded;
    } else if (iconName == 'social' ||
        iconName == 'chat' ||
        appId == 'messenger') {
      fallbackIcon = Icons.chat_bubble_rounded;
    } else if (iconName == 'shopping' ||
        iconName == 'cart' ||
        appId == 'shopee') {
      fallbackIcon = Icons.shopping_bag_rounded;
    } else if (iconName == 'coffee' ||
        iconName == 'storefront' ||
        appId == 'sample_store' ||
        appId == 'coffee_shop') {
      fallbackIcon = Icons.coffee_rounded;
    } else if (iconName == 'code' ||
        iconName == 'terminal' ||
        appId == 'sdk_playground') {
      fallbackIcon = Icons.code_rounded;
    } else if (iconName == 'qr_code_scanner' ||
        iconName == 'scanner' ||
        appId == 'flutter_scanner') {
      fallbackIcon = Icons.qr_code_scanner_rounded;
    } else if (iconName == 'utilities' || appId == 'viettel_tammi') {
      fallbackIcon = Icons.cell_tower_rounded;
    } else if (iconName == 'music' || appId == 'tiktok') {
      fallbackIcon = Icons.music_note_rounded;
    } else if (appId == 'fc_mobile') {
      fallbackIcon = Icons.sports_soccer_rounded;
    } else if (appId == 'facebook') {
      fallbackIcon = Icons.facebook_rounded;
    } else if (appId == 'zalo') {
      fallbackIcon = Icons.message_rounded;
    }

    return Container(
      width: 78,
      height: 78,
      decoration: BoxDecoration(
        color: brandColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: brandColor.withValues(alpha: 0.35),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: fullNetworkUrl != null
            ? Image.network(
                fullNetworkUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Icon(fallbackIcon, size: 40, color: Colors.white),
              )
            : Icon(fallbackIcon, size: 40, color: Colors.white),
      ),
    );
  }

  Widget _buildLoadingView(
    MiniAppManifest? manifest,
    bool isDarkTheme,
    Color themeBgColor,
    Color brandColor,
  ) {
    final title = manifest?.name.isNotEmpty == true
        ? manifest!.name
        : (_overrideTitle ?? 'Mini App');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PulseEffect(
          minScale: 0.94,
          maxScale: 1.04,
          duration: const Duration(milliseconds: 1400),
          child: _buildAppLogo(manifest, brandColor),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isDarkTheme ? Colors.white : const Color(0xFF0F172A),
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 24),
        _MiniAppProgressIndicator(
          progressNotifier: _progressNotifier,
          statusNotifier: _statusNotifier,
          isDarkTheme: isDarkTheme,
          brandColor: brandColor,
        ),
      ],
    );
  }
}

class _MiniAppProgressIndicator extends StatelessWidget {
  final ValueNotifier<double> progressNotifier;
  final ValueNotifier<String> statusNotifier;
  final bool isDarkTheme;
  final Color brandColor;

  const _MiniAppProgressIndicator({
    required this.progressNotifier,
    required this.statusNotifier,
    required this.isDarkTheme,
    required this.brandColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ValueListenableBuilder<double>(
          valueListenable: progressNotifier,
          builder: (context, progress, _) {
            final percent = progress.clamp(0.0, 100.0).toInt();
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$percent%',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: brandColor,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: 170,
                  height: 6,
                  decoration: BoxDecoration(
                    color:
                        isDarkTheme ? Colors.white12 : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: (progress / 100.0).clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: brandColor,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: brandColor.withValues(alpha: 0.4),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        ValueListenableBuilder<String>(
          valueListenable: statusNotifier,
          builder: (context, status, _) {
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                status,
                key: ValueKey(status),
                style: TextStyle(
                  color: isDarkTheme ? Colors.white60 : const Color(0xFF64748B),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
