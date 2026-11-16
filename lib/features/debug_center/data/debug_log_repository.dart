// Kho lưu trữ và phát nhật ký kiểm toán Bridge trong bộ nhớ (Debug Log Repository).
//
// Sử dụng cấu trúc Ring Buffer (Circular Buffer) dung lượng 200 bản ghi với chi phí O(1),
// cơ chế gom cụm (batching/throttling 100–250ms) luồng Stream khi Debug Center đang mở,
// và loại bỏ toàn bộ dữ liệu payload nặng trong môi trường Release để tối ưu bộ nhớ RAM.
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/bridge_log_entry.dart';

/// Lớp quản lý nhật ký gỡ lỗi Bridge với Ring Buffer và Batched Streaming
class DebugLogRepository {
  /// Dung lượng tối đa của Ring Buffer
  final int capacity;

  /// Khoảng thời gian gom cụm log trước khi phát qua Stream (mặc định 150ms)
  final Duration batchWindow;

  /// Cờ xác định môi trường Release (mặc định theo kReleaseMode)
  final bool isRelease;

  late final List<BridgeLogEntry?> _buffer;
  int _head = 0;
  int _count = 0;

  final StreamController<List<BridgeLogEntry>> _logController;
  Timer? _batchTimer;
  bool _hasPendingBatch = false;

  /// Đánh dấu màn hình Debug Center đang mở hay đóng
  bool isDebugCenterOpen = false;

  DebugLogRepository({
    this.capacity = 200,
    this.batchWindow = const Duration(milliseconds: 150),
    bool? isRelease,
  })  : isRelease = isRelease ?? kReleaseMode,
        _logController = StreamController<List<BridgeLogEntry>>.broadcast() {
    _buffer = List<BridgeLogEntry?>.filled(capacity, null);
  }

  /// Trạng thái có cần phát stream hay không (chỉ phát khi Debug Center mở hoặc có listener)
  bool get shouldEmit =>
      !_logController.isClosed &&
      (_logController.hasListener || isDebugCenterOpen);

  /// Số lượng bản ghi hiện có trong bộ đệm
  int get length => _count;

  /// Danh sách bất biến các bản ghi nhật ký (xếp từ mới nhất đến cũ nhất)
  List<BridgeLogEntry> get logs {
    if (_count == 0) return const [];
    final result = List<BridgeLogEntry>.generate(_count, (i) {
      final index = (_head - i + capacity) % capacity;
      return _buffer[index]!;
    }, growable: false);
    return List.unmodifiable(result);
  }

  /// Luồng Stream thông báo danh sách log theo batch khi Debug Center đang mở
  Stream<List<BridgeLogEntry>> get stream => _logController.stream;

  /// Thêm một bản ghi nhật ký mới vào Ring Buffer (O(1))
  void addLog(BridgeLogEntry entry) {
    final processed = _processEntry(entry);
    _insertRingBuffer(processed);

    if (!shouldEmit) return;

    _hasPendingBatch = true;
    _batchTimer ??= Timer(batchWindow, _flushBatch);
  }

  void _insertRingBuffer(BridgeLogEntry entry) {
    if (_count == 0) {
      _head = 0;
      _buffer[0] = entry;
      _count = 1;
    } else {
      _head = (_head + 1) % capacity;
      _buffer[_head] = entry;
      if (_count < capacity) {
        _count++;
      }
    }
  }

  BridgeLogEntry _processEntry(BridgeLogEntry entry) {
    if (isRelease) {
      // Trong Release mode: không lưu toàn bộ payload (params chi tiết và responseData lớn)
      return entry.toReleaseEntry();
    }

    // Trong Debug/Profile mode: cắt tỉa nếu chuỗi hoặc danh sách quá lớn để tránh OOM
    final truncatedParams =
        _truncatePayload(entry.params) as Map<String, dynamic>;
    final truncatedResponse = _truncatePayload(entry.responseData);

    if (identical(truncatedParams, entry.params) &&
        identical(truncatedResponse, entry.responseData)) {
      return entry;
    }

    return BridgeLogEntry(
      id: entry.id,
      action: entry.action,
      params: truncatedParams,
      success: entry.success,
      responseData: truncatedResponse,
      errorMessage: entry.errorMessage,
      executionTimeMs: entry.executionTimeMs,
      timestamp: entry.timestamp,
      appId: entry.appId,
    );
  }

  dynamic _truncatePayload(dynamic data, {int maxDepth = 3}) {
    if (data == null || maxDepth <= 0) return data;
    if (data is String) {
      if (data.length > 2048) {
        return '${data.substring(0, 512)}... [truncated ${data.length} chars]';
      }
      return data;
    }
    if (data is Map<String, dynamic>) {
      final res = <String, dynamic>{};
      for (final e in data.entries) {
        res[e.key] = _truncatePayload(e.value, maxDepth: maxDepth - 1);
      }
      return res;
    }
    if (data is List) {
      if (data.length > 50) {
        final sublist = data
            .take(50)
            .map((e) => _truncatePayload(e, maxDepth: maxDepth - 1))
            .toList();
        sublist.add('[truncated ${data.length - 50} items]');
        return sublist;
      }
      return data.map((e) => _truncatePayload(e, maxDepth: maxDepth - 1)).toList();
    }
    return data;
  }

  void _flushBatch() {
    _batchTimer = null;
    if (_hasPendingBatch && shouldEmit) {
      _hasPendingBatch = false;
      _logController.add(logs);
    }
  }

  /// Ép buộc phát ngay lập tức danh sách log đang chờ trong batch
  void flush() {
    _batchTimer?.cancel();
    _batchTimer = null;
    if (_hasPendingBatch && shouldEmit) {
      _hasPendingBatch = false;
      _logController.add(logs);
    }
  }

  /// Xóa toàn bộ danh sách nhật ký
  void clear() {
    _batchTimer?.cancel();
    _batchTimer = null;
    _hasPendingBatch = false;
    _buffer.fillRange(0, capacity, null);
    _head = 0;
    _count = 0;
    if (shouldEmit) {
      _logController.add(const []);
    }
  }

  void dispose() {
    _batchTimer?.cancel();
    _batchTimer = null;
    _logController.close();
  }
}

/// Provider cung cấp DebugLogRepository toàn cục
final debugLogRepositoryProvider = Provider<DebugLogRepository>((ref) {
  final repo = DebugLogRepository();
  ref.onDispose(() => repo.dispose());
  return repo;
});
