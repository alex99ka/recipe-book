[![CI](https://github.com/alex99ka/recipe-book/actions/workflows/ci.yml/badge.svg)](https://github.com/alex99ka/recipe-book/actions/workflows/ci.yml)

# ספר מתכונים

The household recipe book: recipes from links, videos, photos and scanned
cookbooks, in Hebrew, shared with friends, and shown on the kitchen's e-ink
screen. One Flutter codebase for **Android, Web (the iPad) and Windows**, on
the `make-an-app` core (`alex99ka/app-shell`).

This replaces the Ionic app (`alex99ka/recipe-book-app`, archived, versions up to 4.x)
under the **same Android id and signing key**, so it installs over it in place.
The data never lived in the app, so nothing moves: everyone signs in with
Google once more.

## How it fits together

```
Android / Windows / Web ── Firebase Auth (Google, project alex-todo-shopping)
        │ ID token on every call
        ▼
Pi: recipe server /api/v1 (Tailscale Funnel) ── Mealie (recipes, photos)
        │                                     └─ Postgres (books, cookbooks,
        │                                        friends, comments, prices)
        ▼
GitHub Releases ◄── release.yml (tag): prerelease → early users
                    promote.yml → everyone + live web
```

- **Who gets in** is the server's call (`/me`): members of a to-do household,
  people a friend invited, admins. Others see "אין גישה".
- **Kill switch**: `APP_MIN_VERSION` in the server's `.env` → older builds show
  only "צריך לעדכן". **Patient zero**: `APP_EARLY_USERS` get prereleases.
- **Updates**: Android and Windows read this repo's releases, check the
  SHA-256, download in the background and install. The web checks
  `version.json`.
- **Errors** (`lib/core/errors.dart`) say what failed, why, what to do, and a
  letter code; the recipe server's Hebrew reasons come through as S5.

## Setup (once)

1. **GitHub** (public repo, so updates need no token): secrets
   `ANDROID_KEYSTORE_BASE64` and `ANDROID_KEYSTORE_PASSWORD` (the shared
   `todoshop` key, `~/.keystores/todo-shopping-release.p12`),
   `FIREBASE_SERVICE_ACCOUNT` (Hosting Admin only),
   `GOOGLE_DESKTOP_CLIENT_SECRET`; variables `ANDROID_KEY_ALIAS=todoshop`,
   `FIREBASE_PROJECT=alex-todo-shopping`, `GOOGLE_DESKTOP_CLIENT_ID`.
2. **Server** `.env`: `APP_EARLY_USERS`, `TELEGRAM_BOT_TOKEN`,
   `TELEGRAM_CHAT_ID` (see COMMANDS.md).
3. **Windows sign-in**: a *Desktop app* OAuth client in the project.
4. **Web on the `next` channel**: its domain in Firebase Auth → Authorized
   domains.

## Cost

| Service | Free limit | What uses it |
|---|---|---|
| Firebase Auth | Free | Sign-in. No Firestore reads or writes from this app. |
| Hosting | 10 GB stored, 360 MB a day | The web app (site `alex-recipe-book`) and its `next` channel. |
| GitHub Actions, Releases | Free for a public repo | CI, builds, update downloads. |
| GitHub API | 60 calls an hour per IP | The update check: at start and at most every 6 hours. |
| Claude API | Paid, capped per book per month on the server | Translating new recipes to Hebrew. Reading costs nothing. |
| Pi | Electricity | The recipe server, Mealie, Postgres, the nightly Drive backup. |

## Security

- The server checks the Firebase ID token and the allowlist on **every**
  call, rate-limits each account, and keeps recipes per book. Photos are
  signed URLs.
- **Secrets are never in the repo**: the keystore in `~/.keystores`, the
  server's `.env` on the Pi (mode 600). The Firebase config and the Google
  web client id are public by design.
- **Signing**: the keystore is decoded only on a runner that runs no project
  code, then deleted. A lost key means every user must uninstall to update.
- **Updates** install only if the SHA-256 matches the release and, on
  Android, the signature matches the installed app.

Known limits: anyone who can publish releases here can ship an update (keep
2FA on); the Windows installer is unsigned, so SmartScreen warns once.

## Versioning and releasing

SemVer in `pubspec.yaml`; the tag must equal it; versionCode is
`MAJOR*1000000 + MINOR*1000 + PATCH`. Move `[Unreleased]` in CHANGELOG.md
under the new version (in Hebrew, for the people using it), commit, then
`git tag X.Y.Z && git push --atomic origin master X.Y.Z`. When it's good on
your phone: `gh workflow run promote.yml -f version=X.Y.Z`.
