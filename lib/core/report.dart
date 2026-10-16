import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';

import 'app_info.dart';
import 'diagnostics.dart';
import 'errors.dart';
import 'server.dart';

/// Settings › "דיווח על בעיה". Goes to the builder's Telegram through the home
/// server, which holds the bot token (the app never does).
/// [screenshot]: an image's bytes, sent after the text.
Future<void> sendProblemReport(String text, {List<int>? screenshot}) async {
  final user = FirebaseAuth.instance.currentUser;
  final report = <String, dynamic>{
    'text': text,
    'email': user?.email,
    'version': AppInfo.versionLabel,
    'platform': AppInfo.platform,
    'errors': await recentErrors(),
    'diagnostics': [for (final c in await runDiagnostics()) '$c'],
    if (screenshot != null) 'screenshot': base64Encode(screenshot),
  };
  await server('POST', '/report', report);
}
