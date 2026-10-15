import 'package:flutter/foundation.dart';

import 'app_info.dart';
import 'errors.dart';
import 'server.dart';

/// The recipe app's backend is the Pi server, not Firestore (the Firebase
/// project is the to-do app's, used here for sign-in only), so both settings
/// come from there:
///
/// `GET /app-config` (public):  {minVersion, message}, from the server's .env
/// `GET /me` (signed in):       403 not_invited = no access; `early` = gets
///                              prereleases first (APP_EARLY_USERS)
class RemoteConfig extends ChangeNotifier {
  RemoteConfig._();
  static final instance = RemoteConfig._();

  String minVersion = '0.0.0';
  String message = '';

  /// Gets releases first (patient zero); everyone else waits for the
  /// prerelease to be promoted.
  bool earlyUser = false;

  /// The last /me: the books this account reads, and which one is open.
  Map<String, dynamic>? me;

  /// Below [minVersion]: the app shows only the update screen and does not
  /// call the server, so an old build never writes data in a shape it doesn't know.
  bool get tooOld => isNewer(minVersion, AppInfo.version);

  /// At start and on every return to the app (main and the home screen).
  Future<void> listen() async {
    try {
      final c = await server('GET', '/app-config') as Map<String, dynamic>;
      minVersion = '${c['minVersion'] ?? '0.0.0'}';
      message = '${c['message'] ?? ''}';
      notifyListeners();
    } catch (_) {} // offline: keep the last known values
  }

  /// Whether this account may use the app. The server decides (a to-do
  /// household, an invite, or an admin), not this code.
  Future<bool> checkAccess(String? email) async {
    try {
      me = await server('GET', '/me') as Map<String, dynamic>;
    } on ServerException catch (e) {
      if (e.status == 403) return false;
      rethrow;
    }
    earlyUser = me!['early'] == true;
    notifyListeners();
    return true;
  }
}
