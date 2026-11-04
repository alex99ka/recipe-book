# Graph Report - recipe-book  (2026-11-03)

## Corpus Check
- Corpus is ~49,186 words - fits in a single context window. You may not need a graph.

## Summary
- 1652 nodes · 2215 edges · 108 communities (77 shown, 31 thin omitted)
- Extraction: 98% EXTRACTED · 2% INFERRED · 0% AMBIGUOUS · INFERRED: 46 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- Recipe API and Models
- App Update System
- Project Documentation
- Share Intake
- Error Handling
- Home and Recipe Screens
- Product Walkthrough
- Localization and App Info
- Recipe Cooking View
- Android Activity Handling
- Launcher and Splash Art
- App Configuration
- Web Promotion Workflow
- Admin and Support Tools
- Preferences and Startup
- App Lock and Biometrics
- Errors and Duplicate Review
- Recipe Editing
- Photo Cache
- Package Dependencies
- Kitchen Display Controls
- Recipe Edit Screen
- Cookbook and Access
- Admin and Cookbook Screens
- Recipe Comments
- Windows Runner Integration
- Windows Flutter Host
- Access Gates
- Recipe Export Formats
- Export Dialog
- App Bootstrap
- Continuous Integration
- Google Authentication
- Cookbook Shelf
- Push Notifications
- Invite Acceptance
- Server Request Layer
- Android Home Widgets
- Remote App Updates
- Offline Recipe Cache
- Localization and Widgets
- Shared UI Workflows
- Release Build Jobs
- Friends and Aliases
- System Diagnostics
- Windows Native Startup
- Release Version Checks
- Release Workflow Setup
- Recipe Source Links
- Web App Manifest
- Sign-In Configuration
- Windows DPI Window
- Project Bootstrap Tool
- Flutter App Imports
- Android Release Signing
- Remote Access Configuration
- Native Splash Settings
- Export and Cache Tests
- Release Credentials
- API Test Fixtures
- Launcher Icon Settings
- Win32 Window Messages
- Problem Reports
- Windows Plugin Registration
- GitHub Release Metadata
- Web Wake and Reload
- App Info Tests
- Hosting Deployment
- Release Publication
- Recipe Navigation
- Loading Skeletons
- Package Metadata
- Cooking Screen Wake Lock
- Firebase Initialization
- Development Dependencies
- Bundled Font Assets
- Offline Cache Tests
- Recipe API Tests
- Web Icon Configuration
- Static Analysis Rules
- Recipe Scaling Tests
- Window Geometry Types
- Window Size Types
- Tour Spotlight Geometry
- Update Installers
- Recipe Data Shapes
- Update Source Types
- Update Download Flow
- Rubik Font License
- Tour Spotlight Painting
- Translation Catalog
- Web Reload Fallback
- Tour Target Widget
- Update Checksum
- GitHub Update Source
- Wake Lock Web Fallback
- Android Splash Background
- Night Splash Background
- Night Splash Versioned Background
- Versioned Splash Background

## God Nodes (most connected - your core abstractions)
1. `Steaming Open Cookbook Brand Mark` - 32 edges
2. `dependencies` - 22 edges
3. `Win32Window` - 21 edges
4. `with` - 19 edges
5. `env` - 12 edges
6. `Flutter Clients: Android, Web, and Windows` - 12 edges
7. `Application Overview` - 12 edges
8. `FlutterWindow` - 10 edges
9. `MainActivity` - 9 edges
10. `UpdateReceiver` - 9 edges

## Surprising Connections (you probably didn't know these)
- `Android 12 splash artwork for the recipe book` --semantically_similar_to--> `Steaming Open Cookbook Brand Mark`  [INFERRED] [semantically similar]
  android/app/src/main/res/drawable-hdpi/android12splash.png → assets/icon.png
- `Recipe book application icon asset` --semantically_similar_to--> `Steaming Open Cookbook Brand Mark`  [INFERRED] [semantically similar]
  android/app/src/main/res/drawable-hdpi/ic_launcher_foreground.png → assets/icon.png
- `Android splash artwork for the recipe book` --semantically_similar_to--> `Steaming Open Cookbook Brand Mark`  [INFERRED] [semantically similar]
  android/app/src/main/res/drawable-hdpi/splash.png → assets/icon.png
