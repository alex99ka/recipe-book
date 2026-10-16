import 'dart:async';

import 'package:flutter/material.dart';

import '../config.dart';
import '../core/app_info.dart';
import '../core/errors.dart';
import '../core/remote_config.dart';
import '../core/tour.dart';
import '../core/update.dart';
import '../core/web_update.dart';
import '../recipes/api.dart';
import 'add_recipe_screen.dart';
import 'cookbook_screen.dart';
import 'inbox_screen.dart';
import 'recipe_widgets.dart';
import 'settings_page.dart';
import 'skeleton.dart';
import 'update_banner.dart';

/// Search, the book's own cookbooks, the scanned cookbooks, what was added
/// lately, and the way to add a recipe or open what friends sent.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final AppLifecycleListener _lifecycle;
  final _search = TextEditingController();
  Timer? _debounce;
  bool _searching = false;
  String _q = '';

  /// The tag picked under the search box; null for none.
  String? _tag;

  /// The book's tags, loaded when search first opens.
  List<String>? _tags;

  /// Not searching: the shelves and the latest recipes.
  bool get _browsing => _q.isEmpty && _tag == null;
  int _loads = 0;

  List<Summary>? _recipes;
  List<Shelf> _collections = [];
  List<Shelf> _cookbooks = [];
  Object? _error;

  @override
  void initState() {
    super.initState();
    // Updates and the minimum version: at launch, and on coming back.
    _checkUpdates();
    _lifecycle = AppLifecycleListener(onResume: () {
      _checkUpdates();
      RemoteConfig.instance.listen();
      RemoteConfig.instance.checkAccess(null).ignore(); // the inbox badge
    });
    _load().then((_) => _afterFirstLoad());
  }

  void _checkUpdates() {
    AppUpdater.instance?.checkIfDue();
    WebUpdate.instance.check();
  }

  Future<void> _afterFirstLoad() async {
    if (!mounted || _error != null) return;
    final messenger = ScaffoldMessenger.of(context);
    // The whole tour on a new device; after an update, what it brought.
    final steps = await tourForThisLaunch(AppInfo.version);
    if (steps != null && steps.isNotEmpty) {
      runningTour.value = steps;
    } else if (steps != null && AppConfig.releaseNotes.isNotEmpty) {
      messenger.showSnackBar(SnackBar(
        duration: const Duration(seconds: 8),
        content: Text('מה חדש בגרסה ${AppInfo.version}: ${AppConfig.releaseNotes}'),
      ));
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final seq = ++_loads;
    final q = _q;
    final browsing = _browsing;
    try {
      final results = await Future.wait([
        Api.recipes(q: q, tag: _tag),
        if (browsing) Api.collections(),
        if (browsing) Api.cookbooks(),
      ]);
      if (seq != _loads || !mounted) return; // a newer search started meanwhile
      setState(() {
        _error = null;
        _recipes = results[0] as List<Summary>;
        if (browsing) {
          _collections = results[1] as List<Shelf>;
          _cookbooks = results[2] as List<Shelf>;
        }
      });
    } catch (e) {
      if (seq == _loads && mounted) setState(() => _error = e);
    }
  }

  void _onSearch(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _q = text.trim();
      _load();
    });
  }

  Future<void> _newCollection() async {
    final title = await askTitle(context, 'ספר מתכונים חדש');
    if (title == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final created = await Api.createCollection(title);
      setState(() => _collections = [..._collections, created]);
    } catch (e) {
      showError(messenger, e, 'הספר לא נוצר');
    }
  }

  void _open(Shelf s) => Navigator.push(
          context, MaterialPageRoute<void>(builder: (_) => CookbookScreen(s)))
      .then((_) => _load()); // its recipes may have moved

  @override
  Widget build(BuildContext context) {
    final recipes = _recipes;
    final shown = recipes == null ? null : (_browsing ? recipes.take(30).toList() : recipes);
    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _search,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'חיפוש מתכון', border: InputBorder.none),
                onChanged: _onSearch,
              )
            : const Text(AppConfig.name),
        actions: [
          TourTarget(
            'home.search',
            child: IconButton(
              tooltip: _searching ? 'סגירת החיפוש' : 'חיפוש',
              icon: Icon(_searching ? Icons.close : Icons.search),
              onPressed: () {
                setState(() => _searching = !_searching);
                if (_searching && _tags == null) {
                  Api.tags().then((t) {
                    if (mounted) setState(() => _tags = t);
                  }, onError: (_) {}); // searching by text still works
                }
                if (!_searching && !_browsing) {
                  _search.clear();
                  _q = '';
                  _tag = null;
                  _load();
                }
              },
            ),
          ),
          TourTarget(
            'home.inbox',
            child: ListenableBuilder(
              listenable: RemoteConfig.instance,
              builder: (context, _) => IconButton(
                tooltip: Api.inboxCount == 0 ? 'התקבל מחברים' : 'התקבל מחברים: ${Api.inboxCount}',
                icon: Badge(
                  isLabelVisible: Api.inboxCount > 0,
                  label: Text('${Api.inboxCount}'),
                  child: const Icon(Icons.inbox_outlined),
                ),
                onPressed: () => Navigator.push(
                        context, MaterialPageRoute<void>(builder: (_) => const InboxScreen()))
                    .then((_) => _load()), // kept copies are in the book now
              ),
            ),
          ),
          TourTarget(
            'settings',
            child: IconButton(
              tooltip: 'הגדרות',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => Navigator.push(context,
                      MaterialPageRoute<void>(builder: (_) => const SettingsPage()))
                  .then((_) => _load()), // the book may have changed
            ),
          ),
        ],
      ),
      floatingActionButton: TourTarget(
        'home.add',
        child: FloatingActionButton.extended(
          onPressed: () => Navigator.push(
                  context, MaterialPageRoute<void>(builder: (_) => const AddRecipeScreen()))
              .then((_) => _load()),
          icon: const Icon(Icons.add),
          label: const Text('מתכון חדש'),
        ),
      ),
      body: Column(children: [
        const UpdateBanner(),
        Expanded(
          child: _error != null && recipes == null
              ? Center(child: LoadError(_error!, retry: _load))
              : shown == null
                  ? const SkeletonList()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(children: [
                        if (_error != null) LoadError(_error!, retry: _load),
                        if (_searching && (_tags?.isNotEmpty ?? false))
                          TourTarget(
                            'home.tags',
                            child: SizedBox(
                              height: 56,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                children: [
                                  for (final t in _tags!)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      child: FilterChip(
                                        label: Text(t),
                                        selected: _tag == t,
                                        onSelected: (on) {
                                          setState(() => _tag = on ? t : null);
                                          _load();
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        if (_browsing) ...[
                          const _Header('הספרים שלי'),
                          TourTarget(
                            'home.mine',
                            child: _ShelfRow([
                              for (final c in _collections)
                                _ShelfCard(c, icon: Icons.menu_book_outlined, onTap: () => _open(c)),
                              _ShelfCard(null, icon: Icons.add, label: 'ספר חדש', onTap: _newCollection),
                            ]),
                          ),
                          if (_cookbooks.isNotEmpty) ...[
                            const _Header('ספרי בישול'),
                            TourTarget(
                              'home.cookbooks',
                              child: _ShelfRow([
                                for (final c in _cookbooks)
                                  _ShelfCard(c, icon: Icons.auto_stories_outlined, onTap: () => _open(c)),
                              ]),
                            ),
                          ],
                        ],
                        _Header(_browsing ? 'נוספו לאחרונה' : _tag != null && _q.isEmpty ? 'תגית: $_tag' : 'תוצאות'),
                        if (shown.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(48),
                            child: Text(_browsing ? 'הספר עוד ריק.' : 'לא נמצא מתכון.',
                                textAlign: TextAlign.center),
                          ),
                        for (final (i, r) in shown.indexed)
                          i == 0
                              ? TourTarget('home.first', child: RecipeTile(r, onBack: _load))
                              : RecipeTile(r, onBack: _load),
                        const SizedBox(height: 88), // clear of the add button
                      ]),
                    ),
        ),
      ]),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}

class _ShelfRow extends StatelessWidget {
  const _ShelfRow(this.children);
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 196,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: children,
        ),
      );
}

/// A cookbook cover with its title and count; [shelf] null is the "ספר חדש" card.
class _ShelfCard extends StatelessWidget {
  const _ShelfCard(this.shelf, {required this.icon, required this.onTap, this.label});
  final Shelf? shelf;
  final IconData icon;
  final VoidCallback onTap;
  final String? label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 104,
            child: Column(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: NetImage(shelf?.cover, width: 104, height: 140, icon: icon),
              ),
              const SizedBox(height: 4),
              Text(label ?? shelf!.title,
                  maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
              if (shelf != null)
                Text('${shelf!.count}', style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        ),
      );
}
