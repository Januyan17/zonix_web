/// What a history request effectively means right now. Kept out of the
/// screen so the rule that decides whether a phone may download old months
/// is testable without pumping a widget, the same way
/// app_version_validation.dart is.
///
/// Must match the phone app: an approval is valid while
/// now < approved_at + 24 hours.
library;

import '../models/history_request.dart';

/// How long an approval lasts, counted from approved_at.
const historyApprovalWindow = Duration(hours: 24);

enum HistoryRequestState { pending, approved, expired, denied }

/// The effective state of a request.
///
/// [expiresAt] is set only for [HistoryRequestState.approved] and
/// [HistoryRequestState.expired], and only once approved_at is known.
typedef HistoryRequestStatus = ({
  HistoryRequestState state,
  DateTime? expiresAt,
});

/// [status] is the raw stored value. Anything other than "approved" or
/// "denied" — including missing — reads as pending, since the phone is the
/// only other writer and only ever writes "pending".
///
/// An "approved" request whose [approvedAt] is still null (the server
/// timestamp hasn't resolved yet, a moment after approving) counts as
/// approved with no known expiry yet, never as expired.
HistoryRequestStatus historyRequestStatus({
  required String status,
  required DateTime? approvedAt,
  required DateTime now,
}) {
  switch (status) {
    case 'denied':
      return (state: HistoryRequestState.denied, expiresAt: null);
    case 'approved':
      if (approvedAt == null) {
        return (state: HistoryRequestState.approved, expiresAt: null);
      }
      final expiresAt = approvedAt.add(historyApprovalWindow);
      return (
        state: now.isBefore(expiresAt)
            ? HistoryRequestState.approved
            : HistoryRequestState.expired,
        expiresAt: expiresAt,
      );
    default:
      return (state: HistoryRequestState.pending, expiresAt: null);
  }
}

/// "Expires in 5h 12m" for the time left until [expiresAt]. Minutes are
/// rounded up so the label never reads "0m" while still valid. Returns
/// "Expired" once [now] reaches [expiresAt].
String expiresInLabel({required DateTime expiresAt, required DateTime now}) {
  final remaining = expiresAt.difference(now);
  if (remaining <= Duration.zero) return 'Expired';
  final totalMinutes = (remaining.inSeconds / 60).ceil();
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (hours == 0) return 'Expires in ${minutes}m';
  return 'Expires in ${hours}h ${minutes}m';
}

/// Short display name for a state.
String historyRequestStateLabel(HistoryRequestState state) => switch (state) {
  HistoryRequestState.pending => 'Pending',
  HistoryRequestState.approved => 'Approved',
  HistoryRequestState.expired => 'Expired',
  HistoryRequestState.denied => 'Denied',
};

/// The effective status of [request] at [now].
HistoryRequestStatus statusOf(HistoryRequest request, DateTime now) =>
    historyRequestStatus(
      status: request.status,
      approvedAt: request.approvedAt,
      now: now,
    );

/// Splits [requests] into the ones still in play (pending, approved,
/// denied) and the approvals whose 24 hours have run out, keeping each
/// group in the original order. Used to show expired requests separately.
({List<HistoryRequest> current, List<HistoryRequest> expired}) splitExpired(
  Iterable<HistoryRequest> requests,
  DateTime now,
) {
  final current = <HistoryRequest>[];
  final expired = <HistoryRequest>[];
  for (final r in requests) {
    (statusOf(r, now).state == HistoryRequestState.expired ? expired : current)
        .add(r);
  }
  return (current: current, expired: expired);
}

/// True while any of [requests] is a live approval — i.e. something on
/// screen will change state (and move group) as time passes.
bool hasLiveApproval(Iterable<HistoryRequest> requests, DateTime now) =>
    requests.any((r) => statusOf(r, now).state == HistoryRequestState.approved);
