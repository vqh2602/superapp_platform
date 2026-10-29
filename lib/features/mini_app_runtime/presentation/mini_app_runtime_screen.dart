import 'dart:convert';
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
import '../../user_profile/data/mock_user_repository.dart';
import '../../device/data/mock_device_adapter.dart';
import '../../permissions/data/mock_permission_repository.dart';
import '../../storage/data/mock_secure_storage_repository.dart';
import '../../native_actions/domain/mini_app_ui_delegate.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../domain/web_log_entry.dart';
import 'widgets/mini_app_action_bottom_sheet.dart';
import '../../../../core/animations/app_motion.dart';
import '../../../../core/config/debug_mode_provider.dart';
import '../../../../core/config/endpoint_config.dart';

class MiniAppRuntimeScreen extends ConsumerStatefulWidget {
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
  WebViewController? _webViewController;
  BridgeEventEmitter? _eventEmitter;
  bool _isLoading = true;
  int _loadProgress = 15;
  String? _loadError;
  final List<WebLogEntry> _webLogs = [];
  bool _hasBlankScreenWarning = false;

  // Dynamic UI & Container state from configAppView / setNavigationBarTitle / setNavigationBarColor
  String? _overrideTitle;
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
    if (_isKeepScreenOn) {
      try {
        WakelockPlus.disable();
      } catch (_) {}
    }
    try {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    } catch (_) {}
    _eventEmitter?.emit('miniapp.close');
    super.dispose();
  }

  @override
  void setTitle(String title) {
    if (mounted) {
      setState(() {
        _overrideTitle = title;
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
  }) {
    if (mounted) {
      setState(() {
        if (headerColor != null) _overrideHeaderColor = headerColor;
        if (headerTitle != null) _overrideTitle = headerTitle;
        if (textColor != null) _overrideTextColor = textColor;
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

  Future<void> _safeRunScript(WebViewController? controller, String script) async {
    if (controller == null) return;
    try {
      await controller.runJavaScript(script);
    } catch (e) {
      debugPrint('[MiniApp Runtime] Ignored runJavaScript limitation: $e');
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

  Future<void> _initMiniApp() async {
    setState(() {
      _hasBlankScreenWarning = false;
      _isLoading = true;
      _loadProgress = 15;
    });

    // Revalidate visibility, active version and current grants on every launch.
    final manifest = await ref
        .read(miniAppRepositoryProvider)
        .fetchRemoteManifest(_currentAppId);
    if (!mounted) return;

    if (manifest == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadProgress = 0;
        _loadError = 'Mini App "$_currentAppId" không tồn tại hoặc chưa được publish';
      });
      return;
    }

    final validManifest = manifest;
    if (mounted) {
      setState(() {
        if (_loadProgress < 30) _loadProgress = 30;
      });
    }
    final themeHex = validManifest.schema?['theme']?['backgroundColor'] as String?;
    final themeBg = _parseColor(themeHex, defaultColor: Colors.white);

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(themeBg);

    final endpoint = ref.read(backendEndpointProvider);
    final actionDispatcher = NativeActionDispatcher(
      authRepo: ref.read(mockAuthRepositoryProvider),
      authCodeService: ref.read(mockAuthCodeServiceProvider),
      tokenService: ref.read(mockTokenServiceProvider),
      userRepo: ref.read(mockUserRepositoryProvider),
      deviceAdapter: ref.read(deviceAdapterProvider),
      permissionRepo: ref.read(mockPermissionRepositoryProvider),
      debugLogRepo: ref.read(debugLogRepositoryProvider),
      secureStorageRepo: ref.read(mockSecureStorageRepositoryProvider),
      miniappUrl: endpoint.miniappUrl,
      authUrl: endpoint.authUrl,
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
      uiDelegate: this,
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

    controller.setNavigationDelegate(
      NavigationDelegate(
        onProgress: (int progress) {
          if (mounted) {
            setState(() {
              _loadProgress = progress.clamp(15, 100);
            });
          }
        },
        onPageStarted: (url) {
          if (mounted) {
            setState(() {
              if (_loadProgress < 35) _loadProgress = 35;
            });
          }
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
          await _safeRunScript(controller, resetScript);
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
              _loadProgress = 100;
            });
          }
          await Future.delayed(const Duration(milliseconds: 220));
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

    // Load entry point: remote Backend URL is the primary runtime loader
    if (validManifest.isAsset && validManifest.entryUrl.startsWith('assets/') && !validManifest.entryUrl.startsWith('assets/mini_apps/')) {
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
        targetUri = '${EndpointConfig.alwaysdataEndpoint}/api/v1/miniapps/$targetApp/${validManifest.version}/dist/index.html';
      }
      controller.loadRequest(Uri.parse(targetUri));
    }

    Future.delayed(const Duration(milliseconds: kIsWeb ? 1200 : 3000), () {
      if (mounted && _isLoading && _loadError == null) {
        setState(() {
          _loadProgress = 100;
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

  void _showMiniAppActionBottomSheet(MiniAppManifest? manifest) {
    MiniAppActionBottomSheet.show(
      context,
      manifest: manifest,
      appId: _currentAppId,
      onReload: () {
        setState(() {
          _isLoading = true;
          _hasBlankScreenWarning = false;
        });
        _webViewController?.reload();
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
    final headerTextColor = isDarkHeader ? Colors.white : const Color(0xFF0F172A);
    final displayTitle = _overrideTitle ?? manifest?.name ?? 'Mini App';

    Color brandColor;
    final themePrimaryHex = manifest?.schema?['theme']?['primaryColor'] as String? ??
        manifest?.schema?['theme']?['accentColor'] as String?;
    if (themePrimaryHex != null && themePrimaryHex.isNotEmpty) {
      brandColor = _parseColor(themePrimaryHex, defaultColor: const Color(0xFF2563EB));
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
          brandColor = isDarkTheme ? const Color(0xFFF59E0B) : const Color(0xFF00BA52);
      }
    }

    ref.listen(authStateProvider, (prev, next) {
      if (!next.isAuthenticated && _eventEmitter != null) {
        _eventEmitter!.emitSessionChanged(state: 'logged_out');
      }
    });

    final safeTopInset = MediaQuery.of(context).padding.top;
    final safeBottomInset = MediaQuery.of(context).padding.bottom;
    final bool enableSafeAreaTop = _hasPaddingTop && _hasPadding;
    final bool enableSafeAreaBottom = _hasPaddingBottom && _hasPadding;

    final isHeaderTransparent = headerBgColor == Colors.transparent ||
        headerBgColor.a < 0.95 ||
        _statusBarStyle == 'transparent';
    const headerBarHeight = 48.0;
    final totalHeaderHeight = (_isStatusBarHidden ? 0.0 : safeTopInset) + headerBarHeight;

    // Effective background tint for frosted glass / transparent header
    final effectiveHeaderBgColor = headerBgColor == Colors.transparent
        ? (isDarkHeader
            ? Colors.black.withValues(alpha: 0.3)
            : Colors.white.withValues(alpha: 0.65))
        : (isHeaderTransparent ? headerBgColor.withValues(alpha: 0.8) : headerBgColor);

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
    final contentTop = (isHeaderTransparent || !enableSafeAreaTop || _isActionBarHidden)
        ? (enableSafeAreaTop && !_isStatusBarHidden ? safeTopInset : 0.0)
        : totalHeaderHeight;
    final contentBottom = enableSafeAreaBottom ? safeBottomInset : 0.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: statusBarColor,
        statusBarIconBrightness: statusBarIconBrightness,
        statusBarBrightness: statusBarBrightness,
        systemNavigationBarColor: _bottomNavColor ?? (_hideBottomNav ? Colors.transparent : null),
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
                  if (ref.watch(isDebugModeEnabledProvider) && _hasBlankScreenWarning && !_isLoading && _loadError == null)
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
                                color: isDarkTheme ? Colors.white : const Color(0xFF0F172A),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _isLoading = true;
                                  _loadError = null;
                                  _initMiniApp();
                                });
                              },
                              child: const Text('Thử lại'),
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
          Container(
            width: 0.8,
            height: 16,
            color: capsuleDividerColor,
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
          // Center Title (dynamically updated by configAppView or setTitle)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 90),
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
          ),

          // Right Capsule Bar: [ ••• | ⊙ ] (Host-Controlled, Cannot be removed or edited)
          Align(
            alignment: Alignment.centerRight,
            child: capsuleButton,
          ),
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
    if (iconName == 'video' || iconName == 'movie' || appId == 'capcut' || appId == 'youtube') {
      fallbackIcon = Icons.movie_filter_rounded;
    } else if (iconName == 'games' || iconName == 'game' || appId == 'free_fire') {
      fallbackIcon = Icons.sports_esports_rounded;
    } else if (iconName == 'social' || iconName == 'chat' || appId == 'messenger') {
      fallbackIcon = Icons.chat_bubble_rounded;
    } else if (iconName == 'shopping' || iconName == 'cart' || appId == 'shopee') {
      fallbackIcon = Icons.shopping_bag_rounded;
    } else if (iconName == 'coffee' || iconName == 'storefront' || appId == 'sample_store' || appId == 'coffee_shop') {
      fallbackIcon = Icons.coffee_rounded;
    } else if (iconName == 'code' || iconName == 'terminal' || appId == 'sdk_playground') {
      fallbackIcon = Icons.code_rounded;
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
                errorBuilder: (_, __, ___) => Icon(
                  fallbackIcon,
                  size: 40,
                  color: Colors.white,
                ),
              )
            : Icon(
                fallbackIcon,
                size: 40,
                color: Colors.white,
              ),
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
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: _loadProgress.toDouble()),
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) {
            final percent = value.clamp(0, 100).toInt();
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
                  width: 160,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isDarkTheme ? Colors.white12 : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: (value / 100.0).clamp(0.0, 1.0),
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
                const SizedBox(height: 12),
                Text(
                  percent >= 100
                      ? 'Đang khởi chạy...'
                      : (percent > 60
                          ? 'Đang nạp tài nguyên...'
                          : 'Đang tải Mini App...'),
                  style: TextStyle(
                    color: isDarkTheme ? Colors.white60 : const Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
