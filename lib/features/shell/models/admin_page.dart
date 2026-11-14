import 'package:zonixweb/features/shell/widgets/admin_shell.dart';

/// The top-level pages the nav rail switches between. Each one wraps itself
/// in an [AdminShell] and names itself here, so the rail highlights the
/// right entry without the shell having to inspect the route.
enum AdminPage {
  shops,
  overview,
  payments,
  appVersion,
  deviceLogins,
  historyRequests,
}