- `Android 12 splash artwork for the recipe book` --semantically_similar_to--> `Steaming Open Cookbook Brand Mark`  [INFERRED] [semantically similar]
  android/app/src/main/res/drawable-mdpi/android12splash.png → assets/icon.png
- `Recipe book application icon asset` --semantically_similar_to--> `Steaming Open Cookbook Brand Mark`  [INFERRED] [semantically similar]
  android/app/src/main/res/drawable-mdpi/ic_launcher_foreground.png → assets/icon.png

## Import Cycles
- None detected.

## Communities (108 total, 31 thin omitted)

### Community 0 - "Recipe API and Models"
Cohesion: 0.01
Nodes (126): acceptInvite, addCalendar, addComment, admin, AdminUser, adminUsers, alias, allTags (+118 more)

### Community 1 - "App Update System"
Cohesion: 0.04
Nodes (54): add, allowInstalls, assetFor, available, best, busy, canInstall, _channel (+46 more)

### Community 2 - "Project Documentation"
Cohesion: 0.06
Nodes (46): Cooking mode keeps the display awake, Duplicate recipe review, Display preferences, Recipe Book Feature and Release History, User-Facing Release History, Project Architecture and Safety Context, Development and Release Commands, Migration and Phased Product Plan (+38 more)

### Community 3 - "Share Intake"
Cohesion: 0.04
Nodes (40): _android, bytes, _channel, firstUrl, listenForShares, m, shareArrived, Shared (+32 more)

### Community 4 - "Error Handling"
Cohesion: 0.04
Nodes (45): accountDisabled, all, AppError, classify, code, dataUnavailable, detail, error (+37 more)

### Community 5 - "Home and Recipe Screens"
Cohesion: 0.05
Nodes (36): _add, _afterFirstLoad, _all, _browsing, _checkUpdates, children, _collections, _cookbooks (+28 more)

### Community 6 - "Product Walkthrough"
Cohesion: 0.04
Nodes (40): _all, body, build, child, createState, didUpdateWidget, dispose, _down (+32 more)

### Community 7 - "Localization and App Info"
Cohesion: 0.04
Nodes (36): AppInfo, build, false, isNewer, l, load, pa, parts (+28 more)

### Community 8 - "Recipe Cooking View"
Cohesion: 0.05
Nodes (33): Cost, c, _column, _comments, _cookingMode, createState, dispose, _edit (+25 more)

### Community 10 - "Launcher and Splash Art"
Cohesion: 0.06
Nodes (33): Android 12 splash artwork for the recipe book, Recipe book application icon asset, Android splash artwork for the recipe book, Android 12 splash artwork for the recipe book, Recipe book application icon asset, Android splash artwork for the recipe book, Android 12 splash artwork for the recipe book, Android 12 splash artwork for the recipe book (+25 more)

### Community 11 - "App Configuration"
Cohesion: 0.06
Nodes (29): AppConfig, githubRepo, googleDesktopClientId, googleDesktopSecret, googleWebClientId, name, releaseNotes, serverUrl (+21 more)

### Community 12 - "Web Promotion Workflow"
Cohesion: 0.06
Nodes (30): cancel-in-progress, group, FIREBASE_PROJECT, FIREBASE_SERVICE_ACCOUNT, GH_REPO, GH_TOKEN, HOSTING_SITE, TAG (+22 more)

### Community 13 - "Admin and Support Tools"
Cohesion: 0.07
Nodes (19): _checks, createState, DiagnosticsPage, _DiagnosticsPageState, _fingerprint, icon, initState, _messenger (+11 more)

### Community 14 - "Preferences and Startup"
Cohesion: 0.07
Nodes (23): TourLayer, _StartupError, _FileRow, _NoAccessScreen, UpdateRequiredScreen, _Header, _ShelfCard, _ShelfRow (+15 more)

### Community 15 - "App Lock and Biometrics"
Cohesion: 0.08
Nodes (24): AppLock, _AppLockState, _asking, auth, build, child, _clearSignedOut, createState (+16 more)

