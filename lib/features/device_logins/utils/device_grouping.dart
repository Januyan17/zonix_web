/// Folds the flat `device_logins` list (one row per app install) into one
/// entry per physical device, and matches each device against the user's
/// live sessions. Pure functions so they're testable without widgets.
library;

import 'package:zonixweb/features/device_logins/models/device_login.dart';
import 'package:zonixweb/features/device_logins/models/device_session.dart';

/// Identifies one person in one shop — the unit sessions are stored under.
/// Null when either half is missing.
String? userKeyOf(DeviceLogin login) {
  if (login.shopId.isEmpty || login.userId.isEmpty) return null;
  return '${login.shopId}/${login.userId}';
}

/// Identifies one physical device for one person in one shop.
///
/// A reinstall gets a fresh device id, so the id alone can't tie installs
/// together; the model name + platform does. Two identical phone models used
/// by the same person in the same shop would merge — an accepted trade-off.
/// Rows with no model name fall back to their device id (or document id) so
/// they never merge with anything.
String deviceKeyOf(DeviceLogin login) {
  final name = login.deviceName.trim().toLowerCase();
  final device = name.isNotEmpty
      ? '${login.platform.toLowerCase()}:$name'
      : 'id:${login.deviceId.isNotEmpty ? login.deviceId : login.id}';
  return '${userKeyOf(login) ?? 'doc:${login.id}'}#$device';
}

/// One physical device and every install of the app on it that's loaded.
class DeviceGroup {
  DeviceGroup(
    this.key,
    List<DeviceLogin> installs, {
    List<DeviceLogin>? records,
  }) : assert(installs.isNotEmpty),
       installs = List.unmodifiable(installs),
       records = List.unmodifiable(records ?? installs);

  final String key;

  /// Every loaded document for this device, including repeat reports of
  /// the same install that [installs] hides — what a delete must remove.
  final List<DeviceLogin> records;

  /// The documents behind one install: it plus any repeat reports of it.
  List<DeviceLogin> recordsOf(DeviceLogin install) => [
    for (final r in records)
      if (r.id == install.id ||
          (install.deviceId.isNotEmpty && r.deviceId == install.deviceId))
        r,
  ];

  /// Newest first, as the query returns them.
  final List<DeviceLogin> installs;

  /// The most recent install — its user/shop/device/build describe the group.
  DeviceLogin get latest => installs.first;

  /// The oldest loaded install. Older pages may hold earlier ones.
  DeviceLogin get earliest => installs.last;

  int get installCount => installs.length;

  String? get userKey => userKeyOf(latest);

  Set<String> get deviceIds => {
    for (final i in installs)
      if (i.deviceId.isNotEmpty) i.deviceId,
  };

  /// The live session on any of this device's installs, newest login first.
  /// Null when signed out (or sessions aren't known).
  DeviceSession? activeSessionIn(List<DeviceSession>? sessions) {
    if (sessions == null) return null;
    final ids = deviceIds;
    DeviceSession? best;
    for (final s in sessions) {
      if (!ids.contains(s.deviceId)) continue;
      final bestAt = best?.loggedInAt;
      final at = s.loggedInAt;
      if (best == null ||
          (at != null && (bestAt == null || at.isAfter(bestAt)))) {
        best = s;
      }
    }
    return best;
  }
}

/// Groups [logins] (newest first) by [deviceKeyOf], keeping the groups in
/// the order of their newest install.
///
/// Within a group, records with the same device id are one install reported
/// twice (an app update moved the "already reported" flag from per-shop to
/// per-user), so only the oldest — the real first login — is kept.
List<DeviceGroup> groupDeviceLogins(Iterable<DeviceLogin> logins) {
  final byKey = <String, List<DeviceLogin>>{};
  for (final login in logins) {
    byKey.putIfAbsent(deviceKeyOf(login), () => []).add(login);
  }
  return [
    for (final e in byKey.entries)
      DeviceGroup(e.key, _dedupeInstalls(e.value), records: e.value),
  ];
}

List<DeviceLogin> _dedupeInstalls(List<DeviceLogin> newestFirst) {
  final seen = <String>{};
  final oldestFirst = <DeviceLogin>[];
  for (final login in newestFirst.reversed) {
    if (login.deviceId.isEmpty || seen.add(login.deviceId)) {
      oldestFirst.add(login);
    }
  }
  return oldestFirst.reversed.toList();
}

/// The distinct shop+user pairs across [groups], for fetching sessions —
/// one small query per person, not per row.
Set<String> userKeysOf(Iterable<DeviceGroup> groups) => {
  for (final g in groups)
    if (g.userKey != null) g.userKey!,
};
