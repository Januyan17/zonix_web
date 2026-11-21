/// Badge rules for the Device logins list. Kept out of the screen so they
/// are testable without pumping a widget, the same way
/// app_version_validation.dart is.
library;

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
