# Commands

Run from the repo root unless noted. Flutter: `/c/src/flutter/bin/flutter` (not on PATH).
The server is in `C:\claude projects\cld\server`; its commands are in that repo.

| Command | What it does |
|---|---|
| `flutter run -d windows` | Runs the app with hot reload (`r`, `R`, `q`). |
| `flutter analyze && flutter test` | Static checks and the unit tests. Must be clean. |
| `dart run flutter_launcher_icons` | Regenerates the icons from `assets/icon.png`. |
| `git tag X.Y.Z && git push --atomic origin master X.Y.Z` | Releases (a prerelease: only APP_EARLY_USERS get it). |
| `gh workflow run promote.yml -f version=X.Y.Z` | Makes a release everyone's, web included. |
| `gh release download X.Y.Z -p '*.apk' -D bridge`, `gh repo unarchive alex99ka/recipe-book-app`, `gh release create X.Y.Z bridge/*.apk -R alex99ka/recipe-book-app`, `gh repo archive alex99ka/recipe-book-app` | Bridge for a 4.x Ionic install: 4.x checks the old repo, sees a new MAJOR and installs the APK from inside the app. |
| `MSYS_NO_PATHCONV=1 iscc /Q /DAppVersion=X.Y.Z installer/app.iss` | Builds the Windows installer locally (Git Bash mangles `/Q` without the prefix). |

Server-side settings (the Pi, `~/docker/recipe-server/.env`, then recreate the container):

| Variable | What it does |
|---|---|
| `APP_MIN_VERSION`, `APP_MIN_MESSAGE` | Kill switch: older builds show only "צריך לעדכן". |
| `APP_EARLY_USERS` | Comma-separated emails that get prereleases (patient zero). |
| `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID` | Where "דיווח על בעיה" goes. |

## Don't

| | Why |
|---|---|
| Change `applicationId` (`com.alex99ka.recipes`) or the signing key (`todoshop`) | Installed apps, the Ionic 4.x ones included, can no longer update; users reinstall. |
| Edit `installer/app.iss` with a tool that drops the BOM | Inno Setup then garbles the Hebrew. |
| Write to Firestore from this app | The project is the to-do app's; its rules and its `users/{uid}` docs are that app's. |
| Pass an empty `--dart-define=SERVER_URL=` or `GOOGLE_WEB_CLIENT_ID=` | It overrides the built-in public value with nothing. |
