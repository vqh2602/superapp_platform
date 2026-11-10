import 'package:flutter/widgets.dart';
import '../../../core/security/runtime_security_context.dart';
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

  const ActionContext({
    this.buildContext,
    required this.appId,
    this.origin,
    this.manifest,
    this.uiDelegate,
    this.securityContext,
  });

  /// Host-verified User ID (if authenticated)
  String? get userId => securityContext?.userId;

  /// Host-managed Runtime Session ID
  String? get runtimeSessionId => securityContext?.runtimeSessionId;

  /// Host-managed approved origin
  String get approvedOrigin => securityContext?.approvedOrigin ?? origin ?? '';

  /// Immutable set of allowed capabilities
  Set<String> get allowedCapabilities =>
      securityContext?.allowedCapabilities ??
      (manifest != null ? Set<String>.from(manifest!.capabilities) : const {});
}
