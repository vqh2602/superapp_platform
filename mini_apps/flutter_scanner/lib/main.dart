import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'bridge/superapp_bridge.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ScannerApp());
}

class ScannerApp extends StatelessWidget {
  const ScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Scanner (Flutter Web)',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF0068FF),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 1,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
          iconTheme: IconThemeData(color: Color(0xFF0F172A)),
        ),
      ),
      home: const ScannerHomeScreen(),
    );
  }
}

class ScanRecord {
  final String id;
  final String content;
  final String format;
  final DateTime timestamp;

  ScanRecord({
    required this.id,
    required this.content,
    required this.format,
    required this.timestamp,
  });

  bool get isUrl => content.startsWith('http://') || content.startsWith('https://');
}

class ScannerHomeScreen extends StatefulWidget {
  const ScannerHomeScreen({super.key});

  @override
  State<ScannerHomeScreen> createState() => _ScannerHomeScreenState();
}

class _ScannerHomeScreenState extends State<ScannerHomeScreen> {
  bool _isBridgeConnected = false;
  bool _isScanning = false;
  ScanRecord? _lastScan;
  final List<ScanRecord> _history = [];
  Map<String, dynamic>? _batteryInfo;
  Map<String, dynamic>? _networkInfo;

  @override
  void initState() {
    super.initState();
    _checkBridge();
  }

  void _checkBridge() {
    final available = SuperAppBridge.isAvailable();
    setState(() {
      _isBridgeConnected = available;
    });

    if (available) {
      _loadQuickDiagnostics();
    }
  }

  Future<void> _loadQuickDiagnostics() async {
    try {
      final battery = await SuperAppBridge.getBatteryInfo();
      final network = await SuperAppBridge.getNetworkInfo();
      if (mounted) {
        setState(() {
          _batteryInfo = battery;
          _networkInfo = network;
        });
      }
    } catch (_) {}
  }

