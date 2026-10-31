import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:serp_debug_overlay/flutter_debug_overlay.dart';

/// Global LogBucket and HttpBucket for serp_debug_overlay
final globalLogBucket = LogBucket(maxStoredEntries: 500);
final globalHttpBucket = HttpBucket(maxStoredEntries: 100);

/// Initializes the SERP Debug Overlay log capturing
void initDebugOverlay() {
  if (!LogCapture.isStarted) {
    LogCapture.start(
      globalLogBucket,
      captureDebugPrint: true,
      captureFlutterErrors: true,
      capturePlatformErrors: true,
    );
  }
}

class DebugModeNotifier extends Notifier<bool> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _storageKey = 'superapp_debug_mode_enabled';

  @override
  bool build() {
    _loadState();
    DebugOverlay.enabled = kDebugMode;
    return false;
  }

  Future<void> _loadState() async {
    try {
      final val = await _storage.read(key: _storageKey);
      if (val == 'true') {
        state = true;
        DebugOverlay.enabled = true;
      }
    } catch (_) {}
  }

  Future<void> enableDebug() async {
    state = true;
    DebugOverlay.enabled = true;
    try {
      await _storage.write(key: _storageKey, value: 'true');
    } catch (_) {}
  }

  Future<void> disableDebug() async {
    state = false;
    DebugOverlay.enabled = kDebugMode;
    try {
      await _storage.write(key: _storageKey, value: 'false');
    } catch (_) {}
  }

  Future<void> toggleDebug() async {
    if (state) {
      await disableDebug();
    } else {
      await enableDebug();
    }
  }
}

final debugModeNotifierProvider =
    NotifierProvider<DebugModeNotifier, bool>(DebugModeNotifier.new);

/// Returns true if manual debug mode is enabled OR app is running in Flutter debug mode (kDebugMode)
final isDebugModeEnabledProvider = Provider<bool>((ref) {
  final userEnabled = ref.watch(debugModeNotifierProvider);
  final isEnabled = userEnabled || kDebugMode;
  DebugOverlay.enabled = isEnabled;
  return isEnabled;
});
