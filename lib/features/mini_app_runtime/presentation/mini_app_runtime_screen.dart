import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_all/webview_all.dart';
import '../../authentication/presentation/controllers/auth_controller.dart';
import '../../debug_center/data/debug_log_repository.dart';
import '../../mini_app_catalog/data/mini_app_repository.dart';
import '../../mini_app_catalog/domain/mini_app_manifest.dart';
import '../../mini_app_bridge/bridge_channel.dart';
import '../../mini_app_bridge/bridge_dispatcher.dart';
import '../../mini_app_bridge/bridge_event_emitter.dart';
import '../../native_actions/application/native_action_dispatcher.dart';
import '../../user_profile/data/mock_user_repository.dart';
import '../../device/data/mock_device_adapter.dart';
import '../../payment/data/mock_order_repository.dart';
import '../../permissions/data/mock_permission_repository.dart';
import '../domain/web_log_entry.dart';
import 'widgets/webview_debug_bottom_sheet.dart';
import '../../../../core/config/app_theme.dart';

class MiniAppRuntimeScreen extends ConsumerStatefulWidget {
  final String appId;

  const MiniAppRuntimeScreen({super.key, required this.appId});

  @override
  ConsumerState<MiniAppRuntimeScreen> createState() =>
      _MiniAppRuntimeScreenState();
}

