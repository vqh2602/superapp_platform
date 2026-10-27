import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DebugModeNotifier extends StateNotifier<bool> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _storageKey = 'superapp_debug_mode_enabled';

  DebugModeNotifier() : super(false) {
    _loadState();
  }

  Future<void> _loadState() async {
    try {
      final val = await _storage.read(key: _storageKey);
      if (val == 'true') {
        state = true;
      }
    } catch (_) {}
  }

  Future<void> enableDebug() async {
    state = true;
    try {
      await _storage.write(key: _storageKey, value: 'true');
    } catch (_) {}
  }

  Future<void> disableDebug() async {
    state = false;
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

final debugModeNotifierProvider = StateNotifierProvider<DebugModeNotifier, bool>((ref) {
  return DebugModeNotifier();
});

/// Returns true if manual debug mode is enabled OR app is running in Flutter debug mode (kDebugMode)
final isDebugModeEnabledProvider = Provider<bool>((ref) {
  final userEnabled = ref.watch(debugModeNotifierProvider);
  return userEnabled || kDebugMode;
});
