import 'dart:convert';
import 'package:flutter/foundation.dart';
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

  Future<void> _safeRunScript(WebViewController? controller, String script) async {
    if (controller == null) return;
    try {
      await controller.runJavaScript(script);
    } catch (e) {
      debugPrint('[MiniApp Runtime] Ignored runJavaScript limitation: $e');
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
          if (!kIsWeb) {
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
          await _safeRunScript(controller, BridgeChannel.webDebugPolyfillScript);
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
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
          emitter.emit('miniapp.ready', {
            'appId': validManifest.id,
            'version': validManifest.version,
          });
          emitter.emit('miniapp.show');

          // Check if root element mounted
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

    if (mounted) {
      setState(() {
        _webViewController = controller;
        _eventEmitter = emitter;
      });
    } else {
      _webViewController = controller;
      _eventEmitter = emitter;
    }

    // Load entry point based on runtime type
    if (validManifest.isSchemaApp) {
      controller.loadFlutterAsset('assets/mini_apps/schema_runtime/index.html');
    } else if (validManifest.isAsset) {
      controller.loadFlutterAsset(validManifest.entryUrl);
    } else {
      controller.loadRequest(Uri.parse(validManifest.entryUrl));
    }

    Future.delayed(const Duration(milliseconds: kIsWeb ? 1200 : 3000), () {
      if (mounted && _isLoading && _loadError == null) {
        setState(() {
          _isLoading = false;
        });
        emitter.emit('miniapp.ready', {
          'appId': validManifest.id,
          'version': validManifest.version,
        });
        emitter.emit('miniapp.show');
      }
    });
  }

  void _showMiniAppInfoDialog(MiniAppManifest? manifest) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF00BA52).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.info_outline_rounded, color: Color(0xFF00BA52), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  manifest?.name ?? 'Thông tin Mini App',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInfoRow('Mã ứng dụng (ID)', manifest?.id ?? _currentAppId),
                _buildInfoRow('Phiên bản', 'v${manifest?.version ?? "1.0.0"}'),
                _buildInfoRow('Loại Runtime', manifest?.isSchemaApp == true ? 'No-Code Schema' : 'Web View App'),
                _buildInfoRow('Danh mục', manifest?.category ?? 'Chung'),
                const SizedBox(height: 8),
                const Text('Mô tả:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569))),
                const SizedBox(height: 2),
                Text(
                  manifest?.description ?? 'Chưa có mô tả chi tiết.',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 12),
                const Text('Quyền truy cập (Capabilities):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569))),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: (manifest?.capabilities ?? ['navigation.close']).map((c) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(c, style: const TextStyle(fontSize: 10, color: Color(0xFF334155), fontFamily: 'monospace')),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _isLoading = true;
                  _hasBlankScreenWarning = false;
                });
                _webViewController?.reload();
              },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Tải lại'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.push('/debug');
              },
              child: const Text('Debug Logs'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BA52),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Đóng'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final manifest = ref
        .watch(miniAppRepositoryProvider)
        .getAppById(_currentAppId);

    ref.listen(authStateProvider, (prev, next) {
      if (!next.isAuthenticated && _eventEmitter != null) {
        _eventEmitter!.emitSessionChanged(state: 'logged_out');
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // WeChat-style Mini Program Top Navigation Bar (Circled in red in Image 4)
            Container(
              height: 48,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Color(0xFFEEEEEE), width: 0.8),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Center Title
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 90),
                      child: Text(
                        manifest?.name ?? 'Mini App',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),

                  // Right Capsule Bar: [ ••• | ⊙ ]
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFD1D5DB), width: 0.8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
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
                            onTap: () => _showMiniAppInfoDialog(manifest),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              bottomLeft: Radius.circular(16),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              child: Icon(
                                Icons.more_horiz_rounded,
                                size: 20,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          // Capsule Divider
                          Container(
                            width: 0.8,
                            height: 16,
                            color: const Color(0xFFE5E7EB),
                          ),
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
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              child: Icon(
                                Icons.adjust_rounded,
                                size: 18,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Mini App Content: Full Screen, Edge-to-Edge (No white margins on left/right)
            Expanded(
              child: Stack(
                children: [
                  if (_webViewController != null && _loadError == null)
                    SizedBox(
                      width: double.infinity,
                      height: double.infinity,
                      child: WebViewWidget(controller: _webViewController!),
                    ),

                  // Diagnostic Alert Banner for blank screen
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
                                child: Text(
                                  'Màn hình có thể bị trắng hoặc chưa mount được React DOM.',
                                  style: TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.white54, size: 16),
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
                            CircularProgressIndicator(
                              color: Color(0xFF00BA52),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Đang khởi tạo Mini App...',
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
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00BA52),
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }
}
