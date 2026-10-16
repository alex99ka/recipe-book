import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
import 'export_dialog.dart';
import 'friends_screen.dart';
import 'panel_screen.dart';
import 'pick.dart';
import 'skeleton.dart';

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
      showError(_messenger, e, 'השינוי לא נשמר');
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

  Future<void> _report() async {
    final c = TextEditingController();
    Picked? shot;
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('דיווח על בעיה'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: c,
              autofocus: true,
              maxLines: 5,
              decoration: const InputDecoration(
                  hintText: 'מה קרה? מה ניסיתם לעשות?',
                  helperText: 'יישלחו גם הגרסה, המכשיר והשגיאות האחרונות',
                  helperMaxLines: 2),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                icon: Icon(shot == null ? Icons.add_photo_alternate_outlined : Icons.check),
                label: Text(shot == null ? 'צירוף צילום מסך (לא חובה)' : 'צורף: ${shot!.$2}'),
                onPressed: () async {
                  final p = await pickPhoto(ctx);
                  if (p != null) set(() => shot = p);
                },
              ),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ביטול')),
            FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('שליחה')),
          ],
        ),
      ),
    );
    if (text == null || text.trim().isEmpty) return;
    try {
      await sendProblemReport(text.trim(), screenshot: shot?.$1);
      _say('הדיווח נשלח. תודה!');
    } catch (e) {
      showError(_messenger, e, 'שליחת הדיווח נכשלה');
    }
  }

  void _whatsNew() {
    // This version's own steps, else its release notes as one card.
    final steps = whatsNew(AppInfo.previousVersion(), AppInfo.version);
    Navigator.pop(context);
    runningTour.value = steps.isNotEmpty
        ? steps
        : [
            TourStep('מה חדש בגרסה ${AppInfo.version}',
                AppConfig.releaseNotes.isEmpty ? 'תיקונים ושיפורים.' : AppConfig.releaseNotes),
          ];
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final updater = AppUpdater.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('הגדרות')),
      body: ListView(children: [
        if (Api.books.length > 1) ...[
          _Section('הספר'),
          ListenableBuilder(
            listenable: RemoteConfig.instance,
            builder: (context, _) => RadioGroup<String>(
              groupValue: Api.book,
              onChanged: (key) async {
                try {
                  await Api.setBook(key!);
                } catch (e) {
                  showError(_messenger, e, 'החלפת הספר נכשלה');
                }
              },
              child: Column(children: [
                for (final b in Api.books)
                  RadioListTile<String>(title: Text(b.title), value: b.key),
              ]),
            ),
          ),
        ],
        _Section('שיתוף'),
        TourTarget(
          'settings.friends',
          child: ListTile(
            leading: const Icon(Icons.people_outline),
            title: const Text('חברים'),
            subtitle: const Text('הזמנה בקישור, ושליחת מתכונים זה לזה'),
            onTap: () => Navigator.push(
                context, MaterialPageRoute<void>(builder: (_) => const FriendsScreen())),
          ),
        ),
        TourTarget(
          'settings.panel',
          child: ListTile(
            leading: const Icon(Icons.tablet_outlined),
            title: const Text('המסך במטבח'),
            subtitle: const Text('חיבור המסך לספר, והיומנים שהוא מציג'),
            onTap: () => Navigator.push(
                context, MaterialPageRoute<void>(builder: (_) => const PanelScreen())),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.checklist),
          title: const Text('המשימות והקניות'),
          subtitle: const Text('אותו חשבון ואותו בית'),
          trailing: const Icon(Icons.open_in_new),
          // The to-do app takes its own link over when installed; otherwise the web.
          onTap: () => launchUrl(Uri.parse('https://alex-todo-shopping.web.app'),
              mode: LaunchMode.externalApplication),
        ),
        if (homeWidgetsSupported)
          ListTile(
            leading: const Icon(Icons.widgets_outlined),
            title: const Text('הוספת וידג׳ט למסך הבית'),
            subtitle: const Text('המתכונים האחרונים, או כפתור למתכון חדש'),
            onTap: () => pinHomeWidget(context),
          ),
        _Section('עדכונים'),
        TourTarget(
          'settings.update',
          child: ListenableBuilder(
            listenable: Listenable.merge([updater, WebUpdate.instance]),
            builder: (context, _) => ListTile(
              leading: const Icon(Icons.system_update),
              title: Text('גרסה ${AppInfo.versionLabel}'),
              subtitle: Text(updater == null
                  ? (WebUpdate.instance.available != null
                      ? 'גרסה ${WebUpdate.instance.available} זמינה: רענון'
                      : 'האתר מתעדכן לבד')
                  : updater.checking
                      ? 'בודק…'
                      : updater.progress != null
                          ? 'מוריד… ${(updater.progress! * 100).round()}%'
                          : updater.error != null
                              ? errorText(updater.error!)
                              : updater.available != null
                                  ? (updater.ready && updater.installsByItself
                                      ? 'גרסה ${updater.available!.version} תותקן לבד כשתצאו'
                                      : 'גרסה ${updater.available!.version} זמינה')
                                  : updater.lastResult ?? 'מתעדכן לבד ברקע'),
              trailing: updater?.available != null
                  ? FilledButton(onPressed: updater!.install, child: const Text('עדכון'))
                  : TextButton(
                      onPressed: () => updater == null
                          ? (WebUpdate.instance.available != null
                              ? WebUpdate.instance.apply()
                              : WebUpdate.instance.check())
                          : updater.check(),
                      child: const Text('בדיקה')),
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.new_releases_outlined),
          title: const Text('מה חדש בגרסה הזו'),
          onTap: _whatsNew,
        ),

        if (pushSupported) ...[
          _Section('התראות'),
          if (kIsWeb)
            ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: const Text('התראות במכשיר הזה'),
              subtitle: const Text('באייפד: רק מהאפליקציה שבמסך הבית'),
              onTap: () async => _say(await enableWebNotifications()),
            ),
          if (_notify case final n?)
            for (final e in notificationTypes.entries)
              SwitchListTile(
                title: Text(e.value),
                value: n[e.key] ?? true,
                onChanged: (v) => _setNotify(e.key, v),
              ),
        ],

        _Section('כניסה ואבטחה'),
        if (_fingerprint != null)
          TourTarget(
            'settings.fingerprint',
            child: SwitchListTile(
              secondary: const Icon(Icons.fingerprint),
              title: const Text('כניסה בטביעת אצבע'),
              subtitle: const Text('אחרי יציאה, נכנסים שוב בטביעת אצבע במקום Google'),
              value: _fingerprint!,
              onChanged: _toggleFingerprint,
            ),
          ),
        const ListTile(
          leading: Icon(Icons.shield_outlined),
          title: Text('מה מגן על הנתונים'),
          subtitle: Text('רק בני הבית וחברים שהוזמנו נכנסים, והשרת בודק כל בקשה. '
              'המתכונים נשמרים בשרת בבית ומגובים כל לילה. '
              'מומלץ אימות דו-שלבי בחשבון Google.'),
        ),

        _Section('תצוגה'),
        ListenableBuilder(
          listenable: SettingsStore.instance,
          builder: (context, _) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('כמו במכשיר')),
                ButtonSegment(value: ThemeMode.light, label: Text('בהיר')),
                ButtonSegment(value: ThemeMode.dark, label: Text('כהה')),
              ],
              selected: {SettingsStore.instance.themeMode},
              onSelectionChanged: (s) => SettingsStore.instance.setThemeMode(s.first),
            ),
          ),
        ),
        _Section('נתונים'),
        TourTarget(
          'settings.export',
          child: ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('ייצוא הספר'),
            subtitle: const Text('כל המתכונים והספרים, כקובץ JSON וקובץ CSV לאקסל'),
            onTap: () => exportBookFiles(context),
          ),
        ),
        _Section('עזרה'),
        TourTarget(
          'settings.tour',
          child: ListTile(
            leading: const Icon(Icons.school_outlined),
            title: const Text('סיור באפליקציה'),
            subtitle: const Text('הדרכה אינטראקטיבית בכל מה שיש כאן'),
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
            title: const Text('דיווח על בעיה'),
            onTap: _report,
          ),
        ),
        ListTile(
          leading: const Icon(Icons.monitor_heart_outlined),
          title: const Text('מצב המערכת'),
          onTap: () => Navigator.push(context,
              MaterialPageRoute<void>(builder: (_) => const DiagnosticsPage())),
        ),

        _Section('חשבון'),
        ListTile(
          leading: const Icon(Icons.account_circle_outlined),
          title: Text(user?.displayName ?? ''),
          subtitle: Text([
            user?.email ?? '',
            if (user?.metadata.lastSignInTime case final t?) 'כניסה אחרונה: ${shortDateTime(t)}',
          ].join('\n')),
        ),
        ListTile(
          leading: const Icon(Icons.switch_account_outlined),
          title: const Text('החלפת חשבון'),
          onTap: () async {
            Navigator.popUntil(context, (r) => r.isFirst);
            try {
              await Auth.switchAccount();
            } catch (e) {
              showError(_messenger, e, 'החלפת החשבון נכשלה');
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('יציאה'),
          onTap: () async {
            final yes = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('לצאת מהחשבון?'),
                content: Text(_fingerprint == true
                    ? 'הכניסה הבאה בטביעת אצבע.'
                    : 'הכניסה הבאה תהיה שוב עם Google.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('ביטול')),
                  FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('יציאה')),
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
      appBar: AppBar(title: const Text('מצב המערכת')),
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
