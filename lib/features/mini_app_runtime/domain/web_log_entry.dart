/// Bản ghi nhật ký Web WebView (Web Log Entry).
///
/// Bắt các log từ JavaScript console (log, info, warn, error, debug), các ngoại lệ
/// chưa bắt (uncaught error) và unhandled promise rejections bên trong Mini App.
class WebLogEntry {
  /// Mã ID định danh bản ghi log
  final String id;
  /// Loại log ('console', 'error', 'unhandledrejection', 'eval')
  final String type;
  /// Cấp độ log ('log', 'info', 'warn', 'error', 'debug')
  final String level;
  /// Nội dung thông báo log
  final String message;
  /// Stack trace nếu là lỗi
  final String? stack;
  /// Dấu thời gian ghi nhận
  final DateTime timestamp;

  WebLogEntry({
    required this.id,
    required this.type,
    required this.level,
    required this.message,
    this.stack,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Kiểm tra xem bản ghi có phải là lỗi hay không
  bool get isError => level == 'error' || type == 'error' || type == 'unhandledrejection';

  /// Kiểm tra xem bản ghi có phải là cảnh báo hay không
  bool get isWarning => level == 'warn' || level == 'warning';

  /// Khởi tạo [WebLogEntry] từ JSON Map gửi từ JavaScript Bridge Polyfill
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
