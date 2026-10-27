import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../../../../core/config/endpoint_config.dart';
import '../../authentication/data/mock_auth_repository.dart';
import '../../authentication/presentation/controllers/auth_controller.dart';
import '../domain/mock_order.dart';

class MockOrderRepository {
  final http.Client? httpClient;
  final String? ordersUrl;
  final MockAuthRepository? authRepo;

  final _uuid = const Uuid();
  final Map<String, MockOrder> _orders = {};

  MockOrderRepository({
    this.httpClient,
    this.ordersUrl,
    this.authRepo,
  });

  Future<MockOrder> createOrder({
    required double amount,
    required String description,
    required String appId,
    required String userId,
    String currency = 'VND',
  }) async {
    final ordersUrl = this.ordersUrl;
    final session = authRepo?.currentSession;
    if (ordersUrl != null &&
        session != null &&
        session.accessToken.isNotEmpty &&
        !session.accessToken.startsWith('master_mock_')) {
      try {
        final client = httpClient ?? http.Client();
        final url = Uri.parse(ordersUrl);
        final response = await client
            .post(
              url,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ${session.accessToken}',
              },
              body: jsonEncode({
                'appId': appId,
                'amount': amount,
                'description': description,
                'currency': currency,
              }),
            )
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 201) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final order = MockOrder(
            orderId: data['orderId'] as String,
            amount: (data['amount'] as num).toDouble(),
            currency: data['currency'] as String? ?? currency,
            description: data['description'] as String? ?? description,
            appId: data['appId'] as String? ?? appId,
            userId: data['userId'] as String? ?? userId,
            status: OrderStatus.fromString(data['status'] as String? ?? 'PENDING'),
            createdAt: DateTime.tryParse(data['createdAt'] as String? ?? '') ?? DateTime.now(),
          );
          _orders[order.orderId] = order;
          return order;
        }
      } catch (e) {
        debugPrint('[MockOrderRepository] Backend createOrder failed: $e, falling back to local');
      }
    }

    // Local / offline fallback
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

  Future<MockOrder> updateOrderStatus(
    String orderId,
    OrderStatus status, {
    String paymentMethod = 'SUPERAPP_WALLET',
  }) async {
    final order = _orders[orderId];
    if (order == null) {
      throw Exception('Order not found: $orderId');
    }

    final ordersUrl = this.ordersUrl;
    final session = authRepo?.currentSession;
    if (ordersUrl != null &&
        session != null &&
        session.accessToken.isNotEmpty &&
        !session.accessToken.startsWith('master_mock_')) {
      try {
        final client = httpClient ?? http.Client();
        final url = Uri.parse('$ordersUrl/$orderId/status');
        await client
            .patch(
              url,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ${session.accessToken}',
              },
              body: jsonEncode({
                'status': status.value,
                'paymentMethod': paymentMethod,
              }),
            )
            .timeout(const Duration(seconds: 4));
      } catch (e) {
        debugPrint('[MockOrderRepository] Backend updateOrderStatus failed: $e');
      }
    }

    order.status = status;
    order.completedAt = DateTime.now();
    order.paymentMethod = paymentMethod;
    return order;
  }

  Future<List<MockOrder>> fetchUserOrders() async {
    final ordersUrl = this.ordersUrl;
    final session = authRepo?.currentSession;
    if (ordersUrl != null &&
        session != null &&
        session.accessToken.isNotEmpty &&
        !session.accessToken.startsWith('master_mock_')) {
      try {
        final client = httpClient ?? http.Client();
        final url = Uri.parse(ordersUrl);
        final response = await client.get(
          url,
          headers: {
            'Authorization': 'Bearer ${session.accessToken}',
          },
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final list = jsonDecode(response.body) as List<dynamic>;
          final remoteOrders = <MockOrder>[];
          for (final item in list) {
            final data = item as Map<String, dynamic>;
            final order = MockOrder(
              orderId: data['orderId'] as String,
              amount: (data['amount'] as num).toDouble(),
              currency: data['currency'] as String? ?? 'VND',
              description: data['description'] as String? ?? '',
              appId: data['appId'] as String? ?? '',
              userId: data['userId'] as String? ?? '',
              status: OrderStatus.fromString(data['status'] as String? ?? 'PENDING'),
              createdAt: DateTime.tryParse(data['createdAt'] as String? ?? '') ?? DateTime.now(),
              completedAt: data['completedAt'] != null ? DateTime.tryParse(data['completedAt'] as String) : null,
              paymentMethod: data['paymentMethod'] as String?,
            );
            _orders[order.orderId] = order;
            remoteOrders.add(order);
          }
          return remoteOrders;
        }
      } catch (e) {
        debugPrint('[MockOrderRepository] fetchUserOrders failed: $e');
      }
    }

    return getAllOrders();
  }

  List<MockOrder> getAllOrders() => List.unmodifiable(_orders.values.toList());

  void reset() {
    _orders.clear();
  }
}

final mockOrderRepositoryProvider = Provider<MockOrderRepository>((ref) {
  final endpoint = ref.watch(backendEndpointProvider);
  final authRepo = ref.watch(mockAuthRepositoryProvider);
  return MockOrderRepository(
    ordersUrl: endpoint.ordersUrl,
    authRepo: authRepo,
  );
});
