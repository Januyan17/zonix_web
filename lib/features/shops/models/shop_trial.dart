import 'package:cloud_firestore/cloud_firestore.dart';

/// Default trial length, in days, written when a trial is switched on.
const kDefaultTrialDays = 7;

enum ShopTrialState {
  /// trial_enabled is missing or false — the mobile app works normally.
  off,

  /// Trial on and its end hasn't passed yet (or isn't known yet, for the
  /// moment between switching it on and the server timestamp resolving).
  active,

  /// Trial on and its end has passed — the mobile app is locked.
  ended,
}

/// The per-shop free-trial fields on `shops/{shopId}`, as the mobile app
/// reads them. The app locks itself once [trialEnabled] is true and
/// [endsAt] has passed; turning [trialEnabled] off unlocks it live.
class ShopTrial {
  const ShopTrial({
    this.trialEnabled = false,
    this.startedAt,
    this.days = kDefaultTrialDays,
    this.explicitEndsAt,
    this.message,
    this.contact,
  });

  final bool trialEnabled;

  /// Null when never started, or for a moment right after starting while
  /// the server timestamp is still pending.
  final DateTime? startedAt;

  final int days;

  /// trial_ends_at — set only by "extend trial". Takes priority over
  /// [startedAt] + [days] when present.
  final DateTime? explicitEndsAt;

  final String? message;
  final String? contact;

  factory ShopTrial.fromMap(Map<String, dynamic> map) {
    return ShopTrial(
      trialEnabled: map['trial_enabled'] as bool? ?? false,
      startedAt: _toDateTime(map['trial_started_at']),
      days: (map['trial_days'] as num?)?.toInt() ?? kDefaultTrialDays,
      explicitEndsAt: _toDateTime(map['trial_ends_at']),
      message: map['trial_message'] as String?,
      contact: map['trial_contact'] as String?,
    );
  }

  /// Tolerates anything that isn't a Timestamp (null, a pending server
  /// timestamp, a hand-edited value) by treating it as unknown rather than
  /// throwing — a malformed trial field must never break the shop page.
  static DateTime? _toDateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  /// trial_ends_at if present, otherwise trial_started_at + trial_days.
  /// Null when neither can be computed yet.
  DateTime? get endsAt {
    if (explicitEndsAt != null) return explicitEndsAt;
    final start = startedAt;
    if (start == null) return null;
    return start.add(Duration(days: days));
  }

  ShopTrialState stateAt(DateTime now) {
    if (!trialEnabled) return ShopTrialState.off;
    final end = endsAt;
    if (end == null || now.isBefore(end)) return ShopTrialState.active;
    return ShopTrialState.ended;
  }

  /// Whole days remaining, rounded up so a trial with hours left still
  /// reads as "1 day left" rather than "0 days left". Null if the end isn't
  /// known yet.
  int? daysLeftAt(DateTime now) {
    final end = endsAt;
    if (end == null) return null;
    final remaining = end.difference(now);
    if (remaining.isNegative) return 0;
    final days = (remaining.inMinutes / Duration.minutesPerDay).ceil();
    return days < 1 ? 1 : days;
  }
}
