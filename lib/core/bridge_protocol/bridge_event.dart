/// Đại diện cho sự kiện bất đồng bộ (Event) từ Flutter phát xuống Mini Apps.
///
/// Các sự kiện này có thể là: thay đổi trạng thái mạng (networkChanged),
/// vòng đời ứng dụng (appPaused, appResumed), hoặc các thông báo hệ thống khác.
class BridgeEvent {
  /// Tên định danh của sự kiện (vd: 'networkChanged', 'themeChanged')
  final String event;

  /// Dữ liệu chi tiết đính kèm sự kiện
  final Map<String, dynamic> payload;

  /// Dấu thời gian phát sự kiện (milliseconds since epoch)
  final int timestamp;

  const BridgeEvent({
    required this.event,
    required this.payload,
    required this.timestamp,
  });

  /// Factory tạo nhanh một sự kiện kèm payload và tự động gắn timestamp hiện tại
  factory BridgeEvent.create(String event, [Map<String, dynamic>? payload]) {
    return BridgeEvent(
      event: event,
      payload: payload ?? {},
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Chuyển đổi sự kiện sang Map JSON để phát qua JavaScript
  Map<String, dynamic> toJson() => {
    'event': event,
    'payload': payload,
    'timestamp': timestamp,
  };
}
