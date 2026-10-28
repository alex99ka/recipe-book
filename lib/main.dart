import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'config.dart';
import 'core/app_info.dart';
import 'core/auth.dart';
import 'core/errors.dart';
import 'core/lock.dart';
import 'core/remote_config.dart';
import 'core/settings_store.dart';
import 'core/share_in.dart';
import 'core/tour.dart';
import 'core/update.dart';
import 'core/web_update.dart';
import 'firebase_options.dart';
import 'recipes/api.dart';
import 'recipes/invite.dart';
import 'ui/gates.dart';
import 'ui/theme.dart';
import 'core/i18n.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Errors nobody caught are kept for the problem report in Settings.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    recordError('X2', details.exception, details.stack);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    recordError('X2', error, stack);
    return true;
  };
  if (kReleaseMode) {
    // A broken widget says so in words, not a grey box.
    ErrorWidget.builder = (d) => Directionality(
          textDirection: SettingsStore.instance.lang == 'he' ? TextDirection.rtl : TextDirection.ltr,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(errorText(d.exception, t('המסך הזה לא נטען')),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTokens.danger)),
            ),
          ),
        );
  }
  await AppInfo.load();
  await SettingsStore.instance.load();
  await Api.loadBook();
  listenForInvites();
  listenForShares();

  // A throw before runApp is an invisible process on Windows (no window at
  // all), so startup failures become a screen with a code instead.
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)
        .timeout(const Duration(seconds: 20));
    await FirebaseAuth.instance.setLanguageCode(SettingsStore.instance.lang);
    RemoteConfig.instance.listen();
  } catch (e, stack) {
    recordError('X3', e, stack);
    runApp(App(home: _StartupError(e)));
    return;
  }

  // Before sign-in too: an update can be what fixes a broken sign-in.
  AppUpdater.instance?.checkIfDue();
  WebUpdate.instance.check();
  runApp(const App(home: Gates()));
}

class App extends StatefulWidget {
  const App({super.key, required this.home});
  final Widget home;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  // Windows: a downloaded update installs silently as the window closes.
  late final _lifecycle = AppLifecycleListener(
    onExitRequested: () async {
      await AppUpdater.instance?.installOnExit();
      return AppExitResponse.exit;
    },
  );

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _lifecycle; // start listening
    return ListenableBuilder(
      listenable: SettingsStore.instance,
      builder: (context, _) => MaterialApp(
        // A new language rebuilds every screen, so no word stays in the old one.
        key: ValueKey(SettingsStore.instance.lang),
        title: t(AppConfig.name),
        debugShowCheckedModeBanner: false,
        theme: appTheme(Brightness.light),
        darkTheme: appTheme(Brightness.dark),
        themeMode: SettingsStore.instance.themeMode,
        locale: Locale(SettingsStore.instance.lang),
        supportedLocales: [for (final l in languages.keys) Locale(l)],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: widget.home,
        // Links are handled in place (recipes/invite.dart), not as routes.
        initialRoute: '/',
        // The walkthrough over every screen, the fingerprint lock over that.
        builder: (context, screens) {
          final mq = MediaQuery.of(context);
          // The chosen text size on top of the device's own.
          return MediaQuery(
            data: mq.copyWith(textScaler: TextScaler.linear(
                mq.textScaler.scale(1) * SettingsStore.instance.textScale)),
            child: AppLock(
              signOut: Auth.signOut,
              signedIn: () {
                try {
                  return FirebaseAuth.instance.currentUser != null;
                } catch (_) {
                  return false; // Firebase never started
                }
              },
              child: TourLayer(child: screens!),
            ),
          );
        },
      ),
    );
  }
}

class _StartupError extends StatelessWidget {
  const _StartupError(this.error);
  final Object error;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              errorText(error, t('האפליקציה לא הצליחה להתחבר בהפעלה')),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
}
