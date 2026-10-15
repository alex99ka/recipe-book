import 'package:flutter/material.dart';

import '../recipes/api.dart';
import 'recipe_widgets.dart';
import 'skeleton.dart';

/// One cookbook's recipes: a scanned one in page order, or one of the book's
/// own in the order added. (Renaming, deleting and sending come in 5.1.0.)
class CookbookScreen extends StatefulWidget {
  const CookbookScreen(this.shelf, {super.key});
  final Shelf shelf;

  @override
  State<CookbookScreen> createState() => _CookbookScreenState();
}

class _CookbookScreenState extends State<CookbookScreen> {
  List<Summary>? _recipes;
  Object? _error;

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

  @override
  Widget build(BuildContext context) {
    final recipes = _recipes;
    return Scaffold(
      appBar: AppBar(title: Text(widget.shelf.title)),
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
                    for (final r in recipes) RecipeTile(r),
                  ]),
                ),
    );
  }
}
