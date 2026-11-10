import 'package:flutter/foundation.dart';
import 'mini_app_manifest.dart';

/// Giấy phép cấp quyền thực thi Mini App (Execution Authorization).
///
/// Phân tách rõ ràng giữa:
/// - Catalog Cache: Chỉ phục vụ hiển thị thông tin ứng dụng trong danh mục.
/// - Execution Authorization: Bằng chứng phiên bản đang được phép chạy trên máy khách,
///   có thời hạn hiệu lực (TTL) và được Backend xác thực trước khi mở WebView runtime.
@immutable
class MiniAppExecutionAuthorization {
  /// Định danh Mini App
  final String appId;

  /// Phiên bản cụ thể được cấp phép chạy
  final String version;

  /// Manifest đã được Backend xác thực
  final MiniAppManifest manifest;

  /// Thời điểm cấp phép
  final DateTime authorizedAt;

  /// Thời điểm hết hạn giấy phép thực thi
  final DateTime expiresAt;

  /// Token hoặc chữ ký xác thực từ máy chủ (nếu có)
  final String? authorizationToken;

  /// Xác nhận đã được Backend thẩm định tính hợp lệ
  final bool isBackendVerified;

  const MiniAppExecutionAuthorization({
    required this.appId,
    required this.version,
    required this.manifest,
    required this.authorizedAt,
    required this.expiresAt,
    this.authorizationToken,
    this.isBackendVerified = true,
  });

  /// Kiểm tra xem giấy phép đã quá hạn hiệu lực hay chưa
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Giấy phép chỉ hợp lệ khi còn trong hạn và đã được Backend xác nhận
  bool get isValid => !isExpired && isBackendVerified;

  /// Thời gian còn lại của giấy phép
  Duration get remainingTime => expiresAt.difference(DateTime.now());

  Map<String, dynamic> toJson() => {
        'appId': appId,
        'version': version,
        'manifest': manifest.toJson(),
        'authorizedAt': authorizedAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        'authorizationToken': authorizationToken,
        'isBackendVerified': isBackendVerified,
        'isExpired': isExpired,
      };

  @override
  String toString() =>
      'MiniAppExecutionAuthorization(appId: $appId, v: $version, expires: $expiresAt, valid: $isValid)';
}
