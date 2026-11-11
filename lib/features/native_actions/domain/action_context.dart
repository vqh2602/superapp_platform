// Ngữ cảnh thực thi hành động Native (Action Context).
//
// Chứa thông tin về môi trường runtime, danh tính Mini App đã xác thực,
// BuildContext của giao diện, tham chiếu UI Delegate, hàng đợi tương tác người dùng
// và cơ chế kiểm tra hủy bỏ phiên (Cancellation check).
import 'package:flutter/widgets.dart';
import '../../../core/errors/bridge_error.dart';
import '../../../core/security/runtime_security_context.dart';
import '../../mini_app_bridge/user_interaction_queue.dart';
import '../../mini_app_catalog/domain/mini_app_manifest.dart';
import 'mini_app_ui_delegate.dart';

/// Ngữ cảnh cung cấp cho các Native Action Handler khi thực thi
class ActionContext {
  /// BuildContext của widget màn hình (dùng để mở dialog hoặc điều hướng)
  final BuildContext? buildContext;
  /// Mã định danh Mini App đã được Flutter Host xác thực
  final String appId;
  /// Origin URL của trang web đang gọi
  final String? origin;
  /// Thông tin manifest của Mini App
  final MiniAppManifest? manifest;
  /// Delegate giao diện container của Mini App
  final MiniAppUiDelegate? uiDelegate;
  /// Ngữ cảnh bảo mật runtime do Host quản lý
  final RuntimeSecurityContext? securityContext;
  /// Hàm callback kiểm tra phiên làm việc còn hoạt động hay không
  final bool Function()? isSessionActive;
  final String? _explicitSessionId;
  /// Hàng đợi tuần tự hóa các modal/prompt tương tác người dùng
  final UserInteractionQueue? userInteractionQueue;

  const ActionContext({
    this.buildContext,
    required this.appId,
    this.origin,
    this.manifest,
    this.uiDelegate,
    this.securityContext,
    this.isSessionActive,
    String? runtimeSessionId,
    this.userInteractionQueue,
  }) : _explicitSessionId = runtimeSessionId;

  /// Cho biết phiên kích hoạt hành động này đã bị hủy bỏ hoặc giải phóng hay chưa
  bool get isCancelled => isSessionActive != null && !isSessionActive!();

  /// Ném ra lỗi [BridgeError.cancelled] nếu phiên làm việc đã bị hủy hoặc chuyển đổi
  void checkCancelled([String? message]) {
    if (isCancelled) {
      throw BridgeError.cancelled(message ?? 'Phiên làm việc đã bị hủy hoặc chuyển đổi');
    }
  }

  /// Chạy một tác vụ tương tác người dùng (dialog, modal) thông qua hàng đợi tuần tự
  Future<T> runInteractive<T>(Future<T> Function() task) {
    if (userInteractionQueue != null) {
      return userInteractionQueue!.run<T>(task, isCancelled: () => isCancelled);
    }
    checkCancelled();
    return task();
  }

  /// Định danh người dùng đã được Flutter Host xác thực (null nếu chưa đăng nhập)
  String? get userId => securityContext?.userId;

  /// Session ID phiên runtime do Host sinh
  String? get runtimeSessionId =>
      securityContext?.runtimeSessionId ?? _explicitSessionId;

  /// Nguồn gốc đã được phê duyệt an toàn
  String get approvedOrigin => securityContext?.approvedOrigin ?? origin ?? '';

  /// Tập hợp các capability bất biến được cấp phép
  Set<String> get allowedCapabilities =>
      securityContext?.allowedCapabilities ??
      (manifest != null ? Set<String>.from(manifest!.capabilities) : const {});

  ActionContext copyWith({
    BuildContext? buildContext,
    String? appId,
    String? origin,
    MiniAppManifest? manifest,
    MiniAppUiDelegate? uiDelegate,
    RuntimeSecurityContext? securityContext,
    bool Function()? isSessionActive,
    String? runtimeSessionId,
    UserInteractionQueue? userInteractionQueue,
  }) {
    return ActionContext(
      buildContext: buildContext ?? this.buildContext,
      appId: appId ?? this.appId,
      origin: origin ?? this.origin,
      manifest: manifest ?? this.manifest,
      uiDelegate: uiDelegate ?? this.uiDelegate,
      securityContext: securityContext ?? this.securityContext,
      isSessionActive: isSessionActive ?? this.isSessionActive,
      runtimeSessionId: runtimeSessionId ?? this.runtimeSessionId,
      userInteractionQueue: userInteractionQueue ?? this.userInteractionQueue,
    );
  }
}
