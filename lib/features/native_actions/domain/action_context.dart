import 'package:flutter/widgets.dart';
import '../../mini_app_catalog/domain/mini_app_manifest.dart';

/// Context provided to every Native Action Handler during execution.
class ActionContext {
  final BuildContext? buildContext;
  final String appId;
  final String? origin;
  final MiniAppManifest? manifest;

  const ActionContext({
    this.buildContext,
    required this.appId,
    this.origin,
    this.manifest,
  });
}
