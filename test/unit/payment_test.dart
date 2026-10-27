import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:superapp_platform/features/authentication/data/mock_auth_repository.dart';
import 'package:superapp_platform/features/payment/data/mock_order_repository.dart';
import 'package:superapp_platform/features/payment/domain/mock_order.dart';

void main() {
  group('MockOrderRepository Tests', () {
    late MockOrderRepository repo;

    setUp(() {
      repo = MockOrderRepository();
    });

    test('Creates order with pending status', () async {
      final order = await repo.createOrder(
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

    test('Updates order status to success', () async {
      final order = await repo.createOrder(
        amount: 200000,
        description: 'Success Flow',
        appId: 'sdk_playground',
        userId: 'user_001',
      );

      final updated = await repo.updateOrderStatus(order.orderId, OrderStatus.success);
      expect(updated.status, equals(OrderStatus.success));
      expect(updated.completedAt, isNotNull);
    });

    test('Updates order status to cancelled', () async {
      final order = await repo.createOrder(
        amount: 300000,
        description: 'Cancel Flow',
        appId: 'sdk_playground',
        userId: 'user_001',
      );

      final updated = await repo.updateOrderStatus(order.orderId, OrderStatus.cancelled);
      expect(updated.status, equals(OrderStatus.cancelled));
    });
  });

  group('MockOrderRepository Backend HTTP Integration Tests', () {
    test('Calls Backend POST /api/v1/orders and parses response', () async {
      final mockClient = MockClient((request) async {
        if (request.method == 'POST' && request.url.path.endsWith('/orders')) {
          expect(request.headers['authorization'], equals('Bearer test_real_access_token'));
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['appId'], equals('shopee'));
          expect(body['amount'], equals(120000));

          return http.Response(
            jsonEncode({
              'orderId': 'ORD_BACKEND_99999',
              'amount': 120000,
              'currency': 'VND',
              'description': 'Order from Backend',
              'appId': 'shopee',
              'userId': 'real_user_id',
              'status': 'PENDING',
              'createdAt': '2026-10-27T10:00:00.000Z',
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final authClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'user': {
              'id': 'real_user_id',
              'email': 'alice@example.com',
              'displayName': 'Alice',
            },
            'accessToken': 'test_real_access_token',
            'refreshToken': 'refresh_token',
            'tokenType': 'Bearer',
            'expiresIn': 3600,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final authRepo = MockAuthRepository(
        httpClient: authClient,
        authUrl: 'http://localhost:3000/api/v1/auth',
      );

      // Real login to establish backend session
      await authRepo.login('alice@example.com', 'password123');

      final repo = MockOrderRepository(
        httpClient: mockClient,
        ordersUrl: 'http://localhost:3000/api/v1/orders',
        authRepo: authRepo,
      );

      final order = await repo.createOrder(
        amount: 120000,
        description: 'Order from Backend',
        appId: 'shopee',
        userId: 'real_user_id',
      );

      expect(order.orderId, equals('ORD_BACKEND_99999'));
      expect(order.amount, equals(120000));
      expect(order.status, equals(OrderStatus.pending));
    });
  });
}
