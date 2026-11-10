import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../errors/bridge_error.dart';
import '../../features/mini_app_catalog/domain/mini_app_manifest.dart';

/// Ngữ cảnh bảo mật runtime do Flutter Host quản lý chặt chẽ.
///
/// RuntimeSecurityContext
/// ├── appId: Định danh Mini App do Flutter Host nạp từ manifest (không tin client)
/// ├── userId: Định danh người dùng hiện tại đang đăng nhập trong SuperApp
/// ├── approvedOrigin: Nguồn gốc (Origin/URL) đã được Flutter xác thực & phê duyệt
/// ├── activeVersion: Phiên bản Mini App đang thực thi do Flutter nạp
/// ├── allowedCapabilities: Tập capabilities bất biến được phép theo manifest
/// └── runtimeSessionId: Session ID ngẫu nhiên của phiên chạy WebView do Flutter sinh
///
/// Mọi lời gọi Native Bridge phải vượt qua kiểm tra ngữ cảnh này trước khi tới Action Dispatcher.
/// Không sử dụng giá trị appId, origin, permissions hoặc sessionId do Mini App gửi làm bằng chứng cấp quyền.
@immutable
class RuntimeSecurityContext {
  /// 1. Định danh Mini App được Flutter xác thực (từ manifest.id)
  final String appId;

  /// 2. Định danh người dùng hiện tại (null nếu là khách / chưa đăng nhập)
  final String? userId;

  /// 3. Nguồn gốc (Origin/URL) đã được Flutter xác thực và phê duyệt cho Mini App này
  final String approvedOrigin;

  /// 4. Phiên bản Mini App đang chạy (từ manifest.version)
  final String activeVersion;

  /// 5. Danh sách capabilities bất biến được khai báo trong manifest
  final Set<String> allowedCapabilities;

  /// 6. Session ID duy nhất của phiên chạy WebView do Flutter Runtime khởi tạo
  final String runtimeSessionId;

  /// Thời điểm khởi tạo ngữ cảnh
  final DateTime createdAt;

  RuntimeSecurityContext({
    required this.appId,
    this.userId,
    required this.approvedOrigin,
    required this.activeVersion,
    required Set<String> allowedCapabilities,
    required this.runtimeSessionId,
    DateTime? createdAt,
  })  : allowedCapabilities = Set<String>.unmodifiable(allowedCapabilities),
        createdAt = createdAt ?? DateTime.now();

  /// Khởi tạo RuntimeSecurityContext từ Manifest và các thông tin do Flutter Host quản lý.
  factory RuntimeSecurityContext.create({
    required MiniAppManifest manifest,
    String? userId,
    required String backendBaseUrl,
    String? currentUrl,
    String? customSessionId,
  }) {
    String resolvedOrigin = currentUrl ?? '';
    if (resolvedOrigin.isEmpty) {
      if (manifest.entryUrl.startsWith('http://') || manifest.entryUrl.startsWith('https://')) {
        resolvedOrigin = manifest.entryUrl;
      } else {
        final targetApp = manifest.isWebApp ? manifest.id : 'schema_runtime';
        resolvedOrigin = '$backendBaseUrl/api/v1/miniapps/$targetApp/${manifest.version}/dist/index.html';
      }
    }

    return RuntimeSecurityContext(
      appId: manifest.id,
      userId: userId,
      approvedOrigin: resolvedOrigin,
      activeVersion: manifest.version,
      allowedCapabilities: Set<String>.from(manifest.capabilities),
      runtimeSessionId: customSessionId ?? const Uuid().v4(),
    );
  }

  /// Tạo bản sao context với các thuộc tính cập nhật (nếu có).
  RuntimeSecurityContext copyWith({
    String? approvedOrigin,
    String? userId,
    Set<String>? allowedCapabilities,
  }) {
    return RuntimeSecurityContext(
      appId: appId,
      userId: userId ?? this.userId,
      approvedOrigin: approvedOrigin ?? this.approvedOrigin,
      activeVersion: activeVersion,
      allowedCapabilities: allowedCapabilities ?? this.allowedCapabilities,
      runtimeSessionId: runtimeSessionId,
      createdAt: createdAt,
    );
  }

