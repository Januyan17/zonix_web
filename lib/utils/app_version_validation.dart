/// Validation for the forced-update gate the mobile app reads from
/// `platform_config/appVersion`. Kept out of the screen so the rules that
/// decide whether every till in the field gets locked out are testable
/// without pumping a widget.
///
/// Every number here is a BUILD NUMBER — the integer after the "+" in the
/// app's pubspec version, which is also its Android versionCode. The dotted
/// "1.0.3" string is never compared or stored: as text, "1.0.10" sorts below
/// "1.0.9".
library;

/// Matches an absolute http(s) URL with a host. A relative path, a bare
/// "example.com", or a "javascript:" scheme all fail — the app hands this
/// value straight to the OS to open externally, so it has to stand alone.
bool isAbsoluteHttpUrl(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null) return false;
  if (!uri.hasScheme || !uri.hasAuthority) return false;
  return uri.scheme == 'http' || uri.scheme == 'https';
}

/// Validation message for a build-number field, or null when it's acceptable.
///
/// [min] is 0 for the floor and 1 for the latest build: a floor of 0 is the
/// correct "block nobody" resting state and is what the document is first
/// created with, whereas there is no such thing as a distributed build 0.
String? buildNumberError(String? raw, {required int min}) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty) return 'Required';
  final parsed = int.tryParse(value);
  if (parsed == null) {
    return 'Whole numbers only — this is the build number, not "1.0.3"';
  }
  if (parsed < min) return 'Must be $min or higher';
  return null;
}

/// Message for the case that strands every device: a floor above the newest
/// build anyone can actually download.
String? buildOrderError({required int minSupportedBuild, required int latestBuild}) {
  if (minSupportedBuild <= latestBuild) return null;
  return 'The floor is above the newest build that exists. Every device '
      'would be locked out with nothing available to install.';
}

/// Message for the Android download link. Required as soon as the floor
/// blocks anyone — a block with no link strands every user. (The app does
/// degrade to "contact your admin" copy, but the portal should not be the
/// thing that causes it.)
String? androidDownloadUrlError(String? raw, {required int minSupportedBuild}) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty) {
    if (minSupportedBuild > 0) {
      return 'Required — a block with no download link strands every user';
    }
    return null;
  }
  if (!isAbsoluteHttpUrl(value)) {
    return 'Must be a full URL starting with https://';
  }
  return null;
}

/// Message for the optional iOS link: no floor-dependent requirement, since
/// there may be no iOS build at all, but it must still be a real URL if set.
String? iosDownloadUrlError(String? raw) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty) return null;
  if (!isAbsoluteHttpUrl(value)) {
    return 'Must be a full URL starting with https://';
  }
  return null;
}
