import 'dart:async';

/// A simple concurrency limiter that ensures at most [maxConcurrent]
/// tasks run simultaneously. Additional tasks are queued and started
/// as running tasks complete.
class DownloadPool {
  final int maxConcurrent;
  int _running = 0;
  final List<_PendingTask> _queue = [];

  DownloadPool({required this.maxConcurrent});

  /// Acquire a slot. Resolves immediately if a slot is available,
  /// otherwise waits until one frees up.
  Future<void> acquire() async {
    if (_running < maxConcurrent) {
      _running++;
      return;
    }
    final completer = Completer<void>();
    _queue.add(_PendingTask(completer));
    return completer.future;
  }

  /// Release a slot and start the next queued task if any.
  void release() {
    if (_queue.isNotEmpty) {
      final next = _queue.removeAt(0);
      // Keep _running the same — we're handing the slot to the next task.
      next.completer.complete();
    } else {
      _running--;
    }
  }

  /// Number of tasks currently running.
  int get running => _running;

  /// Number of tasks waiting in the queue.
  int get queued => _queue.length;
}

class _PendingTask {
  final Completer<void> completer;
  _PendingTask(this.completer);
}
