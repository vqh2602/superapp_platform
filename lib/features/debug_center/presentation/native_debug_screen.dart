import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/debug_log_repository.dart';
import '../domain/bridge_log_entry.dart';
import '../../authentication/presentation/controllers/auth_controller.dart';
import '../../permissions/data/mock_permission_repository.dart';
import '../../payment/data/mock_order_repository.dart';
import '../../device/data/mock_device_adapter.dart';

class NativeDebugScreen extends ConsumerStatefulWidget {
  const NativeDebugScreen({super.key});

  @override
  ConsumerState<NativeDebugScreen> createState() => _NativeDebugScreenState();
}

class _NativeDebugScreenState extends ConsumerState<NativeDebugScreen> {
  @override
  Widget build(BuildContext context) {
    final debugRepo = ref.watch(debugLogRepositoryProvider);
    final logs = debugRepo.logs;
    final deviceAdapter = ref.watch(deviceAdapterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bridge Debug Center'),
        actions: [
          IconButton(
            tooltip: 'Xóa logs',
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              setState(() {
                debugRepo.clear();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã xóa toàn bộ Bridge logs')),
              );
            },
          ),
          IconButton(
            tooltip: 'Reset Demo Data',
            icon: const Icon(Icons.refresh_rounded, color: Colors.amber),
            onPressed: () => _resetAllData(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Simulation Controls Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFFF1F5F9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MÔ PHỎNG LỖI / TRẠNG THÁI (SIMULATION)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('Simulate Timeout'),
                      selected: debugRepo.simulateTimeout,
                      onSelected: (val) => setState(() => debugRepo.simulateTimeout = val),
                    ),
                    FilterChip(
                      label: const Text('Simulate Unauthorized'),
                      selected: debugRepo.simulateUnauthorized,
                      onSelected: (val) => setState(() => debugRepo.simulateUnauthorized = val),
                    ),
                    FilterChip(
                      label: const Text('Simulate Denied'),
                      selected: debugRepo.simulatePermissionDenied,
                      onSelected: (val) => setState(() => debugRepo.simulatePermissionDenied = val),
                    ),
                    FilterChip(
                      label: const Text('Simulate Native Failure'),
                      selected: debugRepo.simulateNativeFailure,
                      onSelected: (val) => setState(() => debugRepo.simulateNativeFailure = val),
                    ),
                    FilterChip(
                      label: const Text('Real Device Mode'),
                      selected: deviceAdapter.useRealDeviceMode,
                      onSelected: (val) => setState(() => deviceAdapter.useRealDeviceMode = val),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Log list
          Expanded(
            child: logs.isEmpty
                ? const Center(
                    child: Text(
                      'Chưa có bridge request nào được ghi nhận.\nHãy mở Mini App và thực hiện các tính năng demo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF94A3B8)),
                    ),
                  )
                : ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (ctx, idx) {
                      final log = logs[idx];
                      return _buildLogTile(log);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogTile(BridgeLogEntry log) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: ListTile(
        onTap: () => _showLogDetail(log),
        dense: true,
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: log.success ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            log.success ? Icons.check_circle_outline : Icons.error_outline,
            color: log.success ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
            size: 18,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                log.action,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            Text(
              '${log.executionTimeMs} ms',
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontFamily: 'monospace'),
            ),
          ],
        ),
        subtitle: Text(
          'ID: ${log.id} • ${log.timestamp.toLocal().toString().split(' ')[1].substring(0, 8)} • ${log.appId}',
          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
        ),
        trailing: const Icon(Icons.chevron_right, size: 18, color: Color(0xFFCBD5E1)),
      ),
    );
  }

  void _showLogDetail(BridgeLogEntry log) {
    final jsonStr = const JsonEncoder.withIndent('  ').convert(log.toJson());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    log.action,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 20),
                    tooltip: 'Sao chép JSON',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: jsonStr));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đã sao chép Log JSON')),
                      );
                    },
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SingleChildScrollView(
                    controller: controller,
                    child: Text(
                      jsonStr,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Color(0xFF38BDF8),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _resetAllData() {
    ref.read(mockAuthRepositoryProvider).reset();
    ref.read(mockAuthCodeServiceProvider).reset();
    ref.read(mockTokenServiceProvider).reset();
    ref.read(mockPermissionRepositoryProvider).reset();
    ref.read(mockOrderRepositoryProvider).reset();
    ref.read(debugLogRepositoryProvider).clear();
    ref.read(debugLogRepositoryProvider).resetSimulations();

    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã reset toàn bộ Mock Data và permissions')),
    );
  }
}
