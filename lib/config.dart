import 'dart:convert';

/// Everything a new app renames. The rest of lib/core is the shared standard
/// (see the make-an-app skill) and should not need editing per app.
abstract final class AppConfig {
  /// Shown in the title bar, sign-in screen, notifications and installer.
  static const name = 'ספר מתכונים';

  /// Where releases (and so in-app updates) live: owner/repo, public.
  static const githubRepo = 'alex99ka/recipe-book';

  /// The recipe server's /api/v1 on the Pi (Tailscale Funnel). It is the
  /// backend: recipes, cookbooks, friends, access, min version, reports.
  static const serverUrl = String.fromEnvironment('SERVER_URL',
      defaultValue: 'https://pi5-home-server-ts.tail4f470e.ts.net/api/v1');

  /// Google sign-in. Android: the Firebase project's *web* OAuth client id
  /// (Credential Manager needs it as serverClientId). Windows: a "Desktop app"
  /// OAuth client, whose secret Google documents as not secret for installed
  /// apps; it still comes from --dart-define so it isn't in git.
  static const googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID',
      defaultValue:
          '835092070723-frilc5sdv397qeh010vft7c6fvham4uo.apps.googleusercontent.com');
  static const googleDesktopClientId =
      String.fromEnvironment('GOOGLE_DESKTOP_CLIENT_ID');
  static const googleDesktopSecret =
      String.fromEnvironment('GOOGLE_DESKTOP_CLIENT_SECRET');

  /// This build's release notes (from CHANGELOG, injected by the release
  /// workflow), for the what's-new walkthrough. Base64, because Flutter's
  /// compilers reject newlines in a define; malformed = a cut-off last char.
  static final releaseNotes = utf8.decode(
      base64.decode(const String.fromEnvironment('RELEASE_NOTES')),
      allowMalformed: true).trim();
}