### Community 16 - "Errors and Duplicate Review"
Cohesion: 0.10
Nodes (13): messenger, reviewDuplicateRecipes, friends, go, messenger, note, sendToFriend, to (+5 more)

### Community 17 - "Recipe Editing"
Cohesion: 0.08
Nodes (20): askTitle, build, c, closed, deleteWithUndo, _edit, error, height (+12 more)

### Community 18 - "Photo Cache"
Cohesion: 0.08
Nodes (18): _bytes, CachedPhoto, _dir, f, files, hashCode, loadImage, obtainKey (+10 more)

### Community 19 - "Package Dependencies"
Cohesion: 0.08
Nodes (24): dependencies, crypto, file_selector, firebase_auth, firebase_core, firebase_messaging, flutter, flutter_localizations (+16 more)

### Community 20 - "Kitchen Display Controls"
Cohesion: 0.09
Nodes (22): PanelInfo, _addCalendar, _ask, _batteryIcon, build, _busy, _calendars, _confirm (+14 more)

### Community 21 - "Recipe Edit Screen"
Cohesion: 0.09
Nodes (21): build, _busy, _categories, createState, _delete, dispose, EditRecipeScreen, _EditRecipeScreenState (+13 more)

### Community 22 - "Cookbook and Access"
Cohesion: 0.10
Nodes (14): _block, build, createState, _error, initState, _load, _users, build (+6 more)

### Community 23 - "Admin and Cookbook Screens"
Cohesion: 0.14
Nodes (18): TourOverlay, _TourOverlayState, AdminScreen, _AdminScreenState, CookbookScreen, _CookbookScreenState, FriendsScreen, _FriendsScreenState (+10 more)

### Community 24 - "Recipe Comments"
Cohesion: 0.10
Nodes (20): Comments, build, _composer, createState, _data, dispose, _draft, _drafts (+12 more)

### Community 25 - "Windows Runner Integration"
Cohesion: 0.15
Nodes (8): EnableNonClientDpiScaling, Scale(), Win32Window::Win32Window(), WindowClassRegistrar, class_registered_, WindowClassRegistrar::GetWindowClass(), instance_, WindowClassRegistrar::UnregisterWindowClass()

### Community 26 - "Windows Flutter Host"
Cohesion: 0.11
Nodes (4): FlutterWindow, flutter_controller_, FlutterWindow::FlutterWindow(), project_

### Community 27 - "Access Gates"
Cohesion: 0.11
Nodes (16): _AccessGate, _AccessGateState, _allowed, _ask, _authChanges, build, _check, createState (+8 more)

### Community 28 - "Recipe Export Formats"
Cohesion: 0.10
Nodes (18): collections, csv, csvCell, doc, exportBook, h, image, json (+10 more)

### Community 29 - "Export Dialog"
Cohesion: 0.10
Nodes (17): BookExport, cleaned, day, export, exportBookFiles, exportRecipeFile, file, files (+9 more)

### Community 30 - "App Bootstrap"
Cohesion: 0.11
Nodes (11): App, _AppState, build, createState, dispose, error, home, _lifecycle (+3 more)

### Community 31 - "Continuous Integration"
Cohesion: 0.11
Nodes (18): runs-on, steps, timeout-minutes, jobs, app, name, on, pull_request (+10 more)

### Community 32 - "Google Authentication"
Cohesion: 0.11
Nodes (11): _allowedKey, _desktopCredential, _fb, _googleReady, lastKnownAccess, _random, rememberAccess, signInWithGoogle (+3 more)

### Community 33 - "Cookbook Shelf"
Cohesion: 0.11
Nodes (15): Shelf, build, createState, _delete, _error, initState, _load, messenger (+7 more)

### Community 34 - "Push Notifications"
Cohesion: 0.12
Nodes (14): enableWebNotifications, fcm, forgetThisDevice, _listening, _messenger, notificationPrefs, notificationTypes, pushSupported (+6 more)

### Community 35 - "Invite Acceptance"
Cohesion: 0.12
Nodes (12): acceptPendingInvite, code, didPushRouteInformation, inviteToken, linkPendingPanel, _Links, listenForInvites, panelCode (+4 more)

### Community 36 - "Server Request Layer"
Cohesion: 0.12
Nodes (12): fields, hasServer, mimeOf, req, res, _send, server, serverHeaders (+4 more)

