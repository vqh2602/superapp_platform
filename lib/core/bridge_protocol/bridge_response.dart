import '../errors/bridge_error.dart';

/// Representation of an outgoing response from Flutter to the Mini App JS SDK.
class BridgeResponse {
  final String id;
  final String action;
  final bool success;
  final dynamic data;
  final BridgeError? error;
  final int executionTimeMs;

  const BridgeResponse({
    required this.id,
    this.action = '',
    required this.success,
    this.data,
    this.error,
    this.executionTimeMs = 0,
  });

  factory BridgeResponse.ok(String id, dynamic data, [int executionTimeMs = 0, String action = '']) {
    return BridgeResponse(
      id: id,
      action: action,
      success: true,
      data: data,
      executionTimeMs: executionTimeMs,
    );
  }

  factory BridgeResponse.failure(String id, BridgeError error, [int executionTimeMs = 0, String action = '']) {
    return BridgeResponse(
      id: id,
      action: action,
      success: false,
      error: error,
      executionTimeMs: executionTimeMs,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'action': action,
    'success': success,
    'data': data,
    'error': error?.toJson(),
    'executionTimeMs': executionTimeMs,
    'timestamp': DateTime.now().millisecondsSinceEpoch,
  };

  factory BridgeResponse.fromJson(Map<String, dynamic> json) => BridgeResponse(
    id: json['id'] as String? ?? '',
    action: json['action'] as String? ?? '',
    success: json['success'] as bool? ?? false,
    data: json['data'],
    error: json['error'] != null
        ? BridgeError.fromJson(json['error'] as Map<String, dynamic>)
        : null,
    executionTimeMs: json['executionTimeMs'] as int? ?? 0,
  );
}
