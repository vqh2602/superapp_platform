import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/bridge_log_entry.dart';

class DebugLogRepository {
  final List<BridgeLogEntry> _logs = [];
  final _logController = StreamController<List<BridgeLogEntry>>.broadcast();

  // Simulation flags for debugging
  bool simulateTimeout = false;
  bool simulateUnauthorized = false;
  bool simulatePermissionDenied = false;
  bool simulateNativeFailure = false;

  List<BridgeLogEntry> get logs => List.unmodifiable(_logs);
  Stream<List<BridgeLogEntry>> get stream => _logController.stream;

  void addLog(BridgeLogEntry entry) {
    _logs.insert(0, entry);
    if (_logs.length > 200) {
      _logs.removeLast();
    }
    _logController.add(List.unmodifiable(_logs));
  }

  void clear() {
    _logs.clear();
    _logController.add(List.unmodifiable(_logs));
  }

  void resetSimulations() {
    simulateTimeout = false;
    simulateUnauthorized = false;
    simulatePermissionDenied = false;
    simulateNativeFailure = false;
  }

  void dispose() {
    _logController.close();
  }
}

final debugLogRepositoryProvider = Provider<DebugLogRepository>((ref) {
  final repo = DebugLogRepository();
  ref.onDispose(() => repo.dispose());
  return repo;
});
