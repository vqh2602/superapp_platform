/// Bản ghi nhật ký kiểm toán Bridge (Bridge Log Entry).
///
/// Lưu vết chi tiết từng lời gọi action từ Mini App: định danh request, tên action,
/// tham số đã làm sạch dữ liệu nhạy cảm (sanitized), kết quả phản hồi và thời gian thực thi.
class BridgeLogEntry {
  /// Mã ID định danh của request
  final String id;
  /// Tên action được gọi
  final String action;
  /// Bộ tham số đầu vào (đã được ẩn thông tin nhạy cảm)
  final Map<String, dynamic> params;
  /// Trạng thái thực thi thành công hay thất bại
  final bool success;
  /// Dữ liệu phản hồi trả về
  final dynamic responseData;
  /// Thông điệp lỗi (nếu thất bại)
  final String? errorMessage;
  /// Thời gian xử lý tính bằng mili-giây
  final int executionTimeMs;
  /// Dấu thời gian ghi nhận
  final DateTime timestamp;
  /// Mã Mini App gọi Bridge
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

  /// Làm sạch các trường thông tin nhạy cảm (tokens, passwords, secrets) trước khi ghi log
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
