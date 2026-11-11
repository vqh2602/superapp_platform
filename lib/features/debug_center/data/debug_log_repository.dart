// Kho lưu trữ và phát nhật ký kiểm toán Bridge trong bộ nhớ (Debug Log Repository).
//
// Duy trì tối đa 200 bản ghi nhật ký Bridge gần nhất và cung cấp luồng Stream
// để màn hình Native Debug Center cập nhật theo thời gian thực.
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/bridge_log_entry.dart';

/// Lớp quản lý danh sách nhật ký gỡ lỗi Bridge
class DebugLogRepository {
  final List<BridgeLogEntry> _logs = [];
  final _logController = StreamController<List<BridgeLogEntry>>.broadcast();

  /// Danh sách bất biến các bản ghi nhật ký
  List<BridgeLogEntry> get logs => List.unmodifiable(_logs);

  /// Luồng Stream thông báo khi có log mới
  Stream<List<BridgeLogEntry>> get stream => _logController.stream;

  /// Thêm một bản ghi nhật ký mới vào đầu danh sách (giữ tối đa 200 bản ghi)
  void addLog(BridgeLogEntry entry) {
    _logs.insert(0, entry);
    if (_logs.length > 200) {
      _logs.removeLast();
    }
    _logController.add(List.unmodifiable(_logs));
  }

  /// Xóa toàn bộ danh sách nhật ký
  void clear() {
    _logs.clear();
    _logController.add(List.unmodifiable(_logs));
  }

  void dispose() {
    _logController.close();
  }
}

/// Provider cung cấp DebugLogRepository toàn cục
final debugLogRepositoryProvider = Provider<DebugLogRepository>((ref) {
  final repo = DebugLogRepository();
  ref.onDispose(() => repo.dispose());
  return repo;
});
