// Định nghĩa mã lỗi và đối tượng ngoại lệ chuẩn qua JavaScript Bridge.
//
// Tuân thủ quy chuẩn đặc tả của SuperApp để đảm bảo Mini App JS SDK
// nhận diện và xử lý chính xác từng trường hợp lỗi từ Native Shell.

/// Danh mục các mã lỗi chuẩn của JavaScript Bridge
enum BridgeErrorCode {
  /// Yêu cầu người dùng đăng nhập SuperApp trước khi thực thi
  authRequired('AUTH_REQUIRED'),
  /// Bị từ chối quyền (người dùng từ chối cấp quyền hoặc capability chưa khai báo)
  permissionDenied('PERMISSION_DENIED'),
  /// Action không tồn tại hoặc không được hỗ trợ trong hệ thống
  actionNotFound('ACTION_NOT_FOUND'),
  /// Tham số đầu vào payload không hợp lệ hoặc thiếu trường bắt buộc
  invalidParams('INVALID_PARAMS'),
  /// Tính năng Native không được hỗ trợ trên thiết bị/nền tảng hiện tại
  unsupported('UNSUPPORTED'),
  /// Quá thời gian chờ thực thi hành động (Timeout)
  timeout('TIMEOUT'),
  /// Hành động bị hủy bỏ bởi người dùng hoặc hệ thống
  cancelled('CANCELLED'),
  /// Vượt quá tần suất gọi API cho phép (Rate Limit)
  rateLimitExceeded('RATE_LIMIT_EXCEEDED'),
  /// Kích thước dữ liệu payload vượt quá giới hạn an toàn
  payloadTooLarge('PAYLOAD_TOO_LARGE'),
  /// Lỗi nội bộ phát sinh từ hệ thống Native
  internalError('INTERNAL_ERROR');

  final String code;
  const BridgeErrorCode(this.code);

  /// Chuyển đổi mã chuỗi (String code) sang giá trị Enum tương ứng
  static BridgeErrorCode fromCode(String code) {
    return BridgeErrorCode.values.firstWhere(
      (e) => e.code == code,
      orElse: () => BridgeErrorCode.internalError,
    );
  }
}

/// Lớp đại diện lỗi tiêu chuẩn ném ra hoặc phản hồi qua Bridge.
class BridgeError implements Exception {
  /// Mã lỗi phân loại
  final BridgeErrorCode code;
  /// Thông điệp mô tả chi tiết lỗi
  final String message;
  /// Dữ liệu bổ sung đi kèm lỗi (nếu có)
  final Map<String, dynamic>? details;

  const BridgeError({
    required this.code,
    required this.message,
    this.details,
  });

  /// Tạo lỗi yêu cầu đăng nhập tài khoản
  factory BridgeError.authRequired([String message = 'User authentication is required']) {
    return BridgeError(code: BridgeErrorCode.authRequired, message: message);
  }

  /// Tạo lỗi từ chối quyền truy cập capability
  factory BridgeError.permissionDenied(String capability) {
    return BridgeError(
      code: BridgeErrorCode.permissionDenied,
      message: 'Permission denied for capability: $capability',
      details: {'capability': capability},
    );
  }

  /// Tạo lỗi hành động không được hỗ trợ hoặc không tìm thấy
  factory BridgeError.actionNotFound(String action) {
    return BridgeError(
      code: BridgeErrorCode.actionNotFound,
      message: 'Action not allowed or unsupported: $action',
      details: {'action': action},
    );
  }

  /// Tạo lỗi tham số đầu vào không hợp lệ
  factory BridgeError.invalidParams(String reason) {
    return BridgeError(
      code: BridgeErrorCode.invalidParams,
      message: 'Invalid action parameters: $reason',
    );
  }

  /// Tạo lỗi tính năng phần cứng không được hỗ trợ trên môi trường hiện tại
  factory BridgeError.unsupported(String feature) {
    return BridgeError(
      code: BridgeErrorCode.unsupported,
      message: 'Native feature is unsupported in current environment: $feature',
      details: {'feature': feature},
    );
  }

  /// Tạo lỗi quá hạn thời gian chờ thực thi
  factory BridgeError.timeout([String message = 'Action execution timed out']) {
    return BridgeError(code: BridgeErrorCode.timeout, message: message);
  }

  /// Tạo lỗi thao tác bị người dùng hủy bỏ
  factory BridgeError.cancelled([String message = 'Action was cancelled by user']) {
    return BridgeError(code: BridgeErrorCode.cancelled, message: message);
  }

  /// Tạo lỗi vượt quá tần suất gọi action hoặc nghẽn hàng đợi tương tác
  factory BridgeError.rateLimitExceeded([String message = 'Rate limit or concurrency limit exceeded']) {
    return BridgeError(code: BridgeErrorCode.rateLimitExceeded, message: message);
  }

  /// Tạo lỗi dung lượng gói tin vượt ngưỡng cho phép
  factory BridgeError.payloadTooLarge([String message = 'Message size exceeds limit']) {
    return BridgeError(code: BridgeErrorCode.payloadTooLarge, message: message);
  }

  /// Tạo lỗi nội bộ không xác định kèm chi tiết
  factory BridgeError.internal(String message, [Map<String, dynamic>? details]) {
    return BridgeError(
      code: BridgeErrorCode.internalError,
      message: message,
      details: details,
    );
  }

  /// Tuần tự hóa đối tượng lỗi thành Map JSON để gửi cho Mini App JS SDK
  Map<String, dynamic> toJson() => {
    'code': code.code,
    'message': message,
    if (details != null) 'details': details,
  };

  /// Khởi tạo [BridgeError] từ Map JSON
  factory BridgeError.fromJson(Map<String, dynamic> json) => BridgeError(
    code: BridgeErrorCode.fromCode(json['code'] as String? ?? 'INTERNAL_ERROR'),
    message: json['message'] as String? ?? 'An error occurred',
    details: json['details'] as Map<String, dynamic>?,
  );

  @override
  String toString() => 'BridgeError(${code.code}): $message';
}
