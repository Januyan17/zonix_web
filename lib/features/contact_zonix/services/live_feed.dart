import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:zonixweb/core/utils/error_utils.dart';

/// A shared, lazily started live value backed by a stream (a Supabase
/// realtime `.stream()`), in the style of the portal's other shared
/// listeners: it subscribes when the first listener attaches and cancels
/// when the last one leaves, so the nav badge, overview card and pages
/// share one subscription. A dropped stream is retried after a pause.
class LiveFeed<T> extends ChangeNotifier {
  LiveFeed(this._open);

  final Stream<T> Function() _open;

  static const _retryDelay = Duration(seconds: 15);

  StreamSubscription<T>? _subscription;
  Timer? _retry;

  T? _value;
  String? _error;

  /// Null until the first event arrives.
  T? get value => _value;
  String? get error => _error;
  bool get loading => _value == null && _error == null;

  @override
  void addListener(VoidCallback listener) {
    final first = !hasListeners;
    super.addListener(listener);
    if (first) _start();
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) _stop();
  }

  /// Replaces the current value locally (optimistic updates). The next
  /// stream event overwrites it.
  void setLocal(T value) {
    _value = value;
    notifyListeners();
  }

  /// Drops the subscription and opens a fresh one, e.g. after the access
  /// token changed.
  void restart() {
    _stop();
    if (hasListeners) _start();
  }

  void _start() {
    if (_subscription != null) return;
    _retry?.cancel();
    try {
      _subscription = _open().listen(
        (value) {
          _value = value;
          _error = null;
          notifyListeners();
        },
        onError: (Object e) {
          _error = describeError(e);
          notifyListeners();
          _scheduleRetry();
        },
        onDone: _scheduleRetry,
      );
    } catch (e) {
      _error = describeError(e);
      // Deferred: this can run inside a widget's initState.
      scheduleMicrotask(() {
        notifyListeners();
        _scheduleRetry();
      });
    }
  }

  void _scheduleRetry() {
    _subscription?.cancel();
    _subscription = null;
    _retry?.cancel();
    if (!hasListeners) return;
    _retry = Timer(_retryDelay, () {
      if (hasListeners) _start();
    });
  }

  void _stop() {
    _retry?.cancel();
    _retry = null;
    _subscription?.cancel();
    _subscription = null;
  }
}
