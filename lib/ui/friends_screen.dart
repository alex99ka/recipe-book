import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/errors.dart';
import '../recipes/api.dart';
import 'recipe_widgets.dart';
import 'skeleton.dart';
import '../core/i18n.dart';

/// Friends get copies of recipes and cookbooks you send; they don't see your
/// book or join your household. Invite by a single-use link. The same people
/// are friends in the to-do app; the household is listed too, as it is there.
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  List<Friend>? _friends;
  Object? _error;
  bool _inviting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final f = await Api.friends(mates: true);
      if (mounted) setState(() { _friends = f; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  ScaffoldMessengerState get _messenger => ScaffoldMessenger.of(context);

  Future<void> _invite() async {
    setState(() => _inviting = true);
    final String url;
    try {
      url = await Api.createInvite();
    } catch (e) {
      showError(_messenger, e, t('הקישור לא נוצר'));
      return;
    } finally {
      if (mounted) setState(() => _inviting = false);
    }
    if (!mounted) return;
    final text = t('הזמנה לספר המתכונים שלי, כדי שנוכל לשלוח מתכונים זה לזה: {0}', [url]);
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t('קישור הזמנה')),
        content: Text(t('שלחו אותו לחבר. הוא תקף לשבוע ולחבר אחד.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(t('סגירה'))),
          TextButton(
            onPressed: () async {
              Navigator.pop(c);
              await Clipboard.setData(ClipboardData(text: url));
              _messenger.showSnackBar(SnackBar(content: Text(t('הקישור הועתק'))));
            },
            child: Text(t('העתקת הקישור')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(c);
              launchUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}'),
                  mode: LaunchMode.externalApplication);
            },
            child: Text(t('וואטסאפ')),
          ),
        ],
      ),
    );
  }

  Future<void> _remove(Friend f) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t('להסיר את {0}?', [f.name])),
        content: Text(t('מה שכבר שלחתם זה לזה נשאר אצל כל אחד.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t('ביטול'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(t('הסרה'))),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await Api.removeFriend(f.uid);
      if (mounted) setState(() => _friends = [..._friends!.where((x) => x.uid != f.uid)]);
    } catch (e) {
      showError(_messenger, e, t('החבר לא הוסר'));
    }
  }

  /// A name for them that only I see ("אמא"); empty = the name they chose.
  Future<void> _alias(Friend f) async {
    final alias = await askTitle(context, t('כינוי ל{0}', [f.chosen]),
        initial: f.alias, ok: t('שמירה'), hint: t('רק אתם רואים אותו. ריק = השם שבחרו'),
        allowEmpty: true);
    if (alias == null || alias == f.alias || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Api.setAlias(f.uid, alias);
      await _load();
    } catch (e) {
      showError(messenger, e, t('הכינוי לא נשמר'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final friends = _friends;
    final muted = TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return Scaffold(
      appBar: AppBar(title: Text(t('חברים'))),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(
                t('לחברים שולחים מתכון או ספר שלם, והם מקבלים עותק משלהם. הם לא רואים את הספר שלכם ולא מצטרפים לבית.'),
                style: muted),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: _inviting ? null : _invite,
              icon: const Icon(Icons.person_add_outlined),
              label: Text(t('הזמנת חבר')),
            ),
          ),
          if (_error != null && friends == null)
            LoadError(_error!, retry: _load)
          else if (friends == null)
            const SkeletonList(rows: 3, leading: false)
          else if (friends.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(t('עוד אין לכם חברים. הזמינו מישהו בקישור.'),
                  textAlign: TextAlign.center, style: muted),
            )
          else
            for (final f in friends)
              ListTile(
                leading: Icon(f.mate ? Icons.home_outlined : Icons.person_outline),
                title: Text(f.name),
                // With an alias, the name they chose too, so it's clear who it is.
                subtitle: f.mate || f.alias.isNotEmpty
                    ? Text([if (f.alias.isNotEmpty) f.chosen, if (f.mate) t('מהבית')].join(' · '))
                    : null,
                onTap: () => _alias(f),
                trailing: f.mate ? null : IconButton(
                  tooltip: t('הסרת {0}', [f.name]),
                  icon: const Icon(Icons.person_remove_outlined),
                  onPressed: () => _remove(f),
                ),
              ),
        ]),
      ),
    );
  }
}
