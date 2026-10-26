/// Representation of an incoming request from the Mini App JS SDK to Flutter.
class BridgeRequest {
  final String id;
  final String action;
  final Map<String, dynamic> payload;
  final String appId;
  final String? origin;
  final int timestamp;

  const BridgeRequest({
    required this.id,
    required this.action,
    required this.payload,
    required this.appId,
    this.origin,
    required this.timestamp,
  });

  factory BridgeRequest.fromJson(Map<String, dynamic> json, {String defaultAppId = 'unknown'}) {
    return BridgeRequest(
      id: json['id'] as String? ?? 'req_${DateTime.now().millisecondsSinceEpoch}',
      action: json['action'] as String? ?? '',
      payload: (json['payload'] as Map<String, dynamic>?) ?? {},
      appId: json['appId'] as String? ?? defaultAppId,
      origin: json['origin'] as String?,
      timestamp: json['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'action': action,
    'payload': payload,
    'appId': appId,
    if (origin != null) 'origin': origin,
    'timestamp': timestamp,
  };
}
