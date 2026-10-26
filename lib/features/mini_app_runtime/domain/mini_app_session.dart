import '../../mini_app_catalog/domain/mini_app_manifest.dart';

class MiniAppSession {
  final String sessionId;
  final MiniAppManifest manifest;
  final DateTime startedAt;
  bool isActive;

  MiniAppSession({
    required this.sessionId,
    required this.manifest,
    required this.startedAt,
    this.isActive = true,
  });
}
