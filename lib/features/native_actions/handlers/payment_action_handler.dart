import 'package:flutter/material.dart';
import '../../../../core/errors/bridge_error.dart';
import '../../authentication/data/mock_auth_repository.dart';
import '../../payment/data/mock_order_repository.dart';
import '../../payment/presentation/native_checkout_screen.dart';
import '../domain/action_definition.dart';
import '../domain/action_context.dart';

class PaymentCreateOrderHandler implements NativeActionHandler {
  final MockOrderRepository orderRepo;
  final MockAuthRepository authRepo;

  PaymentCreateOrderHandler({
    required this.orderRepo,
    required this.authRepo,
  });

  @override
  String get actionName => 'payment.createOrder';

  @override
  String? get requiredCapability => 'payment.createOrder';

  @override
  bool get requiresAuth => true;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    final amount = (payload['amount'] as num?)?.toDouble() ?? 50000.0;
    final description = payload['description'] as String? ?? 'Thanh toán đơn hàng Mini App';
    final currency = payload['currency'] as String? ?? 'VND';
    final user = authRepo.currentUser;

    if (user == null || !authRepo.isAuthenticated) {
      throw BridgeError.authRequired();
    }

    final order = await orderRepo.createOrder(
      amount: amount,
      description: description,
      appId: context.appId,
      userId: user.id,
      currency: currency,
    );

    return order.toJson();
  }
}

class PaymentOpenCheckoutHandler implements NativeActionHandler {
  final MockOrderRepository orderRepo;

  PaymentOpenCheckoutHandler({required this.orderRepo});

  @override
  String get actionName => 'payment.openCheckout';

  @override
  String? get requiredCapability => 'payment.openCheckout';

  @override
  bool get requiresAuth => true;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    final orderId = payload['orderId'] as String?;
    if (orderId == null || orderId.isEmpty) {
      throw BridgeError.invalidParams('orderId is required');
    }

    if (context.buildContext == null) {
      throw BridgeError.internal('BuildContext is null');
    }

    final result = await Navigator.push<Map<String, dynamic>>(
      context.buildContext!,
      MaterialPageRoute(
        builder: (_) => NativeCheckoutScreen(
          orderId: orderId,
          miniAppName: context.manifest?.name ?? context.appId,
        ),
      ),
    );

    return result ?? {
      'orderId': orderId,
      'status': 'CANCELLED',
      'message': 'Checkout cancelled by user',
    };
  }
}
