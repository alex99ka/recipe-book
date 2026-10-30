import 'package:flutter/material.dart';

import '../core/errors.dart';
import '../core/tour.dart';
import '../recipes/api.dart';
import '../recipes/links.dart';
import '../recipes/offline.dart';
import '../recipes/scaling.dart';
import 'cookbook_screen.dart';
import 'edit_recipe_screen.dart';
import 'export_dialog.dart';
import 'panel_screen.dart';
import 'recipe_comments.dart';
import 'recipe_widgets.dart';
import 'send_dialog.dart';
import 'skeleton.dart';
import '../core/i18n.dart';

/// A recipe in Hebrew: photo, rating, amounts ×1/×2/×3, cost, steps, and what
/// you do with it (a cookbook, a friend, the shopping list), then comments.
class RecipeScreen extends StatefulWidget {
  const RecipeScreen(this.id, {super.key, this.title = ''});
  final String id;
  final String title;

  @override
  State<RecipeScreen> createState() => _RecipeScreenState();
}

/// Tapping a star sets it; tapping the same star again makes it a half; a
/// half on the first star clears.
double? nextRating(double? current, int star) {
  final c = current ?? 0;
  if (c == star) return star - 0.5;
  if (c == star - 0.5 && star == 1) return null;
  return star.toDouble();
}