### Community 37 - "Android Home Widgets"
Cohesion: 0.23
Nodes (3): open(), QuickAddWidget, SummaryWidget

### Community 38 - "Remote App Updates"
Cohesion: 0.14
Nodes (8): RemoteConfig, AppUpdater, apply, available, check, instance, lastChecked, WebUpdate

### Community 39 - "Offline Recipe Cache"
Cohesion: 0.14
Nodes (12): build, cached, k, keepRecipes, offline, OfflineBanner, prefs, recent (+4 more)

### Community 40 - "Localization and Widgets"
Cohesion: 0.14
Nodes (10): data, homeWidgetsSupported, _last, listenWidgetTaps, messenger, name, _package, pinHomeWidget (+2 more)

### Community 41 - "Shared UI Workflows"
Cohesion: 0.14
Nodes (4): main, pump, pumpWidget, recipe

### Community 42 - "Release Build Jobs"
Cohesion: 0.22
Nodes (14): needs, runs-on, steps, timeout-minutes, steps, android, steps, name (+6 more)

### Community 43 - "Friends and Aliases"
Cohesion: 0.14
Nodes (11): _alias, build, createState, _error, _friends, initState, _invite, _inviting (+3 more)

### Community 44 - "System Diagnostics"
Cohesion: 0.15
Nodes (11): Check, checks, errors, label, lastUpdate, ok, prefs, runDiagnostics (+3 more)

### Community 45 - "Windows Native Startup"
Cohesion: 0.19
Nodes (4): wWinMain(), CreateAndAttachConsole(), GetCommandLineArguments(), Utf8FromUtf16()

### Community 46 - "Release Version Checks"
Cohesion: 0.15
Nodes (13): permissions, version, web, version, contents, outputs, permissions, runs-on (+5 more)

### Community 47 - "Release Workflow Setup"
Cohesion: 0.15
Nodes (13): with, cache, distribution, flutter-version, if-no-files-found, java-version, merge-multiple, name (+5 more)

### Community 48 - "Recipe Source Links"
Cohesion: 0.17
Nodes (9): icon, label, launchUrl, LinkKind, LinkKindLook, on, openLink, _system (+1 more)

### Community 49 - "Web App Manifest"
Cohesion: 0.15
Nodes (12): background_color, description, dir, display, icons, lang, name, orientation (+4 more)

### Community 50 - "Sign-In Configuration"
Cohesion: 0.17
Nodes (7): build, _busy, createState, dispose, _error, _shake, _signIn

### Community 51 - "Windows DPI Window"
Cohesion: 0.21
Nodes (4): Win32Window, child_content_, quit_on_close_, window_handle_

### Community 53 - "Flutter App Imports"
Cohesion: 0.18
Nodes (3): main, needed, unescape

### Community 55 - "Android Release Signing"
Cohesion: 0.18
Nodes (11): env, needs, runs-on, steps, VERSION, android-sign, windows, env (+3 more)

### Community 56 - "Remote Access Configuration"
Cohesion: 0.18
Nodes (8): checkAccess, earlyUser, instance, listen, me, message, minVersion, tooOld

### Community 57 - "Native Splash Settings"
Cohesion: 0.18
Nodes (11): color, color_dark, icon_background_color, icon_background_color_dark, image, flutter_native_splash, android_12, color (+3 more)

### Community 58 - "Export and Cache Tests"
Cohesion: 0.20
Nodes (4): _lines, main, _recipe, main

### Community 59 - "Release Credentials"
Cohesion: 0.20
Nodes (10): ANDROID_KEY_ALIAS, ANDROID_KEYSTORE_BASE64, ANDROID_KEYSTORE_PASSWORD, FIREBASE_PROJECT, FIREBASE_SERVICE_ACCOUNT, GOOGLE_DESKTOP_CLIENT_ID, GOOGLE_DESKTOP_CLIENT_SECRET, env (+2 more)

### Community 60 - "API Test Fixtures"
Cohesion: 0.20
Nodes (3): main, main, main

