import 'package:flutter/material.dart';

import '../core/errors.dart';
import '../recipes/api.dart';
import 'recipe_widgets.dart';
import '../core/i18n.dart';

/// Comments at the bottom of a recipe: the book's own, and on an original,
/// one conversation per friend it was sent to.
class RecipeComments extends StatefulWidget {
  const RecipeComments(this.recipeId, {super.key});
  final String recipeId;

  @override
  State<RecipeComments> createState() => RecipeCommentsState();
}

class RecipeCommentsState extends State<RecipeComments> {
  Comments? _data;

  /// Deleted, waiting out the undo toast.
  final _hidden = <int>{};

  /// Unsent text per conversation: '' is the recipe's own, otherwise a copy id.
  final _drafts = <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    for (final c in _drafts.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> load() async {
    try {
      final d = await Api.comments(widget.recipeId);
      if (mounted) setState(() => _data = d);
    } catch (_) {
      // Comments are extra: the recipe still reads fine without them.
    }
  }

  TextEditingController _draft(String key) => _drafts.putIfAbsent(key, TextEditingController.new);

  Future<void> _post(String key) async {
    final body = _draft(key).text.trim();
    if (body.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Api.addComment(widget.recipeId, body, thread: key.isEmpty ? null : key);
      _draft(key).clear();
      await load();
    } catch (e) {
      showError(messenger, e, t('התגובה לא נשלחה'));
    }
  }

  Future<void> _remove(Comment c) async {
    void shown(bool hidden) {
      if (mounted) setState(() => hidden ? _hidden.add(c.id) : _hidden.remove(c.id));
    }

    await deleteWithUndo(ScaffoldMessenger.of(context),
        said: t('התגובה נמחקה'),
        hide: () => shown(true),
        restore: () => shown(false),
        delete: () => Api.deleteComment(c.id),
        failed: t('התגובה לא נמחקה'));
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    if (d == null) return const SizedBox.shrink();
    final muted = TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _header(context, t('תגובות')),
      if (d.sentBy != null)
        _hint(t('המתכון הגיע מ{0}, שרואה גם את התגובות כאן.', [d.sentBy]), muted),
      ..._list(d.comments, t('אין עדיין תגובות. בישלתם? ספרו איך יצא.'), muted),
      _composer('', t('תגובה')),
      for (final th in d.threads) ...[
        _header(context, t('שיחה עם {0}', [th.friend.isEmpty ? t('חבר') : th.friend])),
        ..._list(th.comments, t('עוד לא כתבתם זה לזה על המתכון.'), muted),
        _composer(th.copyId, t('תשובה ל{0}', [th.friend.isEmpty ? t('חבר') : th.friend])),
      ],
    ]);
  }

  Widget _header(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );

  Widget _hint(String text, TextStyle style) =>
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(text, style: style));

  List<Widget> _list(List<Comment> comments, String empty, TextStyle muted) => comments.isEmpty
      ? [_hint(empty, muted)]
      : [
          for (final c in comments)
            if (!_hidden.contains(c.id))
            ListTile(
              title: Text('${c.author} · ${_when(c.createdAt)}', style: muted),
              subtitle: Text(c.body),
              trailing: c.mine
                  ? IconButton(
                      tooltip: t('מחיקת התגובה'),
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _remove(c))
                  : null,
            ),
        ];

  Widget _composer(String key, String hint) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: TextField(
              controller: _draft(key),
              minLines: 1,
              maxLines: 5,
              maxLength: 1000,
              decoration: InputDecoration(hintText: hint, counterText: ''),
            ),
          ),
          ListenableBuilder(
            listenable: _draft(key),
            builder: (context, _) => IconButton(
              tooltip: t('שליחה'),
              icon: const Icon(Icons.send),
              onPressed: _draft(key).text.trim().isEmpty ? null : () => _post(key),
            ),
          ),
        ]),
      );
}

/// "15/10 21:04", like the Ionic app's d/M HH:mm.
String _when(DateTime? t) => t == null
    ? ''
    : '${t.day}/${t.month} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
