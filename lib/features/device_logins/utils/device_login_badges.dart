/// Badge rules for the Device logins list. Kept out of the screen so they
/// are testable without pumping a widget, the same way
/// app_version_validation.dart is.
library;

import 'package:zonixweb/features/device_logins/models/device_login.dart';

/// True when the install logged in on a build below the current
/// forced-update floor (minSupportedBuild in platform_config/appVersion).
///
/// Unknown on either side never flags: a missing [appBuild] can't be judged,
/// and a null or 0 floor blocks nobody, so nothing is "old" against it.
bool isOldBuild({required int? appBuild, required int? minSupportedBuild}) {
  if (appBuild == null || minSupportedBuild == null) return false;
  if (minSupportedBuild <= 0) return false;
  return appBuild < minSupportedBuild;
}

/// The key that identifies one person in one shop, for repeat detection.
/// Null when either half is missing — such a document can't be matched.
String? repeatInstallKey(DeviceLogin login) {
  if (login.shopId.isEmpty || login.userId.isEmpty) return null;
  return '${login.shopId}/${login.userId}';
}

/// The shop+user keys that appear more than once in [logins] — i.e. the
/// same person has installed (or reinstalled) the app more than once.
/// Only counts what's loaded, so it's "repeat within these results", not
/// across the whole collection.
Set<String> repeatInstallKeys(Iterable<DeviceLogin> logins) {
  final seen = <String>{};
  final repeats = <String>{};
  for (final login in logins) {
    final key = repeatInstallKey(login);
    if (key == null) continue;
    if (!seen.add(key)) repeats.add(key);
  }
  return repeats;
}

/// Whether [login] should carry the "Repeat install" badge, given the
/// result of [repeatInstallKeys] over the loaded list.
bool isRepeatInstall(DeviceLogin login, Set<String> repeatKeys) {
  final key = repeatInstallKey(login);
  return key != null && repeatKeys.contains(key);
}
