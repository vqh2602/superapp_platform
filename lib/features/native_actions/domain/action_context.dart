import 'package:flutter/widgets.dart';
import '../../../core/errors/bridge_error.dart';
import '../../../core/security/runtime_security_context.dart';
import '../../mini_app_bridge/user_interaction_queue.dart';
import '../../mini_app_catalog/domain/mini_app_manifest.dart';
import 'mini_app_ui_delegate.dart';

/// Context provided to every Native Action Handler during execution.
class ActionContext {
  final BuildContext? buildContext;
  final String appId;
  final String? origin;
  final MiniAppManifest? manifest;
  final MiniAppUiDelegate? uiDelegate;
  final RuntimeSecurityContext? securityContext;
  final bool Function()? isSessionActive;
  final String? _explicitSessionId;
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

  /// Indicates whether the session that triggered this action has been cancelled or disposed.
  bool get isCancelled => isSessionActive != null && !isSessionActive!();

  /// Throws [BridgeError.cancelled] if this action context was cancelled due to session switch or disposal.
  void checkCancelled([String? message]) {
    if (isCancelled) {
      throw BridgeError.cancelled(message ?? 'Phiên làm việc đã bị hủy hoặc chuyển đổi');
    }
  }

  /// Runs an interactive task (such as dialog or permission prompt) through the serialized user interaction queue.
  Future<T> runInteractive<T>(Future<T> Function() task) {
    if (userInteractionQueue != null) {
      return userInteractionQueue!.run<T>(task, isCancelled: () => isCancelled);
    }
    checkCancelled();
    return task();
  }

  /// Host-verified User ID (if authenticated)
  String? get userId => securityContext?.userId;

  /// Host-managed Runtime Session ID
  String? get runtimeSessionId =>
      securityContext?.runtimeSessionId ?? _explicitSessionId;

  /// Host-managed approved origin
  String get approvedOrigin => securityContext?.approvedOrigin ?? origin ?? '';

  /// Immutable set of allowed capabilities
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
