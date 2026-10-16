import 'package:flutter/material.dart';

import '../core/errors.dart';
import '../core/remote_config.dart';
import '../recipes/api.dart';
import 'cookbook_screen.dart';
import 'recipe_screen.dart';
import 'recipe_widgets.dart';
import 'skeleton.dart';

/// What friends sent. The copies are already in the book: keep them, or
/// say no and they're deleted.
class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  List<InboxItem>? _items;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await Api.inbox();
      if (mounted) setState(() { _items = items; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _open(InboxItem i) {
    final Widget? screen = i.collectionId != null
        ? CookbookScreen(Shelf({'id': i.collectionId, 'title': i.title, 'count': i.count}))
        : i.recipeId != null
            ? RecipeScreen(i.recipeId!, title: i.title)
            : null;
    if (screen != null) {
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen)).then((_) => _load());
    }
  }

  Future<void> _settle(InboxItem i, {required bool keep}) async {
    if (!keep) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('למחוק את „${i.title}”?'),
          content: Text(i.collectionId != null
              ? 'הספר וכל המתכונים שהגיעו איתו יימחקו מהספר שלכם.'
              : 'המתכון יימחק מהספר שלכם.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('ביטול')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('מחיקה')),
          ],
        ),
      );
      if (yes != true || !mounted) return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Api.settle(i.id, keep: keep);
      if (mounted) setState(() => _items = [..._items!.where((x) => x.id != i.id)]);
      RemoteConfig.instance.checkAccess(null).ignore(); // the badge count
    } catch (e) {
      showError(messenger, e, 'לא נשמר');
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final muted = TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return Scaffold(
      appBar: AppBar(title: const Text('התקבל מחברים')),
      body: _error != null && items == null
          ? Center(child: LoadError(_error!, retry: _load))
          : items == null
              ? const SkeletonList()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(children: [
                    if (items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(48),
                        child: Text('אין כאן כלום כרגע. מה שחברים ישלחו יופיע כאן.',
                            textAlign: TextAlign.center, style: muted),
                      ),
                    for (final i in items)
                      Card(
                        margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          ListTile(
                            title: Text(i.title),
                            subtitle: Text([
                              '${i.collectionId != null ? 'ספר עם ${i.count} מתכונים' : 'מתכון'} · מאת ${i.from}',
                              if (i.note.isNotEmpty) '„${i.note}”',
                            ].join('\n')),
                            onTap: () => _open(i),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            child: Wrap(spacing: 8, children: [
                              FilledButton(
                                  onPressed: () => _settle(i, keep: true), child: const Text('שמירה בספר')),
                              OutlinedButton(
                                  onPressed: () => _settle(i, keep: false), child: const Text('לא צריך')),
                            ]),
                          ),
                        ]),
                      ),
                    const SizedBox(height: 24),
                  ]),
                ),
    );
  }
}
