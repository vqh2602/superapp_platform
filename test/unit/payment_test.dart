import 'package:flutter_test/flutter_test.dart';
import 'package:superapp_platform/features/payment/data/mock_order_repository.dart';
import 'package:superapp_platform/features/payment/domain/mock_order.dart';

void main() {
  group('MockOrderRepository Tests', () {
    late MockOrderRepository repo;

    setUp(() {
      repo = MockOrderRepository();
    });

    test('Creates order with pending status', () {
      final order = repo.createOrder(
        amount: 150000,
        description: 'Demo Purchase',
        appId: 'sdk_playground',
        userId: 'user_001',
      );

      expect(order.orderId.startsWith('ORD_'), isTrue);
      expect(order.amount, equals(150000));
      expect(order.status, equals(OrderStatus.pending));

      final retrieved = repo.getOrder(order.orderId);
      expect(retrieved, isNotNull);
      expect(retrieved?.orderId, equals(order.orderId));
    });

    test('Updates order status to success', () {
      final order = repo.createOrder(
        amount: 200000,
        description: 'Success Flow',
        appId: 'sdk_playground',
        userId: 'user_001',
      );

      final updated = repo.updateOrderStatus(order.orderId, OrderStatus.success);
      expect(updated.status, equals(OrderStatus.success));
      expect(updated.completedAt, isNotNull);
    });

    test('Updates order status to cancelled', () {
      final order = repo.createOrder(
        amount: 300000,
        description: 'Cancel Flow',
        appId: 'sdk_playground',
        userId: 'user_001',
      );

      final updated = repo.updateOrderStatus(order.orderId, OrderStatus.cancelled);
      expect(updated.status, equals(OrderStatus.cancelled));
    });
  });
}
