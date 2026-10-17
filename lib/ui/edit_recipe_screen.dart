import 'package:flutter/material.dart';

import '../core/errors.dart';
import '../recipes/api.dart';
import 'pick.dart';
import 'recipe_widgets.dart';
import '../core/i18n.dart';

/// Name, photo, tags, categories, source link and ingredient prices; and
/// deleting the recipe. Pops true when something was saved, 'deleted' when gone.
class EditRecipeScreen extends StatefulWidget {
  const EditRecipeScreen(this.recipe, {super.key});
  final Recipe recipe;

  @override
  State<EditRecipeScreen> createState() => _EditRecipeScreenState();
}

class _EditRecipeScreenState extends State<EditRecipeScreen> {
  late final Recipe r = widget.recipe;
  late final _name = TextEditingController(text: r.name);
  late final _tags = TextEditingController(text: r.tags.join(', '));
  late final _categories = TextEditingController(text: r.categories.join(', '));
  late final _source = TextEditingController(text: r.sourceUrl);
  late final _prices = [
    for (final p in r.prices) TextEditingController(text: p.price == null ? '' : pretty1(p.price!)),
  ];
  late String? _image = r.image;
  bool _photoChanged = false;
  bool _busy = false;
  bool _uploading = false;

  @override
  void dispose() {
    for (final c in [_name, _tags, _categories, _source, ..._prices]) {
      c.dispose();
    }
    super.dispose();
  }

  ScaffoldMessengerState get _messenger => ScaffoldMessenger.of(context);

  static List<String> _list(String s) =>
      [for (final x in s.split(',')) if (x.trim().isNotEmpty) x.trim()];

  /// The photo is saved at once: it doesn't wait for "save".
  Future<void> _photo() async {
    final p = await pickPhoto(context);
    if (p == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final image = await Api.setPhoto(r.id, p);
      if (mounted) setState(() { _image = image; _photoChanged = true; });
    } catch (e) {
      showError(_messenger, e, t('התמונה לא הועלתה'));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final patch = <String, Object>{
      if (name.isNotEmpty && name != r.name) 'name': name,
      if (_list(_tags.text).join() != r.tags.join()) 'tags': _list(_tags.text),
      if (_list(_categories.text).join() != r.categories.join()) 'categories': _list(_categories.text),
      if (_source.text.trim() != r.sourceUrl) 'sourceUrl': _source.text.trim(),
    };
    final pricesChanged = [
      for (final (i, p) in r.prices.indexed)
        _prices[i].text.trim() != (p.price == null ? '' : pretty1(p.price!)),
    ].any((x) => x);
    setState(() => _busy = true);
    try {
      if (patch.isNotEmpty) await Api.updateRecipe(r.id, patch);
      if (pricesChanged) {
        await Api.setPrices(r.id, [
          for (final (i, p) in r.prices.indexed) (line: p.line, price: _prices[i].text.trim()),
        ]);
      }
      if (mounted) Navigator.pop(context, patch.isNotEmpty || pricesChanged || _photoChanged);
    } catch (e) {
      showError(_messenger, e, t('השינויים לא נשמרו'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t('למחוק את „{0}”?', [r.title])),
        content: Text(t('המתכון יימחק מהספר לכולם בבית. אי אפשר לבטל.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t('ביטול'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(c).colorScheme.error),
            onPressed: () => Navigator.pop(c, true),
            child: Text(t('מחיקה')),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await Api.deleteRecipe(r.id);
      if (mounted) Navigator.pop(context, 'deleted');
    } catch (e) {
      showError(_messenger, e, t('המתכון לא נמחק'));
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return PopScope(
      // A new photo is already saved: the recipe screen should show it.
      canPop: !_photoChanged,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, true);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(t('עריכת מתכון')),
          actions: [
            TextButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(t('שמירה')),
            ),
          ],
        ),
        body: ListView(children: [
          if (_image != null) NetImage(_image, height: 220),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(_image == null ? t('הוספת תמונה') : t('החלפת התמונה')),
            trailing: _uploading
                ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : null,
            onTap: _uploading || _busy ? null : _photo,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(children: [
              TextField(controller: _name, decoration: InputDecoration(labelText: t('שם (בשפת המקור)'))),
              TextField(controller: _tags, decoration: InputDecoration(labelText: t('תגיות, מופרדות בפסיק'))),
              TextField(
                  controller: _categories,
                  decoration: InputDecoration(labelText: t('קטגוריות, מופרדות בפסיק'))),
              TextField(
                controller: _source,
                keyboardType: TextInputType.url,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(labelText: t('קישור למקור')),
              ),
            ]),
          ),
          if (r.prices.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: Text(t('מחירים'), style: Theme.of(context).textTheme.titleMedium),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(t('מחיר הכמות שבמתכון, בשקלים. ריק אם אין מחיר.'), style: muted),
            ),
            for (final (i, p) in r.prices.indexed)
              ListTile(
                title: Text(p.line),
                subtitle: p.was == null ? null : Text(t('תומחר כשהשורה הייתה: {0}', [p.was])),
                trailing: SizedBox(
                  width: 96,
                  child: Semantics(
                    label: t('מחיר: {0}', [p.line]),
                    child: TextField(
                      controller: _prices[i],
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textDirection: TextDirection.ltr,
                      decoration: const InputDecoration(hintText: '₪'),
                    ),
                  ),
                ),
              ),
          ],
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              icon: const Icon(Icons.delete_outline),
              label: Text(t('מחיקת המתכון')),
              onPressed: _busy ? null : _delete,
            ),
          ),
        ]),
      ),
    );
  }
}
