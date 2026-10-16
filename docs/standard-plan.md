# Bringing ספר מתכונים up to the house standard

Audit of 2026-10-15 against the `make-an-app` standard (Defaults + core checklist), and the
phased plan to reach it. Status: **approved 2026-10-15, phases in order.** Phases 0, 1a and
1b done (5.1.0, 2026-10-16). This repo is the only one now: the Ionic app's repo
(`alex99ka/recipe-book-app`) is archived, and this plan moved here from it.

## Where the app is today (4.0.0)

- **Client:** Ionic 9 / Angular 22 / Capacitor 8. Android APK + web (Firebase Hosting
  `alex-recipe-book`). No Windows build.
- **Backend:** the recipe server on the Pi (FastAPI, `cld/server`), behind Tailscale Funnel
  at `/api/v1`. Recipes in **Mealie**, ownership/cookbooks/friends/comments/prices in
  **Postgres**, Hebrew by the Claude API. Firebase is used for **Auth only** (project
  `alex-todo-shopping`, shared with the to-do app); households are read from its Firestore.
- **Updates:** web layer from the release's `www.zip` (Capgo, applied on next start); APK
  versions download inside the app and open Android's installer (4.0.0).
- **Release:** version tag → CI builds a signed APK + web, scans for secrets, publishes a
  full release, deploys Hosting.

## Path: migrate to Flutter

The app isn't Flutter, so the standard says rewrite it on `app-shell`. **Keep the recipe
server, Mealie, Postgres and the Firebase project**: nobody loses a recipe, a cookbook, a
friend or a comment, because the app holds none of them. Ship under the **same id
(`com.alex99ka.recipes`) and the same key**, so it installs over 4.x in place. Two honest
costs: everyone **signs in with Google once more** (the WebView's session can't move into
Flutter), and device-only preferences (chosen book, tour seen) reset.

The 4.0.0 in-app installer is the bridge: a Flutter release is a new MAJOR (5.0.0), so the
Ionic app offers it as an APK and installs it from inside the app.

## Gap table

✅ meets · ⚠️ partial · ❌ missing · ↔ different on purpose

**Defaults**

| Topic | | Notes |
|---|---|---|
| Client | ❌ | Ionic/Angular, not Flutter → phase 1 |
| Backend | ↔ | Pi server + Mealie + Postgres, not Firestore. Recorded in `cld/docs/multi-user-spec.md`: Mealie, Claude translation and the TRMNL panel need a server. Firebase stays Auth-only |
| Server work | ✅ | Pi, Docker, Funnel |
| Cost | ↔ | Claude API for translation (the product's core), capped per book per month; copies sent to friends reuse the Hebrew |
| Language / RTL | ✅ | |
| Theme light + dark | ❌ | light only |
| Sign-in | ⚠️ | Google ✅, stays signed in ✅; allowlist is households + invites on the server (↔, recorded); no fingerprint |
| Updates | ⚠️ | in-app ✅ but not silent: APK needs taps; no Wi-Fi-only, no SHA check on the APK |
| Release | ⚠️ | tag → APK + web ✅; no Windows installer, no prerelease channel |
| Platforms | ⚠️ | Android + web; no Windows, no home widgets |

**Checklist**

| # | Item | | Notes |
|---|---|---|---|
| 1 | Versioning | ⚠️ | SemVer, tag = version, versionCode rule ✅; CHANGELOG entries are English and technical, not Hebrew/user-facing; version not on the sign-in screen |
| 2 | Release pipeline | ⚠️ | keystore in its own job ✅, secret scan ✅, Hosting ✅; no Windows installer; CI has no server pytest (it runs on the Pi by hand) |
| 3 | Patient zero | ❌ | releases go straight to everyone |
| 4 | In-app updates | ⚠️ | no PackageInstaller silent session, no Wi-Fi-only, no progress notification, no pre-sign-in check |
| 5 | Min version / kill switch | ❌ | |
| 6 | Sign-in | ⚠️ | no "אין גישה" screen (a server toast), no switch account, no last sign-in |
| 7 | Fingerprint | ❌ | |
| 8 | Notifications | ❌ | spec'd (friend sent, translation ready, comments) but not built; needs the FCM role |
| 9 | Errors with codes | ⚠️ | Hebrew messages from the server ✅, string codes not the letter catalog; several fetches have no timeout; a server crash showed as "no connection" (fixed server-side 15.10) |
| 10 | Problem report → Telegram | ❌ | |
| 11 | Diagnostics | ❌ | |
| 12 | Walkthrough | ⚠️ | interactive tour over real screens, replay from Settings ✅; no `since` tags / what's-new tour; steps explain rather than wait for the real tap |
| 13 | Settings set | ⚠️ | version, updates, tour, book, screen ✅; missing theme, fingerprint, notifications, switch account, last sign-in, diagnostics, report, export, security note |
| 14 | UI standards | ⚠️ | RTL ✅, splash + adaptive icon ✅; colour tokens partial; spinners not skeletons; confirm dialogs where undo fits; no long-press menus; no widgets; no share target |
| 15 | Data safety | ❌ | **no backup of Postgres or Mealie** (one manual tarball, 15.10). The SD card already corrupted Mealie's image once. No export, no offline cache |
| 16 | Security | ⚠️ | token on every route, rate limits, Funnel guard, 51 server tests ✅; keystore off-PC backup unverified; no Firestore rules here (Auth only) |
| 17 | Docs | ⚠️ | README + CHANGELOG ✅; no CLAUDE.md, TASKS.md, COMMANDS.md; README lacks Cost and Security sections |

## Phases

Each phase ships on its own as one release (or, for phase 0, with no app release).

### Phase 0: safety first (no app release) — done 2026-10-15
- [x] `cld/deploy/backup/backup.py` written; dry run on the Pi restored 195 recipes
- [x] CLAUDE.md, TASKS.md, COMMANDS.md, README Cost + Security
- [x] Drive OAuth + `.env`; first backup to Drive and **restore tested** (195 recipes, 585 photos)
- [x] nightly cron line, 03:30 (Alex)
- [ ] keystore copy on Drive (Alex, to confirm)
- Uptime Kuma: skipped for now (Alex, 15.10); backup failures still go to Telegram
- **Daily backup to Google Drive** from the Pi: `pg_dump` of the recipe DB + Mealie's
  `mealie.db` and images, dated, 30 kept, encrypted. Alert on failure. **Restore tested once.**
- Confirm the shared signing keystore (`todoshop`) is backed up off the PC (Drive).
- Uptime Kuma monitor on `/api/v1/health`.
- `CLAUDE.md`, `TASKS.md`, `COMMANDS.md`; README Cost + Security sections.
- *You notice:* nothing. *Risk:* none to data. *Verified:* a restore into a throwaway
  Postgres/Mealie shows the same recipe count.

### Phase 1a: Flutter app, reading parity, prerelease to Alex only (5.0.0) — done 2026-10-16 (5.0.1 on Alex's phone)
- [x] `C:\claude projects\recipe-book` from app-shell, id `com.alex99ka.recipes`, versionCode 5000000
- [x] screens below; analyze clean, 29 app tests; server 55 tests (4 new)
- [x] min version and early users from the **server** (`/app-config`, `/me.early`), not
  Firestore: the project is the to-do app's, so no rules change there is needed
- [x] problem report → server `/report` → Telegram; CORS for the `next` channel
- [ ] GitHub repo + secrets, server deploy, tag 5.0.0, install on Alex's phone, then 5.0.1
- New repo from `app-shell`, same id and key. Core wired as the starter has it: versioning,
  silent background updates (PackageInstaller), release pipeline (APK + Windows installer +
  web), patient-zero prereleases, min-version gate (`config/recipes` in Firestore), letter
  error codes, diagnostics, problem report.
- Screens: sign-in, home (search, my cookbooks, scanned cookbooks, recent), cookbook,
  recipe (Hebrew, ×1/×2/×3, rating, cost, TikTok, add to cookbook, shopping list, send,
  comments), settings (book switcher).
- *You notice:* one Google sign-in on your phone. Avital and friends stay on 4.x.
- *Risks:* the web app's Angular service worker must be retired cleanly (ship a
  self-unregistering worker); Firestore rules for `config/recipes` live in the to-do repo
  (shared project), deployed first with your OK.
