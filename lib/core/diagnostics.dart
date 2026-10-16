import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_info.dart';
import 'errors.dart';
import 'server.dart';

/// One line of Settings › "מצב המערכת". [ok] null = not applicable.
class Check {
  const Check(this.label, this.value, {this.ok});
  final String label;
  final String value;
  final bool? ok;

  @override
  String toString() => '$label: $value';
}

/// Every check names what it looked at, so "something is wrong" becomes
/// "the server's backup is two days old" (the budget app's lesson: a vague
/// "offline" hid three different faults).
Future<List<Check>> runDiagnostics() async {
  final user = FirebaseAuth.instance.currentUser;
  final prefs = await SharedPreferences.getInstance();
  final lastUpdate = prefs.getString('update_last_check')?.split('|');
  final checks = <Check>[
    Check('גרסה', '${AppInfo.versionLabel} · ${AppInfo.platform}'),
    Check('חשבון', user?.email ?? 'לא מחובר', ok: user != null),
    Check(
      'בדיקת עדכונים אחרונה',
      lastUpdate == null
          ? 'עוד לא נבדק'
          : '${lastUpdate.first.substring(0, 16).replaceFirst('T', ' ')} · ${lastUpdate.last}',
    ),
  ];

  if (hasServer) {
    try {
      final h = await server('GET', '/health');
      checks.add(const Check('השרת בבית', 'עונה', ok: true));
      final backup = h['last_backup'] as String?;
      // The Pi's nightly Drive backup (backup.py) records it; null on an older server.
      if (backup != null) {
        final fresh = DateTime.now().difference(DateTime.parse(backup)).inHours < 36;
        checks.add(Check('גיבוי אחרון', backup.substring(0, 16), ok: fresh));
      }
    } catch (e) {
      final error = classify(e);
      checks.add(Check('השרת בבית', '${error.why} (קוד ${error.code})', ok: false));
    }
  }

  final errors = await recentErrors();
  checks.add(Check('שגיאות אחרונות',
      errors.isEmpty ? 'אין' : '${errors.length}, האחרונה: ${errors.first}',
      ok: errors.isEmpty ? true : null));
  return checks;
}