class _RecipeScreenState extends State<RecipeScreen> {
  Recipe? _r;
  Object? _error;
  int _factor = 1;
  bool _shopping = false;
  bool _showing = false;
  final _comments = GlobalKey<RecipeCommentsState>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Api.recipe(widget.id);
      if (mounted) setState(() { _r = r; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
    await _comments.currentState?.load();
  }

  ScaffoldMessengerState get _messenger => ScaffoldMessenger.of(context);

  List<String> get _lines => [for (final p in _r!.prices) scaleIngredient(p.line, _factor)];

  Future<void> _rate(int star) async {
    final r = _r!;
    final next = nextRating(r.rating, star);
    setState(() => _r = Recipe({...r.j, 'rating': next}));
    try {
      await Api.setRating(r.id, next);
    } catch (e) {
      if (!mounted) return;
      setState(() => _r = r);
      showError(_messenger, e, t('הדירוג לא נשמר'));
    }
  }

  /// Tick the book's own cookbooks this recipe belongs in, or start a new one.
  Future<void> _fileInBooks() async {
    final r = _r!;
    final List<Shelf> all;
    try {
      all = await Api.collections();
    } catch (e) {
      showError(_messenger, e, t('הספרים לא נטענו'));
      return;
    }
    if (!mounted) return;
    final chosen = {...r.collections};
    final answer = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text(t('הוספה לספר')),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (all.isEmpty) Text(t('עוד אין ספרים משלכם. התחילו ספר חדש:')),
              for (final c in all)
                CheckboxListTile(
                  title: Text(Api.label(c.title)),
                  value: chosen.contains(c.id),
                  onChanged: (v) => set(() => v! ? chosen.add(c.id!) : chosen.remove(c.id)),
                ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, 'new'), child: Text(t('ספר חדש'))),
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('ביטול'))),
            if (all.isNotEmpty)
              FilledButton(onPressed: () => Navigator.pop(ctx, 'save'), child: Text(t('שמירה'))),
          ],
        ),
      ),
    );
    if (answer == null || !mounted) return;
    try {
      // Ticks count for "new cookbook" too, so nothing chosen is lost on the way.
      await Future.wait([
        for (final c in all)
          if (chosen.contains(c.id) != r.collections.contains(c.id))
            Api.fileRecipe(c.id!, r.id, chosen.contains(c.id)),
      ]);
      if (answer == 'new' && mounted) {
        final title = await askTitle(context, t('ספר מתכונים חדש'));
        if (title != null) {
          final created = await Api.createCollection(title);
          await Api.fileRecipe(created.id!, r.id, true);
          chosen.add(created.id!);
          _messenger.showSnackBar(SnackBar(content: Text(t('נוסף ל„{0}”', [created.title]))));
        }
      }
      if (mounted) setState(() => _r = Recipe({...r.j, 'collections': chosen.toList()}));
    } catch (e) {
      showError(_messenger, e, t('השינוי לא נשמר'));
      await _load();
    }
  }

  Future<void> _send() async {
    final r = _r!;
    final sent = await sendToFriend(context,
        title: r.title, send: (to, note) => Api.send(r.id, to, note));
    if (sent) await _comments.currentState?.load(); // the note opened a conversation
  }

  Future<void> _showOnScreen() async {
    setState(() => _showing = true);
    try {
      await Api.showOnScreen(_r!.id, _factor);
      _setPlanned(false); // the server takes it off this week's list
      _messenger.showSnackBar(SnackBar(content: Text(t('המתכון יופיע בלחיצה הבאה על הכפתור במסך'))));
    } on ServerException catch (e) {
      if (e.status != 409) return showError(_messenger, e, t('המתכון לא נשלח למסך'));
      _messenger.showSnackBar(SnackBar(
        content: Text(t('אין מסך שמחובר לספר הזה')),
        action: SnackBarAction(
            label: t('חיבור מסך'),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute<void>(builder: (_) => const PanelScreen()))),
      ));
    } catch (e) {
      showError(_messenger, e, t('המתכון לא נשלח למסך'));
    } finally {
      if (mounted) setState(() => _showing = false);
    }
  }

  Future<void> _edit() async {
    final result = await Navigator.push<Object?>(
        context, MaterialPageRoute(builder: (_) => EditRecipeScreen(_r!)));
    if (!mounted) return;
    if (result == 'deleted') {
      Navigator.pop(context, 'deleted');
    } else if (result == true) {
      await _load();
    }
  }

  Future<void> _shoppingList() async {
    setState(() => _shopping = true);
    try {
      final url = await Api.shoppingList(_r!.id, _lines);
      _setPlanned(true); // shopping for it puts it on this week's list
      // The to-do app takes this link over when it is installed; otherwise the browser.
      await openLink(url);
    } catch (e) {
      showError(_messenger, e, t('רשימת הקניות לא נוצרה'));
    } finally {
      if (mounted) setState(() => _shopping = false);
    }
  }

  void _setPlanned(bool on) {
    if (mounted && _r != null) {
      setState(() => _r = Recipe({..._r!.j, 'plannedAt': on ? DateTime.now().toUtc().toIso8601String() : null}));
    }
  }

  Future<void> _plan(bool on) async {
    try {
      await Api.plan(_r!.id, on);
      _setPlanned(on);
      if (!on) _messenger.showSnackBar(SnackBar(content: Text(t('בתיאבון! הוסר מרשימת השבוע.'))));
    } catch (e) {
      showError(_messenger, e, t('השינוי לא נשמר'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _r;
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    // Wide (a tablet, or a phone on its side): the steps beside the ingredients.
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final head = r == null
        ? const <Widget>[]
        : <Widget>[
          Text(r.title, style: text.headlineSmall),
          TourTarget('recipe.stars', child: _Stars(r.rating, onTap: _rate)),
          if (linkKind(r.sourceUrl) case final kind?)
            FilledButton.tonalIcon(
              icon: Icon(kind.icon),
              label: Text(kind.label),
              onPressed: () => openLink(r.sourceUrl),
            ),
          if (r.plannedAt == null)
            OutlinedButton.icon(
              icon: const Icon(Icons.event_available_outlined),
              label: Text(t('רוצה להכין השבוע')),
              onPressed: () => _plan(true),
            )
          else
            FilledButton.icon(
              icon: const Icon(Icons.check),
              label: Text(t('הכנתי (ברשימת השבוע)')),
              onPressed: () => _plan(false),
            ),
          if (r.servings.isNotEmpty || r.totalTime.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                  [if (r.servings.isNotEmpty) t('{0} מנות', [r.servings]), if (r.totalTime.isNotEmpty) r.totalTime]
                      .join(' · '),
                  style: TextStyle(color: muted)),
            ),
          if (r.translating || !r.translated)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(t('התרגום בדרך. משכו למטה לרענון בעוד דקה.'),
                  style: TextStyle(color: muted)),
            ),
          ];
    final ingredients = r == null
        ? const <Widget>[]
        : <Widget>[
          const SizedBox(height: 16),
          Text(t('מצרכים'), style: text.titleMedium),
          const SizedBox(height: 8),
          TourTarget(
            'recipe.scale',
            child: SegmentedButton<int>(
              segments: [
                for (final f in [1, 2, 3]) ButtonSegment(value: f, label: Text('×$f')),
              ],
              selected: {_factor},
              onSelectionChanged: (s) => setState(() => _factor = s.first),
            ),
          ),
          if (_factor != 1)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(t('הכמויות הוכפלו. זמני הבישול לא משתנים.'),
                  style: TextStyle(color: muted)),
            ),
          const SizedBox(height: 8),
          for (final (i, p) in r.prices.indexed)
            _Bullet(_lines[i],
                note: r.cost == null
                    ? null
                    : p.was != null
                        ? t('מחיר לבדיקה')
                        : p.price == null
                            ? t('בלי מחיר')
                            : null),
          if (r.cost case final c?) _CostBox(c, factor: _factor),
          const SizedBox(height: 16),
          TourTarget(
            'recipe.book',
            child: OutlinedButton.icon(
              icon: const Icon(Icons.bookmark_border),
              label: Text(t('הוספה לספר{0}', [switch (r.collections.length) {
                0 => '',
                1 => t(' · בספר אחד'),
                final n => t(' · ב־{0} ספרים', [n]),
              }])),
              onPressed: _fileInBooks,
            ),
          ),
          TourTarget(
            'recipe.send',
            child: OutlinedButton.icon(
              icon: const Icon(Icons.send_outlined),
              label: Text(t('שליחה לחבר')),
              onPressed: _send,
            ),
          ),
          TourTarget(
            'recipe.shopping',
            child: OutlinedButton.icon(
              icon: _shopping
                  ? const SizedBox.square(
                      dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.shopping_cart_outlined),
              label: Text(t('הוספה לרשימת הקניות')),
              onPressed: _shopping ? null : _shoppingList,
            ),
          ),
          OutlinedButton.icon(
            icon: _showing
                ? const SizedBox.square(
                    dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.tv_outlined),
            label: Text(t('הצגה במסך')),
            onPressed: _showing ? null : _showOnScreen,
          ),
          ];
    final rest = r == null
        ? const <Widget>[]
        : <Widget>[
          if (r.steps.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(t('אופן ההכנה'), style: text.titleMedium),
            const SizedBox(height: 8),
            for (final (i, s) in r.steps.indexed) _Bullet(s, number: i + 1),
          ],
          if (r.allTags.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(t('תגיות'), style: text.titleMedium),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final tag in r.allTags)
                ActionChip(
                  label: Text(Api.label(tag)),
                  tooltip: t('כל המתכונים עם {0}', [Api.label(tag)]),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                          builder: (_) =>
                              CookbookScreen(Shelf({'title': tag}), tag: tag))),
                ),
            ]),
          ],
          ];
    return Scaffold(
      appBar: AppBar(title: Text(r?.title ?? widget.title), actions: [
        if (r != null)
          IconButton(
              tooltip: t('ייצוא (PDF, טקסט, Markdown)'),
              icon: const Icon(Icons.ios_share),
              onPressed: () => exportRecipeFile(context, r, _lines)),
        if (r != null)
          TourTarget(
            'recipe.edit',
            child: IconButton(tooltip: t('עריכה'), icon: const Icon(Icons.edit_outlined), onPressed: _edit),
          ),
      ]),
      body: _error != null && r == null
          ? Center(child: LoadError(_error!, retry: _load))
          : r == null
              ? const SkeletonList(rows: 8, leading: false)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(children: [
                    const OfflineBanner(),
                    if (wide)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(
                            child: _column([
                              if (r.image != null)
                                ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: NetImage(r.image, height: 220)),
                              ...head,
                              ...ingredients,
                            ]),
                          ),
                          const SizedBox(width: 24),
                          Expanded(child: _column(rest)),
                        ]),
                      )
                    else ...[
                      if (r.image != null) NetImage(r.image, height: 260),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: _column([...head, ...ingredients, ...rest]),
                      ),
                    ],
                    RecipeComments(r.id, key: _comments),
                    const SizedBox(height: 32),
                  ]),
                ),
    );
  }
}