  Future<void> _handleScanQr() async {
    if (_isScanning) return;
    setState(() => _isScanning = true);

    try {
      await SuperAppBridge.vibrate('light');
      final result = await SuperAppBridge.scanQr(prompt: 'Hướng camera vào mã QR hoặc mã vạch');

      final content = result['content']?.toString() ?? '';
      final format = result['format']?.toString() ?? 'QR_CODE';

      if (content.isNotEmpty) {
        final record = ScanRecord(
          id: 'scan_${DateTime.now().millisecondsSinceEpoch}',
          content: content,
          format: format,
          timestamp: DateTime.now(),
        );

        setState(() {
          _lastScan = record;
          _history.insert(0, record);
        });

        await SuperAppBridge.vibrate('medium');
        await SuperAppBridge.showToast('Quét mã thành công!');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi quét mã: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _handlePickImage() async {
    try {
      await SuperAppBridge.vibrate('light');
      final result = await SuperAppBridge.chooseImage();
      final paths = (result['tempFilePaths'] as List?)?.cast<String>() ?? [];
      if (paths.isNotEmpty) {
        await SuperAppBridge.showToast('Đã chọn ${paths.length} ảnh từ thư viện');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  Future<void> _copyResult(String text) async {
    try {
      await SuperAppBridge.copyToClipboard(text);
      await Clipboard.setData(ClipboardData(text: text));
      await SuperAppBridge.showToast('Đã sao chép mã vào bộ nhớ tạm');
      await SuperAppBridge.vibrate('light');
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã sao chép vào bộ nhớ tạm')),
        );
      }
    }
  }

  Future<void> _openLink(String url) async {
    try {
      await SuperAppBridge.openExternalUrl(url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể mở liên kết: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('HH:mm:ss - dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF0068FF), size: 22),
            SizedBox(width: 8),
            Text('Flutter Scanner (Flutter Web)'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Đóng Mini App',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => SuperAppBridge.closeApp(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // 1. Connection Status Banner
          _buildStatusBanner(),
          const SizedBox(height: 16),

          // 2. Main Scan Trigger Box
          _buildScannerCard(),
          const SizedBox(height: 16),

          // 3. Scan Result Display
          if (_lastScan != null) ...[
            _buildResultCard(_lastScan!, dateFormat),
            const SizedBox(height: 16),
          ],

          // 4. Quick Device Diagnostics (Bridge Verification)
          _buildDiagnosticsCard(),
          const SizedBox(height: 16),

          // 5. Scan History List
          _buildHistorySection(dateFormat),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _isBridgeConnected ? const Color(0xFFEFF6FF) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isBridgeConnected ? const Color(0xFFBFDBFE) : const Color(0xFFFECACA),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isBridgeConnected ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
            color: _isBridgeConnected ? const Color(0xFF0068FF) : const Color(0xFFEF4444),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isBridgeConnected
                      ? 'SuperApp Native Bridge: Đã kết nối'
                      : 'SuperApp Native Bridge: Chưa phát hiện',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _isBridgeConnected ? const Color(0xFF1E3A8A) : const Color(0xFF991B1B),
                  ),
                ),
                Text(
                  _isBridgeConnected
                      ? 'Ứng dụng Flutter Web đang chạy trong Web Container'
                      : 'Chạy độc lập trên trình duyệt web thường',
                  style: TextStyle(
                    fontSize: 11,
                    color: _isBridgeConnected ? const Color(0xFF3B82F6) : const Color(0xFFB91C1C),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 18),
            onPressed: _checkBridge,
            tooltip: 'Kiểm tra lại kết nối',
          ),
        ],
      ),
    );
  }

  Widget _buildScannerCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0068FF), Color(0xFF02569B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0068FF).withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.qr_code_2_rounded,
              color: Colors.white,
              size: 42,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Quét Mã QR & Mã Vạch',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Sử dụng Camera Native phần cứng thông qua SuperApp JavaScript Bridge',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isScanning ? null : _handleScanQr,
              icon: _isScanning
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Color(0xFF0068FF), strokeWidth: 2),
                    )
                  : const Icon(Icons.camera_alt_rounded, size: 20),
              label: Text(
                _isScanning ? 'Đang mở máy quét...' : 'MỞ MÁY QUÉT CAMERA',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0068FF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton.icon(
              onPressed: _handlePickImage,
              icon: const Icon(Icons.photo_library_rounded, size: 18),
              label: const Text(
                'Chọn ảnh từ thư viện',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.6)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(ScanRecord record, DateFormat format) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF10B981)),
                    const SizedBox(width: 4),
                    Text(
                      record.format.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF047857),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                format.format(record.timestamp),
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Nội dung quét được:',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: SelectableText(
              record.content,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => _copyResult(record.content),
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Sao chép'),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              if (record.isUrl) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _openLink(record.content),
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('Mở link'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0068FF),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.hub_rounded, size: 16, color: Color(0xFF0068FF)),
              SizedBox(width: 6),
              Text(
                'Thông số phần cứng thiết bị (via SuperApp Bridge)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildInfoTile(
                  icon: Icons.battery_charging_full_rounded,
                  label: 'Pin',
                  value: _batteryInfo != null ? '${_batteryInfo!['level']}%' : 'Đang đọc...',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildInfoTile(
                  icon: Icons.wifi_rounded,
                  label: 'Mạng',
                  value: _networkInfo != null
                      ? (_networkInfo!['networkType']?.toString().toUpperCase() ?? 'NONE')
                      : 'Đang đọc...',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({required IconData icon, required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF64748B)),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
              Text(
                value,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection(DateFormat format) {
    if (_history.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(Icons.history_rounded, size: 36, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              'Chưa có lịch sử quét mã',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Lịch sử quét (${_history.length})',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _history.clear()),
              child: const Text('Xoá tất cả', style: TextStyle(fontSize: 12, color: Color(0xFFEF4444))),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ..._history.map((item) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: ListTile(
                dense: true,
                leading: Icon(
                  item.isUrl ? Icons.link_rounded : Icons.qr_code_rounded,
                  color: const Color(0xFF0068FF),
                ),
                title: Text(
                  item.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${item.format} • ${format.format(item.timestamp)}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  onPressed: () => _copyResult(item.content),
                ),
              ),
            )),
      ],
    );
  }
}
