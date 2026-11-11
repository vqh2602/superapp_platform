/// Đại diện cho gói tin yêu cầu (Request) từ Mini App JS SDK gửi sang Flutter Native Shell.
///
/// Chứa thông tin action cần thực thi, tham số payload, mã ứng dụng appId,
/// URL nguồn gốc (origin) và dấu thời gian gọi.
class BridgeRequest {
  /// Mã định danh duy nhất của request (dùng để đối soát khi trả kết quả qua BridgeResponse)
  final String id;

  /// Tên action được yêu cầu (vd: 'device.getLocation', 'auth.login')
  final String action;

  /// Tham số đầu vào kèm theo của hành động
  final Map<String, dynamic> payload;

  /// Mã định danh Mini App thực hiện yêu cầu
  final String appId;

  /// Nguồn gốc (Origin/URL) trang web trong WebView phát sinh yêu cầu
  final String? origin;

  /// Thời điểm tạo yêu cầu (milliseconds since epoch)
  final int timestamp;

  const BridgeRequest({
    required this.id,
    required this.action,
    required this.payload,
    required this.appId,
    this.origin,
    required this.timestamp,
  });

  /// Chuyển đổi dữ liệu JSON nhận được từ JavaScript sang đối tượng [BridgeRequest]
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

  /// Tuần tự hóa đối tượng thành Map JSON
  Map<String, dynamic> toJson() => {
    'id': id,
    'action': action,
    'payload': payload,
    'appId': appId,
    if (origin != null) 'origin': origin,
    'timestamp': timestamp,
  };
}
