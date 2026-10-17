import 'package:flutter/material.dart';

import '../core/errors.dart';
import '../recipes/api.dart';
import 'recipe_widgets.dart';
import 'send_dialog.dart';
import 'skeleton.dart';
import '../core/i18n.dart';

/// Opens a cookbook. A delete chosen inside happens here, behind the undo
/// toast: [hidden] hides or shows it again in the caller's list, [after] then
/// refreshes that list.
Future<void> openCookbook(BuildContext context, Shelf s,
    {void Function(bool hidden)? hidden, VoidCallback? after}) async {
  final messenger = ScaffoldMessenger.of(context);
  final r = await Navigator.push<String>(
      context, MaterialPageRoute(builder: (_) => CookbookScreen(s)));
  if (r == 'delete') {
    await deleteWithUndo(messenger,
        said: t('הספר „{0}” נמחק. המתכונים שבו נשארו.', [s.title]),
        hide: () => hidden?.call(true),
        restore: () => hidden?.call(false),
        delete: () => Api.deleteCollection(s.id!),
        failed: t('הספר לא נמחק'));
  }
  after?.call();
}

/// One cookbook's recipes: a scanned one in page order, or one of the book's
/// own in the order added, which can be renamed, sent to a friend or deleted.
class CookbookScreen extends StatefulWidget {
  const CookbookScreen(this.shelf, {super.key, this.tag});
  final Shelf shelf;

  /// Instead of a cookbook: every recipe with this tag or category.
  final String? tag;

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
      final r = await Api.recipes(
          cookbook: widget.shelf.slug, collection: widget.shelf.id, tag: widget.tag);
      if (mounted) setState(() { _recipes = r; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  ScaffoldMessengerState get _messenger => ScaffoldMessenger.of(context);

  Future<void> _rename() async {
    final title = await askTitle(context, t('שם הספר'), initial: _title, ok: t('שמירה'));
    if (title == null || title == _title) return;
    try {
      await Api.renameCollection(widget.shelf.id!, title);
      if (mounted) setState(() => _title = title);
    } catch (e) {
      showError(_messenger, e, t('השם לא נשמר'));
    }
  }

  /// The opener deletes it, behind an undo toast (see [openCookbook]).
  void _delete() => Navigator.pop(context, 'delete');

  @override
  Widget build(BuildContext context) {
    final recipes = _recipes;
    final own = widget.shelf.id != null;
    return Scaffold(
      appBar: AppBar(title: Text(Api.label(_title)), actions: [
        if (own)
          PopupMenuButton<VoidCallback>(
            tooltip: t('עוד'),
            onSelected: (f) => f(),
            itemBuilder: (_) => [
              PopupMenuItem(value: _rename, child: Text(t('שינוי שם'))),
              PopupMenuItem(
                value: () => sendToFriend(context,
                    title: Api.label(_title), send: (to, note) => Api.sendCollection(widget.shelf.id!, to, note)),
                child: Text(t('שליחה לחבר')),
              ),
              PopupMenuItem(value: _delete, child: Text(t('מחיקת הספר'))),
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
                      Padding(
                        padding: EdgeInsets.all(48),
                        child: Text(t('אין עדיין מתכונים בספר הזה. מוסיפים מתוך מתכון: "הוספה לספר".'),
                            textAlign: TextAlign.center),
                      ),
                    for (final r in recipes) RecipeTile(r, onBack: _load),
                  ]),
                ),
    );
  }
}
