enum OrderStatus {
  pending('PENDING'),
  success('SUCCESS'),
  failed('FAILED'),
  cancelled('CANCELLED');

  final String value;
  const OrderStatus(this.value);

  static OrderStatus fromString(String val) {
    return OrderStatus.values.firstWhere(
      (s) => s.value == val.toUpperCase(),
      orElse: () => OrderStatus.pending,
    );
  }
}

class MockOrder {
  final String orderId;
  final double amount;
  final String currency;
  final String description;
  final String appId;
  final String userId;
  OrderStatus status;
  final DateTime createdAt;
  DateTime? completedAt;
  String? paymentMethod;

  MockOrder({
    required this.orderId,
    required this.amount,
    this.currency = 'VND',
    required this.description,
    required this.appId,
    required this.userId,
    this.status = OrderStatus.pending,
    required this.createdAt,
    this.completedAt,
    this.paymentMethod,
  });

  Map<String, dynamic> toJson() => {
    'orderId': orderId,
    'amount': amount,
    'currency': currency,
    'description': description,
    'appId': appId,
    'userId': userId,
    'status': status.value,
    'createdAt': createdAt.toIso8601String(),
    if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
    if (paymentMethod != null) 'paymentMethod': paymentMethod,
  };
}