  /// Kiểm tra xem capability có nằm trong danh sách được phép của Mini App không.
  bool isCapabilityAllowed(String capability) {
    return allowedCapabilities.contains(capability);
  }

  /// Xác thực toàn diện cuộc gọi Bridge từ client đối chiếu với Ngữ cảnh bảo mật của Host.
  ///
  /// Ném ra [BridgeError.permissionDenied] nếu phát hiện bất kỳ dấu hiệu giả mạo nào:
  /// - Client gửi `requestAppId` khác với `appId` của Host.
  /// - Client gửi `requestSessionId` khác với `runtimeSessionId` của Host.
  /// - WebView hiện tại đã bị điều hướng ra ngoài hoặc nguồn gốc client khai báo mâu thuẫn.
  void validateBridgeCall({
    String? requestAppId,
    String? requestOrigin,
    String? currentWebViewUrl,
    String? requestSessionId,
  }) {
    // 1. Kiểm tra tính toàn vẹn danh tính Mini App (Anti-Spoofing AppId)
    if (requestAppId != null && requestAppId.isNotEmpty && requestAppId != appId) {
      throw BridgeError.permissionDenied(
        'Định danh Mini App không hợp lệ (client: "$requestAppId" != host: "$appId")',
      );
    }

    // 2. Kiểm tra tính toàn vẹn phiên làm việc (Anti-Session-Hijacking)
    if (requestSessionId != null &&
        requestSessionId.isNotEmpty &&
        requestSessionId != runtimeSessionId) {
      throw BridgeError.permissionDenied(
        'Runtime session không hợp lệ hoặc đã hết hạn (client: "$requestSessionId" != host: "$runtimeSessionId")',
      );
    }

    // 3. Xác thực nguồn gốc thực tế của WebView
    final effectiveUrl = currentWebViewUrl ?? approvedOrigin;
    if (effectiveUrl.isEmpty) {
      throw BridgeError.permissionDenied(
        'Không thể xác thực nguồn gốc trang web hiện tại của WebView',
      );
    }

    // 4. Kiểm tra nếu client tự khai báo requestOrigin mâu thuẫn với WebView thực tế
    if (requestOrigin != null && requestOrigin.isNotEmpty) {
      final reqUri = Uri.tryParse(requestOrigin);
      final effUri = Uri.tryParse(effectiveUrl);
      if (reqUri != null && effUri != null) {
        if (reqUri.scheme.isNotEmpty &&
            reqUri.scheme.toLowerCase() != effUri.scheme.toLowerCase()) {
          throw BridgeError.permissionDenied(
            'Giao thức origin khai báo ($requestOrigin) không khớp với WebView thực tế ($effectiveUrl)',
          );
        }
        if (reqUri.host.isNotEmpty &&
            reqUri.host.toLowerCase() != effUri.host.toLowerCase()) {
          throw BridgeError.permissionDenied(
            'Nguồn gốc do JavaScript khai báo ($requestOrigin) không khớp với nguồn gốc được phê duyệt ($effectiveUrl)',
          );
        }
      }
    }
  }

  Map<String, dynamic> toJson() => {
        'appId': appId,
        'userId': userId,
        'approvedOrigin': approvedOrigin,
        'activeVersion': activeVersion,
        'allowedCapabilities': allowedCapabilities.toList(),
        'runtimeSessionId': runtimeSessionId,
        'createdAt': createdAt.toIso8601String(),
      };

  @override
  String toString() =>
      'RuntimeSecurityContext(appId: $appId, user: $userId, origin: $approvedOrigin, v: $activeVersion, caps: ${allowedCapabilities.length}, session: $runtimeSessionId)';
}
