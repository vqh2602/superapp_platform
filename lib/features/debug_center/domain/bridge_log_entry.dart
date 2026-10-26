class BridgeLogEntry {
  final String id;
  final String action;
  final Map<String, dynamic> params;
  final bool success;
  final dynamic responseData;
  final String? errorMessage;
  final int executionTimeMs;
  final DateTime timestamp;
  final String appId;

  BridgeLogEntry({
    required this.id,
    required this.action,
    required this.params,
    required this.success,
    this.responseData,
    this.errorMessage,
    required this.executionTimeMs,
    required this.timestamp,
    required this.appId,
  });

  /// Sanitizes sensitive fields such as tokens, passwords, and private auth codes
  static Map<String, dynamic> sanitize(Map<String, dynamic> raw) {
    final sanitized = <String, dynamic>{};
    for (final entry in raw.entries) {
      final key = entry.key.toLowerCase();
      if (key.contains('token') || key.contains('secret') || key.contains('password')) {
        final val = entry.value?.toString() ?? '';
        if (val.length > 8) {
          sanitized[entry.key] = '${val.substring(0, 4)}***${val.substring(val.length - 4)}';
        } else {
          sanitized[entry.key] = '***';
        }
      } else if (entry.value is Map<String, dynamic>) {
        sanitized[entry.key] = sanitize(entry.value as Map<String, dynamic>);
      } else {
        sanitized[entry.key] = entry.value;
      }
    }
    return sanitized;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'action': action,
    'params': params,
    'success': success,
    'responseData': responseData,
    'errorMessage': errorMessage,
    'executionTimeMs': executionTimeMs,
    'timestamp': timestamp.toIso8601String(),
    'appId': appId,
  };
}
