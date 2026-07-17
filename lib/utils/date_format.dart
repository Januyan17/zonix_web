String formatShortDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

/// A human-readable "time ago" for recent dates, falling back to
/// [formatShortDate] once it's over a week old.
String formatRelativeDate(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) {
    final m = diff.inMinutes;
    return '$m minute${m == 1 ? '' : 's'} ago';
  }
  if (diff.inHours < 24) {
    final h = diff.inHours;
    return '$h hour${h == 1 ? '' : 's'} ago';
  }
  if (diff.inDays < 7) {
    final days = diff.inDays;
    return '$days day${days == 1 ? '' : 's'} ago';
  }
  return formatShortDate(d);
}
