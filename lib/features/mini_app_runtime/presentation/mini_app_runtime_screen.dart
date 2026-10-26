import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../authentication/presentation/controllers/auth_controller.dart';
import '../../debug_center/data/debug_log_repository.dart';
import '../../mini_app_catalog/data/mini_app_repository.dart';
import '../../mini_app_bridge/bridge_channel.dart';
import '../../mini_app_bridge/bridge_dispatcher.dart';
import '../../mini_app_bridge/bridge_event_emitter.dart';
import '../../native_actions/application/native_action_dispatcher.dart';
import '../../user_profile/data/mock_user_repository.dart';
import '../../device/data/mock_device_adapter.dart';
import '../../payment/data/mock_order_repository.dart';
import '../../permissions/data/mock_permission_repository.dart';
import '../../../../core/config/app_theme.dart';

class MiniAppRuntimeScreen extends ConsumerStatefulWidget {
  final String appId;

  const MiniAppRuntimeScreen({
    super.key,
    required this.appId,
  });

  @override
  ConsumerState<MiniAppRuntimeScreen> createState() => _MiniAppRuntimeScreenState();
}

class _MiniAppRuntimeScreenState extends ConsumerState<MiniAppRuntimeScreen> with WidgetsBindingObserver {
  late String _currentAppId;
  WebViewController? _webViewController;
  BridgeEventEmitter? _eventEmitter;
  bool _isLoading = true;
  String? _loadError;

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

  void _initMiniApp() {
    final manifest = ref.read(miniAppRepositoryProvider).getAppById(_currentAppId);
    if (manifest == null) {
      setState(() {
        _isLoading = false;
        _loadError = 'Mini App "$_currentAppId" không tồn tại trong danh mục';
      });
      return;
    }

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
      manifest: manifest,
    );

    final emitter = BridgeEventEmitter(controller);

    BridgeChannel.register(
      controller: controller,
      dispatcher: dispatcher,
      contextGetter: () => context,
    );

    controller.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (url) {
          controller.runJavaScript(BridgeChannel.bridgePolyfillScript);
        },
        onPageFinished: (url) {
          controller.runJavaScript(BridgeChannel.bridgePolyfillScript);
          setState(() {
            _isLoading = false;
          });
          emitter.emit('miniapp.ready', {'appId': manifest.id, 'version': manifest.version});
          emitter.emit('miniapp.show');
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

    // Load entry point
    if (manifest.isAsset) {
      controller.loadFlutterAsset(manifest.entryUrl);
    } else {
      controller.loadRequest(Uri.parse(manifest.entryUrl));
    }
  }

  @override
  Widget build(BuildContext context) {
    final manifest = ref.watch(miniAppRepositoryProvider).getAppById(_currentAppId);

    // Listen to session changes to notify Mini App if logged out
    ref.listen(authStateProvider, (prev, next) {
      if (!next.isAuthenticated && _eventEmitter != null) {
        _eventEmitter!.emitSessionChanged(state: 'logged_out');
      }
    });

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
          IconButton(
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
              _webViewController?.reload();
            },
          ),
          IconButton(
            tooltip: 'Bridge Logs',
            icon: const Icon(Icons.developer_mode_rounded),
            onPressed: () {
              Navigator.pushNamed(context, '/debug');
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_webViewController != null && _loadError == null)
            WebViewWidget(controller: _webViewController!),

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
                    const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text(
                      _loadError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
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