class _MiniAppRuntimeScreenState extends ConsumerState<MiniAppRuntimeScreen>
    with WidgetsBindingObserver {
  late String _currentAppId;
  WebViewController? _webViewController;
  BridgeEventEmitter? _eventEmitter;
  bool _isLoading = true;
  String? _loadError;
  final List<WebLogEntry> _webLogs = [];
  bool _hasBlankScreenWarning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentAppId = widget.appId;
    _initMiniApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _eventEmitter?.emit('miniapp.close');
    super.dispose();
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

  Future<void> _initMiniApp() async {
    setState(() {
      _hasBlankScreenWarning = false;
    });

    MiniAppManifest? manifest = ref
        .read(miniAppRepositoryProvider)
        .getAppById(_currentAppId);

    if (manifest == null || (manifest.isSchemaApp && manifest.schema == null)) {
      manifest = await ref
          .read(miniAppRepositoryProvider)
          .fetchRemoteManifest(_currentAppId);
    }

    if (manifest == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Mini App "$_currentAppId" không tồn tại hoặc chưa được publish';
      });
      return;
    }

    final validManifest = manifest;

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white);

    final actionDispatcher = NativeActionDispatcher(
      authRepo: ref.read(mockAuthRepositoryProvider),
      authCodeService: ref.read(mockAuthCodeServiceProvider),
      tokenService: ref.read(mockTokenServiceProvider),
      userRepo: ref.read(mockUserRepositoryProvider),
      deviceAdapter: ref.read(deviceAdapterProvider),
      orderRepo: ref.read(mockOrderRepositoryProvider),
      permissionRepo: ref.read(mockPermissionRepositoryProvider),
      debugLogRepo: ref.read(debugLogRepositoryProvider),
      onSwitchMiniApp: (targetAppId) {
        setState(() {
          _currentAppId = targetAppId;
          _isLoading = true;
          _initMiniApp();
        });
      },
    );

    final dispatcher = BridgeDispatcher(
      actionDispatcher: actionDispatcher,
      debugLogRepo: ref.read(debugLogRepositoryProvider),
      controller: controller,
      manifest: validManifest,
    );

    final emitter = BridgeEventEmitter(controller);

    BridgeChannel.register(
      controller: controller,
      dispatcher: dispatcher,
      contextGetter: () => context,
      onWebDebugMessage: (rawMessage) {
        try {
          final data = jsonDecode(rawMessage) as Map<String, dynamic>;
          final entry = WebLogEntry.fromJson(data);
          if (mounted) {
            setState(() {
              _webLogs.insert(0, entry);
              if (_webLogs.length > 500) _webLogs.removeLast();
            });
          }
        } catch (e) {
          debugPrint('[WebDebug] Failed to parse message: $rawMessage');
        }
      },
    );

    controller.setOnConsoleMessage((JavaScriptConsoleMessage consoleMessage) {
      debugPrint('[MiniApp Web Console] (${consoleMessage.level.name}): ${consoleMessage.message}');
      final isExisting = _webLogs.any((l) => l.message == consoleMessage.message);
      if (!isExisting && mounted) {
        setState(() {
          _webLogs.insert(
            0,
            WebLogEntry(
              id: 'native_console_${DateTime.now().microsecondsSinceEpoch}',
              type: 'console',
              level: consoleMessage.level.name.toLowerCase(),
              message: consoleMessage.message,
            ),
          );
          if (_webLogs.length > 500) _webLogs.removeLast();
        });
      }
    });

    controller.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (url) {
          // Inject debug polyfill first to intercept early errors
          controller.runJavaScript(BridgeChannel.webDebugPolyfillScript);
          controller.runJavaScript(BridgeChannel.bridgePolyfillScript);
          if (validManifest.isSchemaApp && validManifest.schema != null) {
            final schemaJson = jsonEncode(validManifest.schema);
            controller.runJavaScript(
              '''try {
                window.__MINIAPP_SCHEMA__ = $schemaJson;
                window.__MINIAPP_APP_ID__ = "${validManifest.id}";
                window.dispatchEvent(new CustomEvent("miniapp.schema_loaded", { detail: { schema: $schemaJson, appId: "${validManifest.id}" } }));
              } catch(e) { console.error("[Schema Inject Error]", e.message || e, e.stack || ''); }''',
            );
          }
        },
        onPageFinished: (url) {
          controller.runJavaScript(BridgeChannel.webDebugPolyfillScript);
          controller.runJavaScript(BridgeChannel.bridgePolyfillScript);
          if (validManifest.isSchemaApp && validManifest.schema != null) {
            final schemaJson = jsonEncode(validManifest.schema);
            controller.runJavaScript(
              '''try {
                if (!window.__MINIAPP_SCHEMA__) {
                  window.__MINIAPP_SCHEMA__ = $schemaJson;
                  window.__MINIAPP_APP_ID__ = "${validManifest.id}";
                }
                window.dispatchEvent(new CustomEvent("miniapp.schema_loaded", { detail: { schema: $schemaJson, appId: "${validManifest.id}" } }));
              } catch(e) { console.error("[Schema Inject Error]", e.message || e, e.stack || ''); }''',
            );
          }
          setState(() {
            _isLoading = false;
          });
          emitter.emit('miniapp.ready', {
            'appId': validManifest.id,
            'version': validManifest.version,
          });
          emitter.emit('miniapp.show');

          // Check if root element mounted after 2.5 seconds
          Future.delayed(const Duration(milliseconds: 2500), () async {
            if (!mounted || _webViewController == null) return;
            try {
              final res = await _webViewController!.runJavaScriptReturningResult(
                '(function() { var r = document.getElementById("root"); return !!(r && (r.childElementCount > 0 || r.innerHTML.length > 0)); })()'
              );
              final isRendered = res.toString() == 'true';
              if (!isRendered && mounted) {
                setState(() {
                  _hasBlankScreenWarning = true;
                });
              }
            } catch (_) {}
          });
        },
        onWebResourceError: (error) {
          setState(() {
            _isLoading = false;
            _loadError = 'Không thể tải Mini App: ${error.description}';
          });
        },
      ),
    );

    _webViewController = controller;
    _eventEmitter = emitter;

    // Load entry point based on runtime type
    if (validManifest.isSchemaApp) {
      controller.loadFlutterAsset('assets/mini_apps/schema_runtime/index.html');
    } else if (validManifest.isAsset) {
      controller.loadFlutterAsset(validManifest.entryUrl);
    } else {
      controller.loadRequest(Uri.parse(validManifest.entryUrl));
    }
  }

  void _openWebDebugModal(MiniAppManifest? manifest) {
    WebViewDebugBottomSheet.show(
      context,
      controller: _webViewController,
      logs: _webLogs,
      onClearLogs: () => setState(() => _webLogs.clear()),
      appId: _currentAppId,
      appTitle: manifest?.name ?? 'Mini App',
    );
  }

  @override
  Widget build(BuildContext context) {
    final manifest = ref
        .watch(miniAppRepositoryProvider)
        .getAppById(_currentAppId);

    // Listen to session changes to notify Mini App if logged out
    ref.listen(authStateProvider, (prev, next) {
      if (!next.isAuthenticated && _eventEmitter != null) {
        _eventEmitter!.emitSessionChanged(state: 'logged_out');
      }
    });

    final errorCount = _webLogs.where((l) => l.isError).length;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              manifest?.name ?? 'Mini App Runtime',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppTheme.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'Runtime Bridge Connected',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.black.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // WebView Debug Inspector button with error counter badge
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                tooltip: 'WebView Debug Inspector',
                icon: Icon(
                  Icons.bug_report_rounded,
                  color: errorCount > 0 ? Colors.red : const Color(0xFF2563EB),
                ),
                onPressed: () => _openWebDebugModal(manifest),
              ),
              if (errorCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.4),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Center(
                      child: Text(
                        errorCount > 99 ? '99+' : '$errorCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            tooltip: 'Tải lại Mini App',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              setState(() {
                _isLoading = true;
                _hasBlankScreenWarning = false;
              });
              _webViewController?.reload();
            },
          ),
          IconButton(
            tooltip: 'Bridge Logs',
            icon: const Icon(Icons.developer_mode_rounded),
            onPressed: () {
              context.push('/debug');
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_webViewController != null && _loadError == null)
            WebViewWidget(controller: _webViewController!),

          // Diagnostic Alert Banner for blank screen or unhandled errors
          if (_hasBlankScreenWarning && !_isLoading && _loadError == null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 20,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFF1E293B),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 22),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Cảnh báo WebView',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              'Màn hình có thể bị trắng hoặc chưa mount được React DOM.',
                              style: TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF38BDF8),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: () => _openWebDebugModal(manifest),
                        child: const Text('DEBUG NGAY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => setState(() => _hasBlankScreenWarning = false),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          if (_isLoading)
            Container(
              color: Colors.white,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Đang khởi tạo Mini App Runtime...',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),

          if (_loadError != null)
            Container(
              color: Colors.white,
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
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _isLoading = true;
                          _loadError = null;
                        });
                        _initMiniApp();
                      },
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
