import 'package:flutter/material.dart';

import '../core/errors.dart';
import '../recipes/api.dart';
import 'recipe_widgets.dart';
import 'send_dialog.dart';
import 'skeleton.dart';

/// One cookbook's recipes: a scanned one in page order, or one of the book's
/// own in the order added, which can be renamed, sent to a friend or deleted.
class CookbookScreen extends StatefulWidget {
  const CookbookScreen(this.shelf, {super.key});
  final Shelf shelf;

  @override
  State<CookbookScreen> createState() => _CookbookScreenState();
}

class _CookbookScreenState extends State<CookbookScreen> {
  List<Summary>? _recipes;
  Object? _error;
  late String _title = widget.shelf.title;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Api.recipes(cookbook: widget.shelf.slug, collection: widget.shelf.id);
      if (mounted) setState(() { _recipes = r; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  ScaffoldMessengerState get _messenger => ScaffoldMessenger.of(context);

  Future<void> _rename() async {
    final title = await askTitle(context, 'שם הספר', initial: _title, ok: 'שמירה');
    if (title == null || title == _title) return;
    try {
      await Api.renameCollection(widget.shelf.id!, title);
      if (mounted) setState(() => _title = title);
    } catch (e) {
      showError(_messenger, e, 'השם לא נשמר');
    }
  }

  Future<void> _delete() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('למחוק את הספר „$_title”?'),
        content: const Text('רק הספר נמחק. המתכונים שבו נשארים בספר המתכונים.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('ביטול')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('מחיקה')),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await Api.deleteCollection(widget.shelf.id!);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      showError(_messenger, e, 'הספר לא נמחק');
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipes = _recipes;
    final own = widget.shelf.id != null;
    return Scaffold(
      appBar: AppBar(title: Text(_title), actions: [
        if (own)
          PopupMenuButton<VoidCallback>(
            tooltip: 'עוד',
            onSelected: (f) => f(),
            itemBuilder: (_) => [
              PopupMenuItem(value: _rename, child: const Text('שינוי שם')),
              PopupMenuItem(
                value: () => sendToFriend(context,
                    title: _title, send: (to, note) => Api.sendCollection(widget.shelf.id!, to, note)),
                child: const Text('שליחה לחבר'),
              ),
              PopupMenuItem(value: _delete, child: const Text('מחיקת הספר')),
            ],
          ),
      ]),
      body: _error != null && recipes == null
          ? Center(child: LoadError(_error!, retry: _load))
          : recipes == null
              ? const SkeletonList()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(children: [
                    if (recipes.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(48),
                        child: Text('אין עדיין מתכונים בספר הזה. מוסיפים מתוך מתכון: "הוספה לספר".',
                            textAlign: TextAlign.center),
                      ),
                    for (final r in recipes) RecipeTile(r, onBack: _load),
                  ]),
                ),
    );
  }
}
