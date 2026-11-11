// Hàng đợi tương tác người dùng (User Interaction Queue).
//
// Đảm bảo các hội thoại tương tác (Permission Prompt, Confirm Dialog, Alert)
// được hiển thị tuần tự, không bị đè chồng chéo lên nhau khi Mini App gọi liên tiếp.
import 'dart:async';
import '../../../core/errors/bridge_error.dart';

class _QueuedInteraction<T> {
  final Completer<T> completer;
  final Future<T> Function() task;
  final bool Function()? isCancelled;

  _QueuedInteraction({
    required this.completer,
    required this.task,
    this.isCancelled,
  });
}

/// Hàng đợi tuần tự hóa các tác vụ cần tương tác giao diện người dùng (Permission Dialog, Alert, Confirm)
/// nhằm ngăn chặn việc Mini App gửi liên tục yêu cầu làm tràn hoặc chồng chéo nhiều modal dialog trên UI.
class UserInteractionQueue {
  final int maxQueueSize;
  int _activeCount = 0;
  final List<_QueuedInteraction<dynamic>> _queue = [];
  bool _isDisposed = false;

  UserInteractionQueue({this.maxQueueSize = 5});

  int get pendingCount => _queue.length;
  int get activeCount => _activeCount;
  bool get isDisposed => _isDisposed;

  /// Đưa một tác vụ tương tác người dùng vào hàng đợi thực thi tuần tự.
  /// Nếu đang có modal dialog hiển thị, tác vụ sẽ chờ cho đến khi dialog trước đóng lại.
  /// Nếu hàng đợi đã đầy (vượt `maxQueueSize`), ném ra [BridgeError.rateLimitExceeded].
  Future<T> run<T>(
    Future<T> Function() task, {
    bool Function()? isCancelled,
  }) async {
    if (_isDisposed) {
      throw BridgeError.cancelled('User interaction queue has been disposed');
    }
    if (isCancelled != null && isCancelled()) {
      throw BridgeError.cancelled('Session is inactive or cancelled');
    }

    if (_activeCount > 0) {
      if (_queue.length >= maxQueueSize) {
        throw BridgeError.rateLimitExceeded(
          'Hàng đợi tương tác người dùng đã đầy (tối đa $maxQueueSize yêu cầu đang chờ)',
        );
      }
      final completer = Completer<T>();
      _queue.add(_QueuedInteraction<T>(
        completer: completer,
        task: task,
        isCancelled: isCancelled,
      ));
      return await completer.future;
    }

    _activeCount++;
    try {
      if (isCancelled != null && isCancelled()) {
        throw BridgeError.cancelled('Session is inactive or cancelled');
      }
      return await task();
    } finally {
      _activeCount--;
      _processNext();
    }
  }

  void _processNext() {
    if (_isDisposed) return;
    while (_queue.isNotEmpty) {
      final next = _queue.removeAt(0);
      if (next.isCancelled != null && next.isCancelled!()) {
        if (!next.completer.isCompleted) {
          next.completer.completeError(
            BridgeError.cancelled('Yêu cầu tương tác người dùng bị hủy do phiên kết thúc'),
          );
        }
        continue;
      }

      _activeCount++;
      () async {
        try {
          if (next.isCancelled != null && next.isCancelled!()) {
            throw BridgeError.cancelled('Session is inactive or cancelled');
          }
          final result = await next.task();
          if (!next.completer.isCompleted) {
            next.completer.complete(result);
          }
        } catch (e, st) {
          if (!next.completer.isCompleted) {
            next.completer.completeError(e, st);
          }
        } finally {
          _activeCount--;
          _processNext();
        }
      }();
      break;
    }
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    for (final item in _queue) {
      if (!item.completer.isCompleted) {
        item.completer.completeError(
          BridgeError.cancelled('Phiên làm việc đã bị hủy'),
        );
      }
    }
    _queue.clear();
  }
}
