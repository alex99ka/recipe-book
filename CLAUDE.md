# ספר מתכונים (Flutter): context

The recipe book app on the `make-an-app` core (copied from `app-shell` on
2026-10-15). It replaces the Ionic app `alex99ka/recipe-book-app` (4.x) under
the same id and key; the plan and its phases are in that repo's
`docs/standard-plan.md` (phase 1a = this repo's 5.0.0).

- **Backend: the recipe server**, not Firestore: `C:\claude projects\cld\server`
  (FastAPI on the Pi, `/api/v1` through Tailscale Funnel). Recipes in Mealie,
  everything else in Postgres. `lib/recipes/api.dart` is the client.
- **Firebase = sign-in only**, project `alex-todo-shopping` (the to-do app's).
  Never read or write its Firestore from here. Access, min version and early
  users come from the server (`/me`, `/app-config`), see `lib/core/remote_config.dart`.
- Where `lib/core` differs from the starter, on purpose: `server.dart` (any
  JSON, X-Book header, Hebrew error messages), `remote_config.dart` (server,
  not Firestore), `auth.dart` (no `users/{uid}` write), `diagnostics.dart`,
  `report.dart`, `tour.dart` (this app's steps). Removed until their phase:
  notifications (5.4.0), export (5.5.0), home widgets in the manifest (5.3.0).
- Keep green: `flutter analyze`, `flutter test`; server: its pytest on the Pi.
- Shapes from the server are read with extension types over the JSON map;
  add a getter, not a model class.
