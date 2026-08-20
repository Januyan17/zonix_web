import 'package:cloud_firestore/cloud_firestore.dart';

/// The forced-update gate the mobile app reads on cold start and on every
/// resume, from the single document `platform_config/appVersion`.
///
/// Both build fields are BUILD NUMBERS (the integer after "+" in the app's
/// pubspec version, i.e. its Android versionCode), never the dotted version
/// string. The floor is shared across platforms because both platforms are
/// built from that same pubspec version.
class AppVersionConfig {
  const AppVersionConfig({
    required this.minSupportedBuild,
    required this.latestBuild,
    required this.androidDownloadUrl,
    required this.iosDownloadUrl,
    required this.message,
    required this.updatedAt,
    required this.updatedBy,
  });

  /// Devices on a build below this are hard-blocked: the app shows a
  /// full-screen "Update required" and nothing else works. 0 blocks nobody.
  final int minSupportedBuild;

  /// The newest build that has been distributed. Devices below this get a
  /// dismissible nudge, not a block.
  final int latestBuild;

  /// Where an Android device gets the new build — a direct .apk link today,
  /// a Play listing later. The app opens it externally either way.
  final String androidDownloadUrl;

  /// The same for iOS (a TestFlight link today). Empty until there is an
  /// iOS build.
  final String iosDownloadUrl;

  /// Replaces the app's default copy on both the block screen and the nudge.
  /// Empty means the app uses its own wording.
  final String message;

  final DateTime? updatedAt;
  final String? updatedBy;

  /// Reads the document, or returns null when it does not exist yet. Null is
  /// a real state, not an error: until the document is created the app
  /// blocks nobody, which is the correct default — it must never be seeded
  /// with a made-up floor.
  static AppVersionConfig? fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    if (!snapshot.exists) return null;
    final data = snapshot.data() ?? const <String, dynamic>{};
    return AppVersionConfig(
      minSupportedBuild: (data['minSupportedBuild'] as num?)?.toInt() ?? 0,
      latestBuild: (data['latestBuild'] as num?)?.toInt() ?? 0,
      androidDownloadUrl: data['androidDownloadUrl'] as String? ?? '',
      iosDownloadUrl: data['iosDownloadUrl'] as String? ?? '',
      message: data['message'] as String? ?? '',
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      updatedBy: data['updatedBy'] as String?,
    );
  }
}
