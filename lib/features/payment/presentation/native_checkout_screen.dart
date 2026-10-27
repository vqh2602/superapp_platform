import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../domain/mock_order.dart';
import '../data/mock_order_repository.dart';
import '../../../../core/config/app_theme.dart';

class NativeCheckoutScreen extends ConsumerStatefulWidget {
  final String orderId;
  final String miniAppName;

  const NativeCheckoutScreen({
    super.key,
    required this.orderId,
    this.miniAppName = 'Mini App',
  });

  @override
  ConsumerState<NativeCheckoutScreen> createState() => _NativeCheckoutScreenState();
}

class _NativeCheckoutScreenState extends ConsumerState<NativeCheckoutScreen> {
  final currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

  @override
  Widget build(BuildContext context) {
    final orderRepo = ref.watch(mockOrderRepositoryProvider);
    final order = orderRepo.getOrder(widget.orderId);

    if (order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Thanh toán')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text('Không tìm thấy đơn hàng: ${widget.orderId}'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, {'status': 'NOT_FOUND'}),
                child: const Text('Quay lại'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cổng thanh toán Native'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _handleAction(OrderStatus.cancelled),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // App badge
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Text(
                        'Đơn hàng từ: ${widget.miniAppName}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E40AF),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Amount
                  Center(
                    child: Text(
                      currencyFormatter.format(order.amount),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Order Details Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Chi tiết đơn hàng',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const Divider(height: 20),
                          _buildRow('Mã đơn:', order.orderId),
                          _buildRow('Nội dung:', order.description),
                          _buildRow('Thời gian tạo:', DateFormat('HH:mm:ss dd/MM/yyyy').format(order.createdAt)),
                          _buildRow('Tiền tệ:', order.currency),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Mock payment notice
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.shield_outlined, color: Color(0xFFD97706), size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Môi trường Sandbox/Mock: Chọn một trong 3 kịch bản kiểm thử dưới đây để hoàn tất luồng.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Action Buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _handleAction(OrderStatus.success),
                    icon: const Icon(Icons.check_circle_rounded),
                    label: const Text('Thanh toán thành công (Success)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () => _handleAction(OrderStatus.failed),
                    icon: const Icon(Icons.error_outline_rounded),
                    label: const Text('Thanh toán thất bại (Failure)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.danger,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => _handleAction(OrderStatus.cancelled),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Hủy thanh toán (Cancel)'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
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

  void _handleAction(OrderStatus status) async {
    final orderRepo = ref.read(mockOrderRepositoryProvider);
    final updated = await orderRepo.updateOrderStatus(widget.orderId, status);
    if (mounted) {
      Navigator.pop(context, updated.toJson());
    }
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
