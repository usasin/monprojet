import 'dart:async';

class ProspectSearchCancelled implements Exception {
  const ProspectSearchCancelled();
}

/// Cancels the visible wait without letting a late response change the screen.
/// The provider request itself may still finish and populate its normal cache.
class ProspectSearchSession {
  final Completer<void> _cancelled = Completer<void>();

  bool get isCancelled => _cancelled.isCompleted;

  void cancel() {
    if (!isCancelled) _cancelled.complete();
  }

  Future<T> waitFor<T>(Future<T> source, {required Duration timeout}) async {
    if (isCancelled) throw const ProspectSearchCancelled();
    final result = Completer<T>();
    final timer = Timer(timeout, () {
      if (!result.isCompleted) {
        result
            .completeError(TimeoutException('Search step timed out', timeout));
      }
    });
    source.then((value) {
      if (!result.isCompleted) result.complete(value);
    }, onError: (Object error, StackTrace stack) {
      if (!result.isCompleted) result.completeError(error, stack);
    });
    _cancelled.future.then((_) {
      if (!result.isCompleted) {
        result.completeError(const ProspectSearchCancelled());
      }
    });
    try {
      final value = await result.future;
      if (isCancelled) throw const ProspectSearchCancelled();
      return value;
    } finally {
      timer.cancel();
    }
  }
}
