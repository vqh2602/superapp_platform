/// Bridge error codes as defined in the Super App specification.
enum BridgeErrorCode {
  authRequired('AUTH_REQUIRED'),
  permissionDenied('PERMISSION_DENIED'),
  actionNotFound('ACTION_NOT_FOUND'),
  invalidParams('INVALID_PARAMS'),
  unsupported('UNSUPPORTED'),
  timeout('TIMEOUT'),
  cancelled('CANCELLED'),
  internalError('INTERNAL_ERROR');

  final String code;
  const BridgeErrorCode(this.code);

  static BridgeErrorCode fromCode(String code) {
    return BridgeErrorCode.values.firstWhere(
      (e) => e.code == code,
      orElse: () => BridgeErrorCode.internalError,
    );
  }
}

/// Standard error thrown or returned across the bridge.
class BridgeError implements Exception {
  final BridgeErrorCode code;
  final String message;
  final Map<String, dynamic>? details;

  const BridgeError({
    required this.code,
    required this.message,
    this.details,
  });

  factory BridgeError.authRequired([String message = 'User authentication is required']) {
    return BridgeError(code: BridgeErrorCode.authRequired, message: message);
  }

  factory BridgeError.permissionDenied(String capability) {
    return BridgeError(
      code: BridgeErrorCode.permissionDenied,
      message: 'Permission denied for capability: $capability',
      details: {'capability': capability},
    );
  }

  factory BridgeError.actionNotFound(String action) {
    return BridgeError(
      code: BridgeErrorCode.actionNotFound,
      message: 'Action not allowed or unsupported: $action',
      details: {'action': action},
    );
  }

  factory BridgeError.invalidParams(String reason) {
    return BridgeError(
      code: BridgeErrorCode.invalidParams,
      message: 'Invalid action parameters: $reason',
    );
  }

  factory BridgeError.unsupported(String feature) {
    return BridgeError(
      code: BridgeErrorCode.unsupported,
      message: 'Native feature is unsupported in current environment: $feature',
      details: {'feature': feature},
    );
  }

  factory BridgeError.timeout([String message = 'Action execution timed out']) {
    return BridgeError(code: BridgeErrorCode.timeout, message: message);
  }

  factory BridgeError.cancelled([String message = 'Action was cancelled by user']) {
    return BridgeError(code: BridgeErrorCode.cancelled, message: message);
  }

  factory BridgeError.internal(String message, [Map<String, dynamic>? details]) {
    return BridgeError(
      code: BridgeErrorCode.internalError,
      message: message,
      details: details,
    );
  }

  Map<String, dynamic> toJson() => {
    'code': code.code,
    'message': message,
    if (details != null) 'details': details,
  };

  factory BridgeError.fromJson(Map<String, dynamic> json) => BridgeError(
    code: BridgeErrorCode.fromCode(json['code'] as String? ?? 'INTERNAL_ERROR'),
    message: json['message'] as String? ?? 'An error occurred',
    details: json['details'] as Map<String, dynamic>?,
  );

  @override
  String toString() => 'BridgeError(${code.code}): $message';
}
