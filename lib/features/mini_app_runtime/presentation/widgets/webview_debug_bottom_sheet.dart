import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:webview_all/webview_all.dart';
import '../../domain/web_log_entry.dart';

class WebViewDebugBottomSheet extends StatefulWidget {
  final WebViewController? controller;
  final List<WebLogEntry> logs;
  final VoidCallback onClearLogs;
  final String appId;
  final String appTitle;

  const WebViewDebugBottomSheet({
    super.key,
    required this.controller,
    required this.logs,
    required this.onClearLogs,
    required this.appId,
    required this.appTitle,
  });

  static void show(
    BuildContext context, {
    required WebViewController? controller,
    required List<WebLogEntry> logs,
    required ValueListenable<int> logsRevision,
    required VoidCallback onClearLogs,
    required String appId,
    required String appTitle,
  }) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ValueListenableBuilder<int>(
        valueListenable: logsRevision,
        builder: (context, revision, child) => PointerInterceptor(
          child: WebViewDebugBottomSheet(
            controller: controller,
            logs: logs,
            onClearLogs: onClearLogs,
            appId: appId,
            appTitle: appTitle,
          ),
        ),
      ),
    );
  }

  @override
  State<WebViewDebugBottomSheet> createState() =>
      _WebViewDebugBottomSheetState();
}

