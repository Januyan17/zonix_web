/// Web's JS interop layer wraps failed JS promises in a generic Dart
/// exception whose toString() is just "Dart exception thrown from converted
/// Future...". The real reason is on its dynamic `.error` property. This
/// unwraps that when present, falling back to toString() otherwise.
String describeError(Object error) {
  try {
    // ignore: avoid_dynamic_calls
    final inner = (error as dynamic).error;
    if (inner != null) return inner.toString();
  } catch (_) {
    // error has no `.error` property (not a wrapped JS promise rejection).
  }
  return error.toString();
}
