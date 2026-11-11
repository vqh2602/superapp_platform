// Mô hình phiên làm việc cơ bản của Mini App (Mini App Session).
//
// Quản lý mã phiên sessionId, thông tin manifest và thời điểm bắt đầu phiên.
import '../../mini_app_catalog/domain/mini_app_manifest.dart';

/// Lớp đại diện phiên chạy của một Mini App
class MiniAppSession {
  /// Mã phiên duy nhất
  final String sessionId;
  /// Manifest của Mini App đang chạy
  final MiniAppManifest manifest;
  /// Thời điểm bắt đầu phiên
  final DateTime startedAt;
  /// Trạng thái phiên còn hoạt động hay không
  bool isActive;

  MiniAppSession({
    required this.sessionId,
    required this.manifest,
    required this.startedAt,
    this.isActive = true,
  });
}
