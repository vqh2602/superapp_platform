import 'dart:async';
import '../../../../core/errors/bridge_error.dart';
import '../../payment/presentation/payment_checkout_bottom_sheet.dart';
import '../domain/action_definition.dart';
import '../domain/action_context.dart';

enum PaymentOrderStatus {
  pending,
  completed,
  cancelled,
  failed,
}

class PaymentOrder {
  final String orderId;
  final String appId;
  final double amount;
  final String currency;
  final String description;
  PaymentOrderStatus status;
  final DateTime createdAt;
  final Map<String, dynamic>? extraData;

  PaymentOrder({
    required this.orderId,
    required this.appId,
    required this.amount,
    required this.currency,
    required this.description,
    this.status = PaymentOrderStatus.pending,
    required this.createdAt,
    this.extraData,
  });

  Map<String, dynamic> toJson() => {
        'orderId': orderId,
        'appId': appId,
        'amount': amount,
        'currency': currency,
        'description': description,
        'status': status.name.toUpperCase(),
        'createdAt': createdAt.toIso8601String(),
        if (extraData != null) 'extraData': extraData,
      };
}

class PaymentOrderStore {
  final Map<String, PaymentOrder> _orders = {};
  final Map<String, Map<String, dynamic>> _transactions = {};

  void saveOrder(PaymentOrder order) {
    _orders[order.orderId] = order;
  }

  PaymentOrder? getOrder(String orderId) => _orders[orderId];

  void updateOrderStatus(String orderId, PaymentOrderStatus status) {
    final order = _orders[orderId];
    if (order != null) {
      order.status = status;
    }
  }

  void recordTransaction(String transactionId, Map<String, dynamic> data) {
    _transactions[transactionId] = data;
    final orderId = data['orderId'] as String?;
    if (orderId != null) {
      _transactions['order:$orderId'] = data;
    }
  }

  Map<String, dynamic>? getTransaction(String transactionId) {
    return _transactions[transactionId];
  }

  Map<String, dynamic>? getTransactionByOrderId(String orderId) {
    return _transactions['order:$orderId'];
  }

  void clear() {
    _orders.clear();
    _transactions.clear();
  }
}

class PaymentCreateOrderHandler implements NativeActionHandler {
  final PaymentOrderStore store;

  PaymentCreateOrderHandler({required this.store});

  @override
  String get actionName => 'payment.createOrder';

  @override
  String? get requiredCapability => 'payment.createOrder';

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    context.checkCancelled();

    final rawAmount = payload['amount'];
    final num? amount = rawAmount is num
        ? rawAmount
        : (rawAmount != null ? num.tryParse(rawAmount.toString()) : null);

    if (amount == null || amount <= 0) {
      throw BridgeError.invalidParams('Payment amount must be greater than 0');
    }

    final rawOrderId = payload['orderId'] as String?;
    final orderId = (rawOrderId != null && rawOrderId.trim().isNotEmpty)
        ? rawOrderId.trim()
        : 'ord_${DateTime.now().millisecondsSinceEpoch}_${context.appId}';

    final description = (payload['description'] as String?)?.trim() ?? 'Thanh toán đơn hàng';
    final currency = (payload['currency'] as String?)?.trim().toUpperCase() ?? 'VND';

    final order = PaymentOrder(
      orderId: orderId,
      appId: context.appId,
      amount: amount.toDouble(),
      currency: currency,
      description: description,
      status: PaymentOrderStatus.pending,
      createdAt: DateTime.now(),
      extraData: payload['extraData'] is Map<String, dynamic>
          ? payload['extraData'] as Map<String, dynamic>
          : null,
    );

    store.saveOrder(order);

    return {
      'orderId': order.orderId,
      'amount': order.amount,
      'currency': order.currency,
      'description': order.description,
      'status': 'PENDING',
      'createdAt': order.createdAt.toIso8601String(),
    };
  }
}

class PaymentOpenCheckoutHandler implements NativeActionHandler {
  final PaymentOrderStore store;

  PaymentOpenCheckoutHandler({required this.store});

  @override
  String get actionName => 'payment.openCheckout';

