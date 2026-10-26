import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../domain/mock_order.dart';

class MockOrderRepository {
  final _uuid = const Uuid();
  final Map<String, MockOrder> _orders = {};

  MockOrder createOrder({
    required double amount,
    required String description,
    required String appId,
    required String userId,
    String currency = 'VND',
  }) {
    final orderId = 'ORD_${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4().substring(0, 6).toUpperCase()}';
    final order = MockOrder(
      orderId: orderId,
      amount: amount,
      currency: currency,
      description: description,
      appId: appId,
      userId: userId,
      createdAt: DateTime.now(),
      status: OrderStatus.pending,
    );

    _orders[orderId] = order;
    return order;
  }

  MockOrder? getOrder(String orderId) => _orders[orderId];

  MockOrder updateOrderStatus(
    String orderId,
    OrderStatus status, {
    String paymentMethod = 'SUPERAPP_WALLET',
  }) {
    final order = _orders[orderId];
    if (order == null) {
      throw Exception('Order not found: $orderId');
    }

    order.status = status;
    order.completedAt = DateTime.now();
    order.paymentMethod = paymentMethod;
    return order;
  }

  List<MockOrder> getAllOrders() => List.unmodifiable(_orders.values.toList());

  void reset() {
    _orders.clear();
  }
}

final mockOrderRepositoryProvider = Provider<MockOrderRepository>((ref) {
  return MockOrderRepository();
});
