class WebLogEntry {
  final String id;
  final String type; // 'console', 'error', 'unhandledrejection', 'eval'
  final String level; // 'log', 'info', 'warn', 'error', 'debug'
  final String message;
  final String? stack;
  final DateTime timestamp;

  WebLogEntry({
    required this.id,
    required this.type,
    required this.level,
    required this.message,
    this.stack,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isError => level == 'error' || type == 'error' || type == 'unhandledrejection';
  bool get isWarning => level == 'warn' || level == 'warning';

  factory WebLogEntry.fromJson(Map<String, dynamic> json) {
    return WebLogEntry(
      id: json['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
      type: json['type'] as String? ?? 'console',
      level: json['level'] as String? ?? 'log',
      message: json['message'] as String? ?? '',
      stack: json['stack'] as String?,
      timestamp: json['timeMs'] != null
          ? DateTime.fromMillisecondsSinceEpoch((json['timeMs'] as num).toInt())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'level': level,
    'message': message,
    'stack': stack,
    'timestamp': timestamp.toIso8601String(),
  };
}