### Community 61 - "Launcher Icon Settings"
Cohesion: 0.20
Nodes (10): flutter_launcher_icons, adaptive_icon_background, adaptive_icon_foreground, android, image_path, min_sdk_android, windows, generate (+2 more)

### Community 63 - "Problem Reports"
Cohesion: 0.22
Nodes (4): report, sendProblemReport, server, user

### Community 65 - "GitHub Release Metadata"
Cohesion: 0.22
Nodes (8): env, FLUTTER_VERSION, jobs, name, on, push, permissions, tags

### Community 66 - "Web Wake and Reload"
Cohesion: 0.25
Nodes (3): reloadPage, _sentinel, setWebWakeLock

### Community 67 - "App Info Tests"
Cohesion: 0.25
Nodes (3): main, rel, sources

### Community 68 - "Hosting Deployment"
Cohesion: 0.29
Nodes (8): concurrency, cancel-in-progress, group, concurrency, needs, permissions, runs-on, hosting

### Community 69 - "Release Publication"
Cohesion: 0.25
Nodes (8): GH_REPO, GH_TOKEN, TAG, release, env, needs, permissions, runs-on

### Community 70 - "Recipe Navigation"
Cohesion: 0.25
Nodes (7): build, _openPushed, _openShared, _open, build, _showOnScreen, build

### Community 71 - "Loading Skeletons"
Cohesion: 0.25
Nodes (6): build, createState, dispose, leading, _pulse, rows

### Community 72 - "Package Metadata"
Cohesion: 0.29
Nodes (6): description, environment, sdk, name, publish_to, version

### Community 74 - "Firebase Initialization"
Cohesion: 0.33
Nodes (3): android, DefaultFirebaseOptions, web

### Community 75 - "Development Dependencies"
Cohesion: 0.33
Nodes (6): dev_dependencies, flutter_launcher_icons, flutter_lints, flutter_native_splash, flutter_test, sdk

### Community 76 - "Bundled Font Assets"
Cohesion: 0.33
Nodes (6): flutter, fonts, uses-material-design, asset, family, fonts

### Community 79 - "Web Icon Configuration"
Cohesion: 0.40
Nodes (5): web, background_color, generate, image_path, theme_color

### Community 80 - "Static Analysis Rules"
Cohesion: 0.50
Nodes (3): analyzer, exclude, include

### Community 82 - "Window Geometry Types"
Cohesion: 0.50
Nodes (3): Point, x, y

### Community 83 - "Window Size Types"
Cohesion: 0.50
Nodes (3): Size, height, width

### Community 86 - "Update Installers"
Cohesion: 0.67
Nodes (3): AndroidUpdateInstaller, UpdateInstaller, WindowsUpdateInstaller

### Community 87 - "Recipe Data Shapes"
Cohesion: 1.00
Nodes (3): Recipe, Summary, Extension Types over Server JSON

## Knowledge Gaps
- **892 isolated node(s):** `AppConfig`, `name`, `githubRepo`, `webUrl`, `serverUrl` (+887 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 1195 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **31 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Are the 32 inferred relationships involving `Steaming Open Cookbook Brand Mark` (e.g. with `Android 12 splash artwork for the recipe book` and `Recipe book application icon asset`) actually correct?**
  _`Steaming Open Cookbook Brand Mark` has 32 INFERRED edges - model-reasoned connections that need verification._
- **What connects `AppConfig`, `name`, `githubRepo` to the rest of the system?**
  _892 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Recipe API and Models` be split into smaller, more focused modules?**
  _Cohesion score 0.014705882352941176 - nodes in this community are weakly interconnected._
- **Should `App Update System` be split into smaller, more focused modules?**
  _Cohesion score 0.03508771929824561 - nodes in this community are weakly interconnected._
- **Should `Project Documentation` be split into smaller, more focused modules?**
  _Cohesion score 0.05551020408163265 - nodes in this community are weakly interconnected._
- **Should `Share Intake` be split into smaller, more focused modules?**
  _Cohesion score 0.044326241134751775 - nodes in this community are weakly interconnected._
- **Should `Error Handling` be split into smaller, more focused modules?**
  _Cohesion score 0.043478260869565216 - nodes in this community are weakly interconnected._
`graphify-out/` was written into the working tree and is not ignored, so it appears in `git status`.