- *Verified:* golden recipe screens against the live server; update 5.0.0 → 5.0.1 on your phone.

### Phase 1b: full parity (5.1.0) — done 2026-10-16
- Add, edit (photo, prices, delete), friends + invite links (App Link), inbox, screen
  linking + calendars, the tour with `since` tags.
- Promoted once Alex confirmed. Only Alex and his wife used 4.x, so there is no bridge
  release in the old repo: she installs the APK by hand (same key, over 4.x). The web
  gets Angular's safety worker at `ngsw-worker.js`, so the old PWA steps aside.
- *Verified:* 5.0.1 updated itself to 5.1.0 on Alex's phone; every 4.x flow works there.

### Phase 2: sign-in, errors, settings set — built 2026-10-16, ships in 5.3.0
Most of it came with the core in 5.0.0 (no-access screen, switch account, version on the
sign-in screen, error catalog, timeouts, theme, diagnostics, report). Added: last sign-in,
401 → sign-in screen, a deadline on the token refresh, a screenshot in the report, and the
nightly backup's time in diagnostics (server change, deployed when Alex is home). 5.2.0
went out as tag search + staying signed in (fingerprint only to sign back in).

- "אין גישה" screen for uninvited accounts, switch account, last sign-in, version on the
  sign-in screen, timeouts on every call, the full Settings set, security note.

### Phase 3: UI standard — built 2026-10-16, ships in 5.3.0
Done: undo toasts (comments, own cookbooks), long-press menus, two home widgets (newest
recipes, new recipe), share target (link/video/photo/PDF → new recipe), native splash, the
icon really light brown. Light/dark, fingerprint, skeletons and the tour came with 5.0.0.

- Light + dark from one tokens file, fingerprint opt-in, skeleton loaders, undo toasts
  (cookbook and comment deletes; recipe delete stays a confirm), long-press menus,
  what's-new tour, native splash.
- 2–3 Android home widgets (recently added, quick add, shopping list), share target:
  share a link/video/photo to the app to add a recipe.

### Phase 4: notifications (5.4.0)
- FCM from the Pi: a friend sent you something, a translation finished, a comment on your
  recipe, a new version; alert to you when a backup or job fails. Per-type toggles, web push.
- Needs from you: grant the service account "Firebase Cloud Messaging API Admin" (one command).

### Phase 5: data and offline (5.5.0)
- Export (JSON + CSV of recipes, cookbooks, prices) from Settings, offline cache of opened
  recipes for the kitchen, Hebrew user-facing CHANGELOG entries going forward.

The old Ionic repo is archived (2026-10-16): one repo, no bridge.