Widget _column(List<Widget> children) =>
    Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);

class _Stars extends StatelessWidget {
  const _Stars(this.rating, {required this.onTap});
  final double? rating;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final r = rating ?? 0;
    return Row(children: [
      for (var i = 1; i <= 5; i++)
        IconButton(
          tooltip: t('{0} כוכבים', [i]),
          visualDensity: VisualDensity.compact,
          color: Theme.of(context).colorScheme.tertiary,
          icon: Icon(r >= i ? Icons.star : r >= i - 0.5 ? Icons.star_half : Icons.star_border),
          onPressed: () => onTap(i),
        ),
    ]);
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text, {this.number, this.note});
  final String text;
  final int? number;
  final String? note;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 24, child: Text(number == null ? '•' : '$number.')),
          Expanded(
            child: Text.rich(TextSpan(text: text, children: [
              if (note != null)
                TextSpan(
                    text: '  $note',
                    style: TextStyle(
                        fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ]), style: const TextStyle(height: 1.5)),
          ),
        ]),
      );
}

class _CostBox extends StatelessWidget {
  const _CostBox(this.c, {required this.factor});
  final Cost c;
  final int factor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = TextStyle(color: scheme.onSurfaceVariant);
    const big = TextStyle(fontSize: 18, fontWeight: FontWeight.w600);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t('עלות משוערת'), style: muted),
            Text('${(c.total * factor).toStringAsFixed(2)} ₪', style: big),
          ]),
          if (c.perServing != null && c.servings != null) ...[
            const SizedBox(width: 24),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t('למנה ({0} מנות)', [pretty(c.servings! * factor)]), style: muted),
              Text('${c.perServing!.toStringAsFixed(2)} ₪', style: big),
            ]),
          ],
        ]),
      ),
      if (c.missing > 0 || c.stale > 0)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text([
            if (c.missing > 0) t('לא כולל {0} מצרכים בלי מחיר.', [c.missing]),
            if (c.stale > 0) t('{0} מחירים לבדיקה: השורה השתנתה מאז שתומחרה.', [c.stale]),
          ].join(' '), style: muted),
        ),
    ]);
  }
}
