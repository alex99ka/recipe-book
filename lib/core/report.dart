import 'package:firebase_auth/firebase_auth.dart';

import 'app_info.dart';
import 'diagnostics.dart';
import 'errors.dart';
import 'server.dart';

/// Settings › "דיווח על בעיה". Goes to the builder's Telegram through the home
/// server, which holds the bot token (the app never does).
Future<void> sendProblemReport(String text) async {
  final user = FirebaseAuth.instance.currentUser;
  final report = <String, dynamic>{
    'text': text,
    'email': user?.email,
    'version': AppInfo.versionLabel,
    'platform': AppInfo.platform,
    'errors': await recentErrors(),
    'diagnostics': [for (final c in await runDiagnostics()) '$c'],
  };
  await server('POST', '/report', report);
}