  @override
  String? get requiredCapability => 'payment.openCheckout';

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    return context.runInteractive(() async {
      context.checkCancelled();

      final orderId = payload['orderId'] as String?;
      if (orderId == null || orderId.trim().isEmpty) {
        throw BridgeError.invalidParams('orderId is required for payment.openCheckout');
      }

      final existingOrder = store.getOrder(orderId);
      final rawAmount = payload['amount'] ?? existingOrder?.amount;
      final num? parsedAmount = rawAmount is num
          ? rawAmount
          : (rawAmount != null ? num.tryParse(rawAmount.toString()) : null);
      final double amount = parsedAmount?.toDouble() ?? 50000.0;

      final description = existingOrder?.description ??
          (payload['description'] as String?) ??
          'Thanh toán đơn hàng';
      final currency = existingOrder?.currency ??
          (payload['currency'] as String?)?.toUpperCase() ??
          'VND';
      final appName = context.manifest?.name ?? context.appId;

      bool approved = false;
      if (context.buildContext != null) {
        approved = await PaymentCheckoutBottomSheet.show(
          context.buildContext!,
          appName: appName,
          orderId: orderId,
          amount: amount,
          currency: currency,
          description: description,
        );
      } else {
        // Fallback for headless testing
        approved = payload['autoApprove'] == true;
      }

      context.checkCancelled();

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      if (approved) {
        final txId = 'tx_succ_${timestamp}_${orderId.hashCode.abs()}';
        final result = {
          'transactionId': txId,
          'orderId': orderId,
          'status': 'SUCCESS',
          'amount': amount,
          'currency': currency,
          'timestamp': timestamp,
          'paymentMethod': 'SUPERAPP_WALLET',
          'message': 'Thanh toán thành công qua ví SuperApp',
        };
        store.recordTransaction(txId, result);
        if (existingOrder != null) {
          store.updateOrderStatus(orderId, PaymentOrderStatus.completed);
        }
        return result;
      } else {
        final txId = 'tx_cancel_$timestamp';
        final result = {
          'transactionId': txId,
          'orderId': orderId,
          'status': 'CANCELLED',
          'amount': amount,
          'currency': currency,
          'timestamp': timestamp,
          'paymentMethod': 'SUPERAPP_WALLET',
          'message': 'Người dùng đã huỷ giao dịch thanh toán',
        };
        store.recordTransaction(txId, result);
        if (existingOrder != null) {
          store.updateOrderStatus(orderId, PaymentOrderStatus.cancelled);
        }
        return result;
      }
    });
  }
}

class PaymentCheckStatusHandler implements NativeActionHandler {
  final PaymentOrderStore store;

  PaymentCheckStatusHandler({required this.store});

  @override
  String get actionName => 'payment.checkStatus';

  @override
  String? get requiredCapability => null;

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    context.checkCancelled();

    final txId = payload['transactionId'] as String?;
    final orderId = payload['orderId'] as String?;

    if ((txId == null || txId.isEmpty) && (orderId == null || orderId.isEmpty)) {
      throw BridgeError.invalidParams('transactionId or orderId is required');
    }

    final tx = (txId != null ? store.getTransaction(txId) : null) ??
        (orderId != null ? store.getTransactionByOrderId(orderId) : null);

    if (tx != null) {
      return tx;
    }

    final order = orderId != null ? store.getOrder(orderId) : null;
    if (order != null) {
      return {
        'orderId': order.orderId,
        'status': order.status.name.toUpperCase(),
        'amount': order.amount,
        'currency': order.currency,
        'timestamp': order.createdAt.millisecondsSinceEpoch,
      };
    }

    throw BridgeError.invalidParams('Không tìm thấy thông tin giao dịch thanh toán: ${txId ?? orderId}');
  }
}

class PaymentRequestPaymentHandler implements NativeActionHandler {
  final PaymentCreateOrderHandler createOrderHandler;
  final PaymentOpenCheckoutHandler openCheckoutHandler;

  PaymentRequestPaymentHandler({
    required this.createOrderHandler,
    required this.openCheckoutHandler,
  });

  @override
  String get actionName => 'payment.requestPayment';

  @override
  String? get requiredCapability => 'payment.openCheckout';

  @override
  bool get requiresAuth => false;

  @override
  Future<dynamic> handle(Map<String, dynamic> payload, ActionContext context) async {
    context.checkCancelled();

    var orderId = payload['orderId'] as String?;
    if (orderId == null || orderId.isEmpty) {
      final orderResult = await createOrderHandler.handle(payload, context);
      orderId = orderResult['orderId'] as String;
    }

    final checkoutPayload = Map<String, dynamic>.from(payload);
    checkoutPayload['orderId'] = orderId;

    return openCheckoutHandler.handle(checkoutPayload, context);
  }
}
