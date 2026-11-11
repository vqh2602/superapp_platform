// Gói tin kết quả phản hồi (Response) từ Flutter gửi ngược lại Mini App JS SDK.
//
// Chứa mã id trùng khớp với request tương ứng, trạng thái thành công hoặc thất bại,
// dữ liệu trả về hoặc đối tượng lỗi [BridgeError], và thời gian thực thi.
import '../errors/bridge_error.dart';

/// Đại diện phản hồi trả về qua JavaScript Bridge
class BridgeResponse {
  /// Mã định danh đối soát tương ứng với `BridgeRequest.id`
  final String id;

  /// Tên action đã thực thi
  final String action;

  /// Trạng thái kết quả thành công hay thất bại
  final bool success;

  /// Dữ liệu kết quả trả về cho Mini App (khi `success == true`)
  final dynamic data;

  /// Thông tin lỗi chi tiết (khi `success == false`)
  final BridgeError? error;

  /// Thời gian xử lý hành động tính bằng mili-giây
  final int executionTimeMs;

  const BridgeResponse({
    required this.id,
    this.action = '',
    required this.success,
    this.data,
    this.error,
    this.executionTimeMs = 0,
  });

  /// Tạo phản hồi thành công chứa dữ liệu
  factory BridgeResponse.ok(String id, dynamic data, [int executionTimeMs = 0, String action = '']) {
    return BridgeResponse(
      id: id,
      action: action,
      success: true,
      data: data,
      executionTimeMs: executionTimeMs,
    );
  }

  /// Tạo phản hồi thất bại mang thông tin lỗi [BridgeError]
  factory BridgeResponse.failure(String id, BridgeError error, [int executionTimeMs = 0, String action = '']) {
    return BridgeResponse(
      id: id,
      action: action,
      success: false,
      error: error,
      executionTimeMs: executionTimeMs,
    );
  }

  /// Chuyển đổi phản hồi sang cấu trúc JSON gửi vào WebView
  Map<String, dynamic> toJson() => {
    'id': id,
    'action': action,
    'success': success,
    'data': data,
    'error': error?.toJson(),
    'executionTimeMs': executionTimeMs,
    'timestamp': DateTime.now().millisecondsSinceEpoch,
  };

  /// Khởi tạo [BridgeResponse] từ JSON Map
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