class _WebViewDebugBottomSheetState extends State<WebViewDebugBottomSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _logFilter = 'all'; // 'all', 'error', 'warn', 'log'
  String _searchQuery = '';

  // REPL State
  final TextEditingController _replController = TextEditingController();
  String? _replResult;
  bool _replRunning = false;
  bool _replIsError = false;

  // Inspector State
  bool _inspectorLoading = false;
  Map<String, dynamic> _inspectionData = {};

  // DOM Source State
  bool _domLoading = false;
  String? _domSource;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && _inspectionData.isEmpty) {
        _runInspection();
      } else if (_tabController.index == 3 && _domSource == null) {
        _loadDomSource();
      }
    });
    _runInspection();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _replController.dispose();
    super.dispose();
  }

  Future<void> _runInspection() async {
    if (widget.controller == null) return;
    setState(() {
      _inspectorLoading = true;
    });

    try {
      const inspectScript = '''
        (function() {
          var root = document.getElementById('root');
          var rootInfo = {
            exists: !!root,
            childElementCount: root ? root.childElementCount : 0,
            innerHTMLSnippet: root ? (root.innerHTML.substring(0, 300) + (root.innerHTML.length > 300 ? '...' : '')) : null,
            innerHTMLLength: root ? root.innerHTML.length : 0
          };
          var bridgeInfo = {
            superAppBridgeExists: typeof window.SuperAppBridge !== 'undefined',
            flutterBridgeExists: typeof window.FlutterBridge !== 'undefined',
            hasCallbacks: !!(window.SuperAppBridge && window.SuperAppBridge._callbacks),
            hasListeners: !!(window.SuperAppBridge && window.SuperAppBridge._listeners)
          };
          var schemaInfo = {
            schemaExists: typeof window.__MINIAPP_SCHEMA__ !== 'undefined',
            appId: window.__MINIAPP_APP_ID__ || null,
            schemaPagesCount: (window.__MINIAPP_SCHEMA__ && window.__MINIAPP_SCHEMA__.pages) ? window.__MINIAPP_SCHEMA__.pages.length : 0
          };
          return JSON.stringify({
            url: window.location.href,
            title: document.title,
            readyState: document.readyState,
            root: rootInfo,
            bridge: bridgeInfo,
            schema: schemaInfo,
            scriptsCount: document.querySelectorAll('script').length,
            errorsRecorded: (window.__WEBVIEW_LOGS__ || []).filter(function(e) { return e.level === 'error'; }).length
          });
        })()
      ''';

      final res = await widget.controller!.runJavaScriptReturningResult(
        inspectScript,
      );
      String rawJson = res.toString();
      // Handle string wrapped inside JSON from webview
      if (rawJson.startsWith('"') && rawJson.endsWith('"')) {
        rawJson = jsonDecode(rawJson);
      }
      final parsed = jsonDecode(rawJson) as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _inspectionData = parsed;
          _inspectorLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _inspectionData = {'error': e.toString()};
          _inspectorLoading = false;
        });
      }
    }
  }

  Future<void> _executeRepl(String code) async {
    if (widget.controller == null || code.trim().isEmpty) return;
    setState(() {
      _replRunning = true;
      _replResult = null;
      _replIsError = false;
    });

    try {
      final wrappedCode =
          '''
        (function() {
          try {
            var res = eval(${jsonEncode(code)});
            if (typeof res === 'object') {
              try { return JSON.stringify(res, null, 2); } catch(e) { return String(res); }
            }
            return String(res);
          } catch(err) {
            return 'ERROR: ' + (err.stack || err.message || err);
          }
        })()
      ''';

      final result = await widget.controller!.runJavaScriptReturningResult(
        wrappedCode,
      );
      var display = result.toString();
      if (display.startsWith('"') && display.endsWith('"')) {
        try {
          display = jsonDecode(display);
        } catch (_) {}
      }

      final isErr = display.startsWith('ERROR:');
      if (mounted) {
        setState(() {
          _replResult = display;
          _replIsError = isErr;
          _replRunning = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _replResult = 'Eval Exception: $e';
          _replIsError = true;
          _replRunning = false;
        });
      }
    }
  }

  Future<void> _simulateError(String type) async {
    if (widget.controller == null) return;
    String script;
    switch (type) {
      case 'type_error':
        script = '''
          (function() {
            try {
              var orderData = null;
              // Mô phỏng gọi hàm trên null/undefined
              orderData.calculateTotal();
            } catch(e) {
              console.error("[Mô phỏng TypeError]", e.name + ": " + e.message, "\\nStack Trace:\\n" + e.stack);
            }
          })();
        ''';
        break;
      case 'unhandled_rejection':
        script = '''
          (function() {
            setTimeout(function() {
              Promise.reject(new Error("Timeout khi gọi API /api/v1/sync sau 4000ms (Mô phỏng lỗi mạng)"));
            }, 50);
          })();
        ''';
        break;
      case 'syntax_error':
        script = '''
          (function() {
            try {
              eval("const brokenSyntax = ;");
            } catch(err) {
              console.error("[Mô phỏng SyntaxError]", err.name + ": " + err.message, "\\n" + err.stack);
            }
          })();
        ''';
        break;
      case 'bridge_failure':
        script =
            '''
          (function() {
            if (window.FlutterBridge && window.FlutterBridge.postMessage) {
              window.FlutterBridge.postMessage(JSON.stringify({
                id: 'sim_fail_' + Date.now(),
                action: 'debug.simulateFailure',
                payload: { type: 'permission_denied' },
                appId: '${widget.appId}'
              }));
            } else {
              console.warn('[Bridge] FlutterBridge not found');
            }
          })();
        ''';
        break;
      default:
        script =
            'console.error(new Error("[Mô phỏng lỗi] Custom runtime error"));';
    }

    try {
      await widget.controller!.runJavaScript(script);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Đã kích hoạt mô phỏng lỗi! Xem chi tiết trong danh sách logs.',
            ),
            duration: Duration(seconds: 2),
            backgroundColor: Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('[Simulate Error] Failed: $e');
    }
  }

  Future<void> _loadDomSource() async {
    if (widget.controller == null) return;
    setState(() {
      _domLoading = true;
    });

    try {
      final res = await widget.controller!.runJavaScriptReturningResult(
        'document.documentElement.outerHTML',
      );
      var source = res.toString();
      if (source.startsWith('"') && source.endsWith('"')) {
        try {
          source = jsonDecode(source);
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _domSource = source;
          _domLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _domSource = 'Failed to retrieve DOM source: $e';
          _domLoading = false;
        });
      }
    }
  }

  void _copyToClipboard(String text, String successMsg) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(successMsg),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final errorCount = widget.logs.where((l) => l.isError).length;
    final warnCount = widget.logs.where((l) => l.isWarning).length;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: errorCount > 0
                        ? Colors.red.withValues(alpha: 0.2)
                        : const Color(0xFF2563EB).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.terminal_rounded,
                    color: errorCount > 0
                        ? const Color(0xFFF87171)
                        : const Color(0xFF60A5FA),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'WebView Debug Inspector',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (errorCount > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$errorCount lỗi',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        '${widget.appTitle} (${widget.appId})',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Đóng',
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Tabs
          Container(
            color: const Color(0xFF1E293B),
            child: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF38BDF8),
              indicatorWeight: 3,
              labelColor: const Color(0xFF38BDF8),
              unselectedLabelColor: Colors.white60,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Console'),
                      if (errorCount > 0) ...[
                        const SizedBox(width: 4),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Tab(text: 'Inspector'),
                const Tab(text: 'JS REPL'),
                const Tab(text: 'DOM Source'),
              ],
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildConsoleTab(errorCount, warnCount),
                _buildInspectorTab(),
                _buildReplTab(),
                _buildDomSourceTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // TAB 1: CONSOLE LOGS
  Widget _buildConsoleTab(int errorCount, int warnCount) {
    final filteredLogs = widget.logs.where((l) {
      if (_logFilter == 'error' && !l.isError) return false;
      if (_logFilter == 'warn' && !l.isWarning) return false;
      if (_logFilter == 'log' && (l.isError || l.isWarning)) return false;
      if (_searchQuery.isNotEmpty) {
        return l.message.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (l.stack?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
                false);
      }
      return true;
    }).toList();

    return Column(
      children: [
        // Filter bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: const Color(0xFF131D31),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip(
                            'all',
                            'Tất cả (${widget.logs.length})',
                            null,
                          ),
                          const SizedBox(width: 6),
                          _buildFilterChip(
                            'error',
                            'Lỗi ($errorCount)',
                            Colors.red,
                          ),
                          const SizedBox(width: 6),
                          _buildFilterChip(
                            'warn',
                            'Cảnh báo ($warnCount)',
                            Colors.amber,
                          ),
                          const SizedBox(width: 6),
                          _buildFilterChip('log', 'Logs', Colors.blue),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  PopupMenuButton<String>(
                    tooltip: 'Mô phỏng lỗi',
                    icon: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.5),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bolt_rounded,
                            color: Colors.redAccent,
                            size: 14,
                          ),
                          SizedBox(width: 2),
                          Text(
                            'Test Lỗi',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    color: const Color(0xFF1E293B),
                    onSelected: (val) => _simulateError(val),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'type_error',
                        child: Row(
                          children: [
                            Text('💥 ', style: TextStyle(fontSize: 14)),
                            Expanded(
                              child: Text(
                                'TypeError (orderData.calculateTotal)',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'unhandled_rejection',
                        child: Row(
                          children: [
                            Text('⏱️ ', style: TextStyle(fontSize: 14)),
                            Expanded(
                              child: Text(
                                'Promise Rejection (Timeout)',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'syntax_error',
                        child: Row(
                          children: [
                            Text('⚠️ ', style: TextStyle(fontSize: 14)),
                            Expanded(
                              child: Text(
                                'Syntax / Parse Error',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'bridge_failure',
                        child: Row(
                          children: [
                            Text('🌉 ', style: TextStyle(fontSize: 14)),
                            Expanded(
                              child: Text(
                                'Native Bridge Error (Simulate)',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.copy_rounded,
                      color: Colors.white70,
                      size: 18,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    padding: const EdgeInsets.all(4),
                    tooltip: 'Sao chép toàn bộ logs',
                    onPressed: widget.logs.isEmpty
                        ? null
                        : () {
                            final allText = widget.logs
                                .map((l) {
                                  final st = l.stack != null
                                      ? '\n${l.stack}'
                                      : '';
                                  return '[${l.timestamp.toIso8601String()}] [${l.level.toUpperCase()}] ${l.message}$st';
                                })
                                .join('\n\n');
                            _copyToClipboard(
                              allText,
                              'Đã sao chép ${widget.logs.length} dòng logs',
                            );
                          },
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_sweep_rounded,
                      color: Colors.white70,
                      size: 18,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    padding: const EdgeInsets.all(4),
                    tooltip: 'Xóa sạch logs',
                    onPressed: () {
                      widget.onClearLogs();
                      setState(() {});
                    },
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Search input
              TextField(
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm trong logs...',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 12,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Colors.white54,
                    size: 16,
                  ),
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ],
          ),
        ),

        // Log entries list
        Expanded(
          child: filteredLogs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: Colors.white.withValues(alpha: 0.2),
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.logs.isEmpty
                            ? 'Chưa có log nào từ WebView'
                            : 'Không có log phù hợp bộ lọc',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filteredLogs.length,
                  itemBuilder: (ctx, index) {
                    final log = filteredLogs[index];
                    return _buildLogCard(log);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String key, String label, Color? dotColor) {
    final isSelected = _logFilter == key;
    return InkWell(
      onTap: () => setState(() => _logFilter = key),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogCard(WebLogEntry log) {
    Color badgeColor;
    Color borderColor;
    String badgeText;

    final isScriptErrorCensored =
        log.isError &&
        (log.message.contains('Script error') ||
            log.message == 'Script error.');

    if (log.isError) {
      badgeColor = Colors.red;
      borderColor = Colors.red.withValues(alpha: 0.4);
      badgeText = log.type == 'unhandledrejection' ? 'REJECTION' : 'ERROR';
    } else if (log.isWarning) {
      badgeColor = Colors.amber;
      borderColor = Colors.amber.withValues(alpha: 0.4);
      badgeText = 'WARN';
    } else {
      badgeColor = const Color(0xFF38BDF8);
      borderColor = const Color(0xFF334155);
      badgeText = log.level.toUpperCase();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}:${log.timestamp.second.toString().padLeft(2, '0')}.${log.timestamp.millisecond.toString().padLeft(3, '0')}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 11,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(
                  Icons.copy_rounded,
                  color: Colors.white54,
                  size: 14,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Copy',
                onPressed: () {
                  final text =
                      '${log.message}${log.stack != null ? '\n${log.stack}' : ''}';
                  _copyToClipboard(text, 'Đã sao chép log');
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          SelectableText(
            log.message,
            style: TextStyle(
              color: log.isError ? const Color(0xFFFCA5A5) : Colors.white,
              fontSize: 12,
              fontFamily: 'monospace',
              fontWeight: log.isError ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          if (isScriptErrorCensored) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF451A03),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFB45309)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: Color(0xFFF59E0B),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Chi tiết chẩn đoán WebKit CORS/file://',
                          style: TextStyle(
                            color: Color(0xFFFDE68A),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'WebKit trên iOS tự động thay thế chi tiết lỗi runtime của script tải từ file:// bằng chuỗi "Script error." để bảo mật. Hãy dùng tab JS REPL hoặc bọc code trong try...catch để unmask stack trace.',
                          style: TextStyle(
                            color: Color(0xFFFEF3C7),
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () => _tabController.animateTo(2),
                          child: const Text(
                            '👉 Chuyển sang JS REPL để test thử mã lỗi',
                            style: TextStyle(
                              color: Color(0xFF38BDF8),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (log.stack != null && log.stack!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.alt_route_rounded,
                        color: Color(0xFF94A3B8),
                        size: 13,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'CALL STACK / GỢI Ý',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    log.stack!,
                    style: const TextStyle(
                      color: Color(0xFFCBD5E1),
                      fontSize: 11,
                      fontFamily: 'monospace',
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // TAB 2: HEALTH & DOM INSPECTOR
  Widget _buildInspectorTab() {
    if (_inspectorLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
      );
    }

    if (_inspectionData.containsKey('error')) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
            const SizedBox(height: 8),
            Text(
              'Lỗi truy vấn WebView: ${_inspectionData['error']}',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _runInspection,
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }

    final root = _inspectionData['root'] as Map<String, dynamic>? ?? {};
    final bridge = _inspectionData['bridge'] as Map<String, dynamic>? ?? {};
    final schema = _inspectionData['schema'] as Map<String, dynamic>? ?? {};

    final rootExists = root['exists'] == true;
    final rootChildren = root['childElementCount'] ?? 0;
    final rootLength = root['innerHTMLLength'] ?? 0;
    final isRootRendered = rootExists && (rootChildren > 0 || rootLength > 0);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'TRẠNG THÁI RUNTIME (LIVE HEALTH)',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            TextButton.icon(
              icon: const Icon(
                Icons.refresh,
                size: 14,
                color: Color(0xFF38BDF8),
              ),
              label: const Text(
                'Cập nhật',
                style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12),
              ),
              onPressed: _runInspection,
            ),
          ],
        ),

        // Diagnostics Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isRootRendered
                ? const Color(0xFF064E3B).withValues(alpha: 0.3)
                : const Color(0xFF7F1D1D).withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isRootRendered ? const Color(0xFF059669) : Colors.red,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isRootRendered
                    ? Icons.check_circle_rounded
                    : Icons.warning_rounded,
                color: isRootRendered
                    ? const Color(0xFF34D399)
                    : const Color(0xFFF87171),
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isRootRendered
                          ? 'DOM & React đã mount thành công'
                          : 'Cảnh báo: #root đang trống!',
                      style: TextStyle(
                        color: isRootRendered
                            ? const Color(0xFF34D399)
                            : const Color(0xFFF87171),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isRootRendered
                          ? 'Đã phát hiện $rootChildren phần tử con trong #root (innerHTML: $rootLength ký tự).'
                          : 'Phần tử #root chưa có nội dung DOM. Có thể script gặp lỗi trước khi React.render hoàn tất.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        _buildSectionHeader('1. THÔNG TIN TRANG WEB & TÀI NGUYÊN'),
        _buildInfoTile('URL', _inspectionData['url']?.toString() ?? 'N/A'),
        _buildInfoTile(
          'Document Title',
          _inspectionData['title']?.toString() ?? 'N/A',
        ),
        _buildInfoTile(
          'ReadyState',
          _inspectionData['readyState']?.toString() ?? 'N/A',
        ),
        _buildInfoTile(
          'Thẻ <script> trong DOM',
          '${_inspectionData['scriptsCount'] ?? 0} thẻ',
        ),

        const SizedBox(height: 16),

        _buildSectionHeader('2. PHẦN TỬ GỐC (#root)'),
        _buildStatusTile('#root tồn tại trong DOM', rootExists),
        _buildInfoTile(
          'Số phần tử con (child elements)',
          '$rootChildren nodes',
        ),
        _buildInfoTile('Độ dài innerHTML', '$rootLength ký tự'),
        if (root['innerHTMLSnippet'] != null && rootLength > 0)
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              root['innerHTMLSnippet'].toString(),
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ),

        const SizedBox(height: 16),

        _buildSectionHeader('3. NATIVE BRIDGE CONNECTIVITY'),
        _buildStatusTile(
          'window.FlutterBridge (Native Channel)',
          bridge['flutterBridgeExists'] == true,
        ),
        _buildStatusTile(
          'window.SuperAppBridge (JS SDK Polyfill)',
          bridge['superAppBridgeExists'] == true,
        ),
        _buildStatusTile(
          'SuperAppBridge Callbacks Map',
          bridge['hasCallbacks'] == true,
        ),
        _buildStatusTile(
          'SuperAppBridge Listeners Map',
          bridge['hasListeners'] == true,
        ),

        const SizedBox(height: 16),

        _buildSectionHeader('4. NO-CODE SCHEMA STATE'),
        _buildStatusTile(
          'window.__MINIAPP_SCHEMA__ được nạp',
          schema['schemaExists'] == true,
        ),
        _buildInfoTile(
          'window.__MINIAPP_APP_ID__',
          schema['appId']?.toString() ?? 'null',
        ),
        _buildInfoTile(
          'Số trang trong Schema',
          '${schema['schemaPagesCount'] ?? 0} pages',
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF38BDF8),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTile(String label, bool isOk) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          Row(
            children: [
              Icon(
                isOk ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: isOk ? const Color(0xFF10B981) : Colors.red,
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                isOk ? 'OK' : 'MISSING',
                style: TextStyle(
                  color: isOk ? const Color(0xFF10B981) : Colors.red,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // TAB 3: JS CONSOLE REPL
  Widget _buildReplTab() {
    final snippets = [
      {'label': 'document.title', 'code': 'document.title'},
      {
        'label': '#root innerHTML',
        'code':
            'document.getElementById("root") ? document.getElementById("root").innerHTML.substring(0, 200) : "root not found"',
      },
      {'label': 'SuperAppBridge', 'code': 'typeof window.SuperAppBridge'},
      {'label': 'Schema Object', 'code': 'window.__MINIAPP_SCHEMA__'},
      {'label': 'User Agent', 'code': 'navigator.userAgent'},
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'QUICK SHORTCUTS:',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: snippets.map((s) {
              return ActionChip(
                backgroundColor: const Color(0xFF1E293B),
                label: Text(
                  s['label']!,
                  style: const TextStyle(
                    color: Color(0xFF38BDF8),
                    fontSize: 11,
                  ),
                ),
                onPressed: () {
                  _replController.text = s['code']!;
                  _executeRepl(s['code']!);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // Code input
          TextField(
            controller: _replController,
            maxLines: 3,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontFamily: 'monospace',
            ),
            decoration: InputDecoration(
              hintText: 'Nhập mã JavaScript (e.g. document.body.innerHTML)...',
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 12,
              ),
              filled: true,
              fillColor: const Color(0xFF1E293B),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF334155)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF38BDF8)),
              ),
            ),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                ),
                icon: _replRunning
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.play_arrow_rounded, size: 18),
                label: Text(
                  _replRunning ? 'Đang chạy...' : 'Chạy biểu thức (Eval)',
                ),
                onPressed: _replRunning
                    ? null
                    : () => _executeRepl(_replController.text),
              ),
              const Spacer(),
              if (_replResult != null)
                IconButton(
                  tooltip: 'Sao chép kết quả',
                  icon: const Icon(
                    Icons.copy_rounded,
                    color: Colors.white70,
                    size: 18,
                  ),
                  onPressed: () =>
                      _copyToClipboard(_replResult!, 'Đã sao chép kết quả'),
                ),
            ],
          ),

          const SizedBox(height: 12),
          const Text(
            'KẾT QUẢ THỰC THI (OUTPUT):',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),

          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _replIsError
                      ? Colors.red.withValues(alpha: 0.5)
                      : const Color(0xFF334155),
                ),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  _replResult ??
                      '// Nhập lệnh hoặc chọn shortcut bên trên để chạy.',
                  style: TextStyle(
                    color: _replResult == null
                        ? Colors.white30
                        : (_replIsError
                              ? const Color(0xFFF87171)
                              : const Color(0xFF38BDF8)),
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // TAB 4: DOM SOURCE
  Widget _buildDomSourceTab() {
    if (_domLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: const Color(0xFF131D31),
          child: Row(
            children: [
              Text(
                'Kích thước DOM: ${_domSource?.length ?? 0} ký tự',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(
                  Icons.refresh,
                  color: Colors.white70,
                  size: 18,
                ),
                tooltip: 'Tải lại DOM Source',
                onPressed: _loadDomSource,
              ),
              IconButton(
                icon: const Icon(
                  Icons.copy_rounded,
                  color: Colors.white70,
                  size: 18,
                ),
                tooltip: 'Sao chép toàn bộ HTML',
                onPressed: _domSource == null
                    ? null
                    : () => _copyToClipboard(
                        _domSource!,
                        'Đã sao chép HTML Source',
                      ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: const Color(0xFF0F172A),
            child: SingleChildScrollView(
              child: SelectableText(
                _domSource ?? 'Đang tải HTML Source...',
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
