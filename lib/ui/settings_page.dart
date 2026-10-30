import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../core/app_info.dart';
import '../core/auth.dart';
import '../core/diagnostics.dart';
import '../core/errors.dart';
import '../core/home_widgets.dart';
import '../core/lock.dart';
import '../core/notifications.dart';
import '../core/remote_config.dart';
import '../core/report.dart';
import '../core/settings_store.dart';
import '../core/tour.dart';
import '../core/update.dart';
import '../core/web_update.dart';
import '../recipes/api.dart';
import 'admin_screen.dart';
import 'export_dialog.dart';
import 'friends_screen.dart';
import 'panel_screen.dart';
import 'pick.dart';
import 'recipe_widgets.dart';
import 'skeleton.dart';
import '../core/i18n.dart';

/// The standard set, in this order: updates, sign-in and security, look,
/// help, account; the recipe app's book switcher first. Notifications
/// (5.4.0), data export (5.5.0) and the last sign-in (5.2.0) come back later.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool? _fingerprint;
  Map<String, bool>? _notify;

  @override
  void initState() {
    super.initState();
    fingerprintSetting().then((v) {
      if (mounted) setState(() => _fingerprint = v);
    });
    if (pushSupported) {
      notificationPrefs().then((v) {
        if (mounted) setState(() => _notify = v);
      }).ignore(); // offline: the switches just don't show
    }
  }

  Future<void> _setNotify(String type, bool on) async {
    setState(() => _notify = {..._notify!, type: on});
    try {
      final saved = await setNotificationPref(type, on);
      if (mounted) setState(() => _notify = saved);
    } catch (e) {
      if (mounted) setState(() => _notify = {..._notify!, type: !on});
      showError(_messenger, e, t('השינוי לא נשמר'));
    }
  }

  ScaffoldMessengerState get _messenger => ScaffoldMessenger.of(context);
  void _say(String text) => _messenger.showSnackBar(SnackBar(content: Text(text)));

  Future<void> _toggleFingerprint(bool on) async {
    if (!on) {
      await disableFingerprint();
      setState(() => _fingerprint = false);
      return;
    }
    final r = await enableFingerprint();
    if (!mounted) return;
    setState(() => _fingerprint = r == FingerprintResult.enabled);
    if (r == FingerprintResult.unsupported) _say(errorText(Errors.noBiometrics));
  }

  /// The site works everywhere; the APK is for Android phones. Where the
  /// system has no share sheet (some browsers), the text is copied instead.
  Future<void> _shareApp() async {
    final text = t('{0}\nבאתר, בכל טלפון, אייפד או מחשב: {1}\nלהתקנה באנדרואיד: https://github.com/{2}/releases/latest', [AppConfig.name, AppConfig.webUrl, AppConfig.githubRepo]);
    try {
      await SharePlus.instance.share(ShareParams(text: text));
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      _say(t('הקישורים הועתקו'));
    }
  }

  Future<void> _report() async {
    final c = TextEditingController();
    Picked? shot;
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text(t('דיווח על בעיה')),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: c,
              autofocus: true,
              maxLines: 5,
              decoration: InputDecoration(
                  hintText: t('מה קרה? מה ניסיתם לעשות?'),
                  helperText: t('יישלחו גם הגרסה, המכשיר והשגיאות האחרונות'),
                  helperMaxLines: 2),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                icon: Icon(shot == null ? Icons.add_photo_alternate_outlined : Icons.check),
                label: Text(shot == null ? t('צירוף צילום מסך (לא חובה)') : t('צורף: {0}', [shot!.$2])),
                onPressed: () async {
                  final p = await pickPhoto(ctx);
                  if (p != null) set(() => shot = p);
                },
              ),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('ביטול'))),
            FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: Text(t('שליחה'))),
          ],
        ),
      ),
    );
    if (text == null || text.trim().isEmpty) return;
    try {
      await sendProblemReport(text.trim(), screenshot: shot?.$1);
      _say(t('הדיווח נשלח. תודה!'));
    } catch (e) {
      showError(_messenger, e, t('שליחת הדיווח נכשלה'));
    }
  }

  Future<void> _whatsNew() async {
    // This version's own steps, else its release notes as one card.
    final steps = whatsNew(AppInfo.previousVersion(), AppInfo.version);
    final notes = steps.isEmpty ? await Api.releaseNotes() : '';
    if (!mounted) return;
    Navigator.pop(context);
    runningTour.value = steps.isNotEmpty
        ? steps
        : [
            TourStep(t('מה חדש בגרסה {0}', [AppInfo.version]),
                notes.isEmpty ? t('תיקונים ושיפורים.') : notes),
          ];
  }

  Future<void> _myName() async {
    final google = FirebaseAuth.instance.currentUser?.displayName ?? '';
    final name = await askTitle(context, t('השם שלי'),
        initial: Api.displayName.isEmpty ? google : Api.displayName,
        ok: t('שמירה'), hint: t('ריק = השם מחשבון Google'), allowEmpty: true);
    if (name == null || !mounted) return;
    try {
      await Api.setDisplayName(name == google ? '' : name);
      if (mounted) setState(() {});
    } catch (e) {
      showError(_messenger, e, t('השם לא נשמר'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final updater = AppUpdater.instance;
    return Scaffold(
      appBar: AppBar(title: Text(t('הגדרות'))),
      body: ListView(children: [
        if (Api.books.length > 1) ...[
          _Section(t('הספר')),
          ListenableBuilder(
            listenable: RemoteConfig.instance,
            builder: (context, _) => RadioGroup<String>(
              groupValue: Api.book,
              onChanged: (key) async {
                try {
                  await Api.setBook(key!);
                } catch (e) {
                  showError(_messenger, e, t('החלפת הספר נכשלה'));
                }
              },
              child: Column(children: [
                for (final b in Api.books)
                  RadioListTile<String>(title: Text(Api.label(b.title)), value: b.key),
              ]),
            ),
          ),
        ],
        _Section(t('שיתוף')),
        TourTarget(
          'settings.friends',
          child: ListTile(
            leading: const Icon(Icons.people_outline),
            title: Text(t('חברים')),
            subtitle: Text(t('הזמנה בקישור, ושליחת מתכונים זה לזה')),
            onTap: () => Navigator.push(
                context, MaterialPageRoute<void>(builder: (_) => const FriendsScreen())),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.share_outlined),
          title: Text(t('שיתוף האפליקציה')),
          subtitle: Text(t('קישור לאתר ולהורדה לאנדרואיד. כל אחד נכנס עם Google ומקבל ספר משלו')),
          onTap: _shareApp,
        ),
        TourTarget(
          'settings.panel',
          child: ListTile(
            leading: const Icon(Icons.tablet_outlined),
            title: Text(t('המסך במטבח')),
            subtitle: Text(t('סוללה, תצוגה, יומנים וחיבור המסך לספר')),
            onTap: () => Navigator.push(
                context, MaterialPageRoute<void>(builder: (_) => const PanelScreen())),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.checklist),
          title: Text(t('המשימות והקניות')),
          subtitle: Text(t('אותו חשבון ואותו בית')),
          trailing: const Icon(Icons.open_in_new),
          // The to-do app takes its own link over when installed; otherwise the web.
          onTap: () => launchUrl(Uri.parse('https://alex-todo-shopping.web.app'),
              mode: LaunchMode.externalApplication),
        ),
        if (homeWidgetsSupported)
          ListTile(
            leading: const Icon(Icons.widgets_outlined),
            title: Text(t('הוספת וידג׳ט למסך הבית')),
            subtitle: Text(t('המתכונים האחרונים, או כפתור למתכון חדש')),
            onTap: () => pinHomeWidget(context),
          ),
        _Section(t('עדכונים')),
        TourTarget(
          'settings.update',
          child: ListenableBuilder(
            listenable: Listenable.merge([updater, WebUpdate.instance]),
            builder: (context, _) => ListTile(
              leading: const Icon(Icons.system_update),
              // Only early users see whether this is a beta.
              title: Text(t('גרסה {0}{1}', [AppInfo.versionLabel, RemoteConfig.instance.earlyUser && updater?.runningBeta == true ? t(' · בטא') : ''])),
              subtitle: Text(updater == null
                  ? (WebUpdate.instance.available != null
                      ? t('גרסה {0} זמינה: רענון', [WebUpdate.instance.available])
                      : t('האתר מתעדכן לבד'))
                  : updater.checking
                      ? t('בודק…')
                      : updater.progress != null
                          ? t('מוריד… {0}%', [(updater.progress! * 100).round()])
                          : updater.error != null
                              ? errorText(updater.error!)
                              : updater.available != null
                                  ? (updater.ready && updater.installsByItself
                                      ? t('גרסה {0} תותקן לבד כשתצאו', [updater.available!.version])
                                      : t('גרסה {0} זמינה', [updater.available!.version]))
                                  : updater.lastResult ?? t('מתעדכן לבד ברקע')),
              trailing: updater?.available != null
                  ? FilledButton(onPressed: updater!.install, child: Text(t('עדכון')))
                  : TextButton(
                      onPressed: () => updater == null
                          ? (WebUpdate.instance.available != null
                              ? WebUpdate.instance.apply()
                              : WebUpdate.instance.check())
                          : updater.check(),
                      child: Text(t('בדיקה'))),
            ),
          ),
        ),
        if (updater != null && RemoteConfig.instance.earlyUser)
          ListenableBuilder(
            listenable: SettingsStore.instance,
            builder: (context, _) => SwitchListTile(
              secondary: const Icon(Icons.science_outlined),
              title: Text(t('גרסאות בטא')),
              subtitle: Text(t('מקבלים כל גרסה ראשונים, לפני שהיא עוברת לכולם. רק אצלך')),
              value: SettingsStore.instance.beta,
              onChanged: (on) {
                SettingsStore.instance.setBeta(on);
                updater.early = on;
              },
            ),
          ),
        ListTile(
          leading: const Icon(Icons.new_releases_outlined),
          title: Text(t('מה חדש בגרסה הזו')),
          onTap: _whatsNew,
        ),

        if (pushSupported) ...[
          _Section(t('התראות')),
          if (kIsWeb)
            ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: Text(t('התראות במכשיר הזה')),
              subtitle: Text(t('באייפד: רק מהאפליקציה שבמסך הבית')),
              onTap: () async => _say(await enableWebNotifications()),
            ),
          if (_notify case final n?)
            for (final e in notificationTypes.entries)
              SwitchListTile(
                title: Text(t(e.value)),
                value: n[e.key] ?? true,
                onChanged: (v) => _setNotify(e.key, v),
              ),
        ],

        _Section(t('כניסה ואבטחה')),
        if (_fingerprint != null)
          TourTarget(
            'settings.fingerprint',
            child: SwitchListTile(
              secondary: const Icon(Icons.fingerprint),
              title: Text(t('כניסה בטביעת אצבע')),
              subtitle: Text(t('אחרי יציאה, נכנסים שוב בטביעת אצבע במקום Google')),
              value: _fingerprint!,
              onChanged: _toggleFingerprint,
            ),
          ),
        ListTile(
          leading: Icon(Icons.shield_outlined),
          title: Text(t('מה מגן על הנתונים')),
          subtitle: Text(t('כל חשבון רואה רק את הספר שלו ושל בני הבית, והשרת בודק כל בקשה. המתכונים נשמרים בשרת בבית ומגובים כל לילה. מומלץ אימות דו-שלבי בחשבון Google.')),
        ),

        _Section(t('תצוגה')),
        // In all three at once, so it can be found from any of them.
        const ListTile(
          leading: Icon(Icons.translate),
          title: Text('שפה · Язык · Language'),
        ),
        // Each language in its own words, so the way back is readable.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SegmentedButton<String>(
            segments: [
              for (final e in languages.entries) ButtonSegment(value: e.key, label: Text(e.value)),
            ],
            selected: {SettingsStore.instance.lang},
            onSelectionChanged: (s) => SettingsStore.instance.setLang(s.first),
          ),
        ),
        ListenableBuilder(
          listenable: SettingsStore.instance,
          builder: (context, _) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<ThemeMode>(
              segments: [
                ButtonSegment(value: ThemeMode.system, label: Text(t('כמו במכשיר'))),
                ButtonSegment(value: ThemeMode.light, label: Text(t('בהיר'))),
                ButtonSegment(value: ThemeMode.dark, label: Text(t('כהה'))),
              ],
              selected: {SettingsStore.instance.themeMode},
              onSelectionChanged: (s) => SettingsStore.instance.setThemeMode(s.first),
            ),
          ),
        ),
        ListenableBuilder(
          listenable: SettingsStore.instance,
          builder: (context, _) => ListTile(
            leading: const Icon(Icons.format_size),
            title: Text(t('גודל הטקסט')),
            subtitle: Slider(
              value: SettingsStore.instance.textScale,
              min: 0.8,
              max: 1.6,
              divisions: 8,
              label: '${(SettingsStore.instance.textScale * 100).round()}%',
              onChanged: SettingsStore.instance.setTextScale,
            ),
          ),
        ),
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
          ListenableBuilder(
            listenable: SettingsStore.instance,
            builder: (context, _) => SwitchListTile(
              secondary: const Icon(Icons.screen_rotation_outlined),
              title: Text(t('סיבוב אוטומטי למסך רחב')),
              subtitle: Text(t('כבוי: המסך נשאר לאורך גם כשמסובבים את הטלפון או הטאבלט')),
              value: SettingsStore.instance.rotate,
              onChanged: SettingsStore.instance.setRotate,
            ),
          ),
        _Section(t('נתונים')),
        TourTarget(
          'settings.export',
          child: ListTile(
            leading: const Icon(Icons.download_outlined),
            title: Text(t('ייצוא הספר')),
            subtitle: Text(t('כל המתכונים והספרים, כקובץ JSON וקובץ CSV לאקסל')),
            onTap: () => exportBookFiles(context),
          ),
        ),
        _Section(t('עזרה')),
        TourTarget(
          'settings.tour',
          child: ListTile(
            leading: const Icon(Icons.school_outlined),
            title: Text(t('סיור באפליקציה')),
            subtitle: Text(t('הדרכה אינטראקטיבית בכל מה שיש כאן')),
            onTap: () {
              Navigator.pop(context);
              runningTour.value = fullTour;
            },
          ),
        ),
        TourTarget(
          'settings.report',
          child: ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: Text(t('דיווח על בעיה')),
            onTap: _report,
          ),
        ),
        ListTile(
          leading: const Icon(Icons.monitor_heart_outlined),
          title: Text(t('מצב המערכת')),
          onTap: () => Navigator.push(context,
              MaterialPageRoute<void>(builder: (_) => const DiagnosticsPage())),
        ),

        if (Api.isAdmin) ...[
          _Section(t('ניהול')),
          ListTile(
            leading: const Icon(Icons.admin_panel_settings_outlined),
            title: Text(t('ניהול משתמשים')),
            subtitle: Text(t('מי נכנס, הספרים שלהם, וחסימה')),
            onTap: () => Navigator.push(
                context, MaterialPageRoute<void>(builder: (_) => const AdminScreen())),
          ),
        ],
        _Section(t('חשבון')),
        ListTile(
          leading: const Icon(Icons.badge_outlined),
          title: Text(t('השם שלי')),
          subtitle: Text(t('{0} · כך חברים רואים אותך',
              [Api.displayName.isEmpty ? user?.displayName ?? '' : Api.displayName])),
          onTap: _myName,
        ),
        ListTile(
          leading: const Icon(Icons.account_circle_outlined),
          title: Text(user?.displayName ?? ''),
          subtitle: Text([
            user?.email ?? '',
            if (user?.metadata.lastSignInTime case final seen?) t('כניסה אחרונה: {0}', [shortDateTime(seen)]),
          ].join('\n')),
        ),
        ListTile(
          leading: const Icon(Icons.switch_account_outlined),
          title: Text(t('החלפת חשבון')),
          onTap: () async {
            Navigator.popUntil(context, (r) => r.isFirst);
            try {
              await Auth.switchAccount();
            } catch (e) {
              showError(_messenger, e, t('החלפת החשבון נכשלה'));
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: Text(t('יציאה')),
          onTap: () async {
            final yes = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: Text(t('לצאת מהחשבון?')),
                content: Text(_fingerprint == true
                    ? t('הכניסה הבאה בטביעת אצבע.')
                    : t('הכניסה הבאה תהיה שוב עם Google.')),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t('ביטול'))),
                  FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(t('יציאה'))),
                ],
              ),
            );
            if (yes != true || !context.mounted) return;
            Navigator.popUntil(context, (r) => r.isFirst);
            if (_fingerprint == true) {
              await signOutToFingerprint();
            } else {
              await Auth.signOut();
            }
          },
        ),
        const SizedBox(height: 32),
      ]),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
        child: Text(title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary)),
      );
}

class DiagnosticsPage extends StatefulWidget {
  const DiagnosticsPage({super.key});

  @override
  State<DiagnosticsPage> createState() => _DiagnosticsPageState();
}

class _DiagnosticsPageState extends State<DiagnosticsPage> {
  late Future<List<Check>> _checks = runDiagnostics();

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(t('מצב המערכת'))),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _checks = runDiagnostics());
          await _checks;
        },
        child: FutureBuilder<List<Check>>(
          future: _checks,
          builder: (context, snap) => !snap.hasData
              ? const SkeletonList(rows: 5)
              : ListView(children: [
                  for (final check in snap.data!)
                    ListTile(
                      leading: Icon(
                        check.ok == null
                            ? Icons.info_outline
                            : check.ok!
                                ? Icons.check_circle_outline
                                : Icons.error_outline,
                        color: check.ok == false ? c.error : c.primary,
                      ),
                      title: Text(check.label),
                      subtitle: Text(check.value),
                    ),
                ]),
        ),
      ),
    );
  }
}
