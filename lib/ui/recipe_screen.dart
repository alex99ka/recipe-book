import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/errors.dart';
import '../core/tour.dart';
import '../recipes/api.dart';
import '../recipes/offline.dart';
import '../recipes/scaling.dart';
import 'cookbook_screen.dart';
import 'edit_recipe_screen.dart';
import 'recipe_comments.dart';
import 'recipe_widgets.dart';
import 'send_dialog.dart';
import 'skeleton.dart';

/// A recipe in Hebrew: photo, rating, amounts ×1/×2/×3, cost, steps, and what
/// you do with it (a cookbook, a friend, the shopping list), then comments.
class RecipeScreen extends StatefulWidget {
  const RecipeScreen(this.id, {super.key, this.title = ''});
  final String id;
  final String title;

  @override
  State<RecipeScreen> createState() => _RecipeScreenState();
}

/// Same rule as the server's video.py: any tiktok.com host, short links included.
bool isTikTok(String url) =>
    RegExp(r'(^|\.)tiktok\.com$', caseSensitive: false).hasMatch(Uri.tryParse(url)?.host ?? '');

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
      showError(_messenger, e, 'הדירוג לא נשמר');
    }
  }

  /// Tick the book's own cookbooks this recipe belongs in, or start a new one.
  Future<void> _fileInBooks() async {
    final r = _r!;
    final List<Shelf> all;
    try {
      all = await Api.collections();
    } catch (e) {
      showError(_messenger, e, 'הספרים לא נטענו');
      return;
    }
    if (!mounted) return;
    final chosen = {...r.collections};
    final answer = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('הוספה לספר'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (all.isEmpty) const Text('עוד אין ספרים משלכם. התחילו ספר חדש:'),
              for (final c in all)
                CheckboxListTile(
                  title: Text(c.title),
                  value: chosen.contains(c.id),
                  onChanged: (v) => set(() => v! ? chosen.add(c.id!) : chosen.remove(c.id)),
                ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, 'new'), child: const Text('ספר חדש')),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ביטול')),
            if (all.isNotEmpty)
              FilledButton(onPressed: () => Navigator.pop(ctx, 'save'), child: const Text('שמירה')),
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
        final title = await askTitle(context, 'ספר מתכונים חדש');
        if (title != null) {
          final created = await Api.createCollection(title);
          await Api.fileRecipe(created.id!, r.id, true);
          chosen.add(created.id!);
          _messenger.showSnackBar(SnackBar(content: Text('נוסף ל„${created.title}”')));
        }
      }
      if (mounted) setState(() => _r = Recipe({...r.j, 'collections': chosen.toList()}));
    } catch (e) {
      showError(_messenger, e, 'השינוי לא נשמר');
      await _load();
    }
  }

  Future<void> _send() async {
    final r = _r!;
    final sent = await sendToFriend(context,
        title: r.title, send: (to, note) => Api.send(r.id, to, note));
    if (sent) await _comments.currentState?.load(); // the note opened a conversation
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
      // The to-do app takes this link over when it is installed; otherwise the browser.
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      showError(_messenger, e, 'רשימת הקניות לא נוצרה');
    } finally {
      if (mounted) setState(() => _shopping = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _r;
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(title: Text(r?.title ?? widget.title), actions: [
        if (r != null)
          TourTarget(
            'recipe.edit',
            child: IconButton(tooltip: 'עריכה', icon: const Icon(Icons.edit_outlined), onPressed: _edit),
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
                    if (r.image != null) NetImage(r.image, height: 260),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Text(r.title, style: text.headlineSmall),
                        TourTarget('recipe.stars', child: _Stars(r.rating, onTap: _rate)),
                        if (isTikTok(r.sourceUrl))
                          FilledButton.tonalIcon(
                            icon: const Icon(Icons.play_circle_outline),
                            label: const Text('לסרטון בטיקטוק'),
                            onPressed: () => launchUrl(Uri.parse(r.sourceUrl),
                                mode: LaunchMode.externalApplication),
                          ),
                        if (r.servings.isNotEmpty || r.totalTime.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                                [if (r.servings.isNotEmpty) '${r.servings} מנות', if (r.totalTime.isNotEmpty) r.totalTime]
                                    .join(' · '),
                                style: TextStyle(color: muted)),
                          ),
                        if (r.translating || !r.translated)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text('התרגום לעברית בדרך. משכו למטה לרענון בעוד דקה.',
                                style: TextStyle(color: muted)),
                          ),
                        const SizedBox(height: 16),
                        Text('מצרכים', style: text.titleMedium),
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
                            child: Text('הכמויות הוכפלו. זמני הבישול לא משתנים.',
                                style: TextStyle(color: muted)),
                          ),
                        const SizedBox(height: 8),
                        for (final (i, p) in r.prices.indexed)
                          _Bullet(_lines[i],
                              note: r.cost == null
                                  ? null
                                  : p.was != null
                                      ? 'מחיר לבדיקה'
                                      : p.price == null
                                          ? 'בלי מחיר'
                                          : null),
                        if (r.cost case final c?) _CostBox(c, factor: _factor),
                        const SizedBox(height: 16),
                        TourTarget(
                          'recipe.book',
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.bookmark_border),
                            label: Text('הוספה לספר${switch (r.collections.length) {
                              0 => '',
                              1 => ' · בספר אחד',
                              final n => ' · ב־$n ספרים',
                            }}'),
                            onPressed: _fileInBooks,
                          ),
                        ),
                        TourTarget(
                          'recipe.send',
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.send_outlined),
                            label: const Text('שליחה לחבר'),
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
                            label: const Text('הוספה לרשימת הקניות'),
                            onPressed: _shopping ? null : _shoppingList,
                          ),
                        ),
                        if (r.steps.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text('אופן ההכנה', style: text.titleMedium),
                          const SizedBox(height: 8),
                          for (final (i, s) in r.steps.indexed) _Bullet(s, number: i + 1),
                        ],
                        if (r.allTags.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text('תגיות', style: text.titleMedium),
                          const SizedBox(height: 8),
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            for (final t in r.allTags)
                              ActionChip(
                                label: Text(t),
                                tooltip: 'כל המתכונים עם $t',
                                onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                        builder: (_) =>
                                            CookbookScreen(Shelf({'title': t}), tag: t))),
                              ),
                          ]),
                        ],
                        if (r.sourceUrl.isNotEmpty && !isTikTok(r.sourceUrl))
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: TextButton.icon(
                              icon: const Icon(Icons.link),
                              label: const Text('למקור'),
                              onPressed: () => launchUrl(Uri.parse(r.sourceUrl),
                                  mode: LaunchMode.externalApplication),
                            ),
                          ),
                      ]),
                    ),
                    RecipeComments(r.id, key: _comments),
                    const SizedBox(height: 32),
                  ]),
                ),
    );
  }
}

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
          tooltip: '$i כוכבים',
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
            Text('עלות משוערת', style: muted),
            Text('${(c.total * factor).toStringAsFixed(2)} ₪', style: big),
          ]),
          if (c.perServing != null && c.servings != null) ...[
            const SizedBox(width: 24),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('למנה (${pretty(c.servings! * factor)} מנות)', style: muted),
              Text('${c.perServing!.toStringAsFixed(2)} ₪', style: big),
            ]),
          ],
        ]),
      ),
      if (c.missing > 0 || c.stale > 0)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text([
            if (c.missing > 0) 'לא כולל ${c.missing} מצרכים בלי מחיר.',
            if (c.stale > 0) '${c.stale} מחירים לבדיקה: השורה השתנתה מאז שתומחרה.',
          ].join(' '), style: muted),
        ),
    ]);
  }
}
