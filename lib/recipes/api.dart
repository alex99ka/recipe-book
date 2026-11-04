import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../core/remote_config.dart';
import '../core/server.dart';
import 'models.dart';
import 'offline.dart';

export 'models.dart';

/// HTTP operations for the recipe server's /api/v1 endpoints.
String _q(String s) => Uri.encodeComponent(s);

abstract final class Api {
  // ---- the chosen book (a member of several households switches in Settings) ----

  static const _bookKey = 'recipes.book';

  /// Before the first call: the book chosen on this device, if any.
  static Future<void> loadBook() async {
    final key = (await SharedPreferences.getInstance()).getString(_bookKey);
    if (key != null && key.isNotEmpty) serverHeaders['X-Book'] = key;
  }

  static Future<void> setBook(String key) async {
    await (await SharedPreferences.getInstance()).setString(_bookKey, key);
    serverHeaders['X-Book'] = key;
    await RemoteConfig.instance.checkAccess(null); // /me again: the open book
  }

  static List<Book> get books => [
        for (final b in RemoteConfig.instance.me?['books'] as List? ?? const [])
          Book(b as Map<String, dynamic>)
      ];
  static String? get book => RemoteConfig.instance.me?['book'] as String?;

  /// Waiting inbox items, from the last /me.
  static int get inboxCount => RemoteConfig.instance.me?['inbox'] as int? ?? 0;

  /// Images and covers come as signed paths under the server (`/api/v1/...`).
  static String? imageUrl(String? path) =>
      path == null ? null : Uri.parse(AppConfig.serverUrl).resolve(path).toString();

  // ---- the app's language ----

  /// Tags, categories and book names in the app's language, by the original.
  /// The originals stay what is filtered by and edited; only the screen shows these.
  static Map<String, String> labels = {};

  static String label(String original) => labels[original] ?? original;

  static Future<void> loadLabels() async {
    try {
      labels = {
        for (final e in (await cached('labels', () => server('GET', '/labels')) as Map).entries)
          '${e.key}': '${e.value}'
      };
    } catch (_) {} // the originals will do
  }

  /// This version's release notes in the app's language; the Hebrew when that fails.
  static Future<String> releaseNotes() async {
    final notes = AppConfig.releaseNotes;
    if (notes.isEmpty || serverHeaders['X-Lang'] == null) return notes;
    try {
      final j = await server('POST', '/translate', {'texts': [notes]}) as Map;
      return '${j[notes] ?? notes}';
    } catch (_) {
      return notes;
    }
  }

  // ---- names ----

  /// The name friends see; '' goes back to the Google name.
  static Future<void> setDisplayName(String name) async {
    RemoteConfig.instance.me = await server('PATCH', '/me', {'displayName': name}) as Map<String, dynamic>;
  }

  static String get displayName => RemoteConfig.instance.me?['displayName'] as String? ?? '';

  /// A name for a friend only I see; '' takes it away.
  static Future<void> setAlias(String uid, String alias) =>
      server('PUT', '/friends/${_q(uid)}/alias', {'alias': alias});

  // ---- reading ----

  static Future<List<Summary>> recipes(
      {String q = '', String? cookbook, int? collection, String? tag}) async {
    final query = {
      if (q.isNotEmpty) 'q': q,
      'tag': ?tag,
      'cookbook': ?cookbook,
      'collection': ?collection?.toString(),
    };
    final path = Uri(path: '/recipes', queryParameters: query.isEmpty ? null : query).toString();
    // The full list is what the home screen shows: kept for the kitchen offline.
    final list = (query.isEmpty
        ? await cached('recipes', () => server('GET', path))
        : await server('GET', path)) as List;
    return [for (final r in list) Summary(r as Map<String, dynamic>)];
  }

  /// The book's tags and categories, together and sorted, for picking one.
  static Future<List<String>> tags() async {
    final j = await server('GET', '/tags') as Map;
    final tags = (j['tags'] as List? ?? const []).map((value) => '$value');
    final categories = (j['categories'] as List? ?? const []).map((value) => '$value');
    return {...tags, ...categories}.toList()..sort();
  }

  static Future<List<Shelf>> cookbooks() async =>
      [for (final c in await cached('cookbooks', () => server('GET', '/cookbooks')) as List) Shelf(c as Map<String, dynamic>)];

  static Future<List<Shelf>> collections() async =>
      [for (final c in await cached('collections', () => server('GET', '/collections')) as List) Shelf(c as Map<String, dynamic>)];

  static Future<Recipe> recipe(String id) async =>
      Recipe(await cached('recipe.$id', () => server('GET', '/recipes/${_q(id)}'), recipe: true)
          as Map<String, dynamic>);

  static Future<Comments> comments(String id) async =>
      Comments(await server('GET', '/recipes/${_q(id)}/comments') as Map<String, dynamic>);

  /// [mates]: the household too, as in the to-do app (same people in both).
  static Future<List<Friend>> friends({bool mates = false}) async => [
        for (final f in await server('GET', mates ? '/friends?mates=1' : '/friends') as List)
          Friend(f as Map<String, dynamic>)
      ];

  // ---- small writes from the recipe screen ----

  /// 0.5 to 5 in half steps, or null to clear.
  static Future<void> setRating(String id, double? stars) =>
      server('PUT', '/recipes/${_q(id)}/rating', {'stars': stars});

  static Future<Shelf> createCollection(String title) async =>
      Shelf(await server('POST', '/collections', {'title': title}) as Map<String, dynamic>);

  /// Puts the recipe in the cookbook ([inIt]) or takes it out.
  static Future<void> fileRecipe(int collection, String id, bool inIt) =>
      server(inIt ? 'PUT' : 'DELETE', '/collections/$collection/recipes/${_q(id)}');

  /// A link to the to-do app's import screen with these lines (as shown, so
  /// doubled amounts stay doubled).
  static Future<String> shoppingList(String id, List<String> lines) async =>
      (await server('POST', '/recipes/${_q(id)}/shopping-list', {'lines': lines}) as Map)['url'] as String;

  /// On the kitchen screen at the next button press; 409 when this book has no screen linked.
  /// Want to make it this week, or (false) made it.
  static Future<void> plan(String id, bool on) => server(on ? 'PUT' : 'DELETE', '/recipes/${_q(id)}/plan');

  static Future<void> showOnScreen(String id, int scale) =>
      server('POST', '/recipes/${_q(id)}/show', {'scale': scale});

  /// A copy into the friend's book; the note opens a conversation in it.
  static Future<void> send(String id, String to, String note) =>
      server('POST', '/recipes/${_q(id)}/send', {'to': to, 'note': note});

  /// [thread]: a copy of this recipe, to answer in the conversation with that friend.
  static Future<void> addComment(String id, String body, {String? thread}) =>
      server('POST', '/recipes/${_q(id)}/comments', {'body': body, 'thread': ?thread});

  static Future<void> deleteComment(int id) => server('DELETE', '/comments/$id');

  // ---- adding and editing ----

  /// From a link (a recipe site or a cooking video) or pasted text. The
  /// Hebrew follows in the background. Returns the new recipe's id.
  static Future<String> createRecipe({String? url, String? text, List<int> collections = const []}) async =>
      (await server('POST', '/recipes', {'url': ?url, 'text': ?text, 'collections': collections},
          slowCall) as Map)['id'] as String;

  /// From a photo or PDF of a recipe, with an optional photo of the dish.
  static Future<String> uploadRecipe((List<int>, String) source, (List<int>, String)? dish,
          List<int> collections) async =>
      (await serverUpload('POST', '/recipes/upload',
          files: {'source': source, 'photo': ?dish},
          fields: {'collections': collections.join(',')}) as Map)['id'] as String;

  /// Only the fields that changed: name, tags, categories, sourceUrl.
  static Future<void> updateRecipe(String id, Map<String, Object> patch) =>
      server('PATCH', '/recipes/${_q(id)}', patch);

  static Future<void> deleteRecipe(String id) => server('DELETE', '/recipes/${_q(id)}');

  /// Returns the new photo's signed path.
  static Future<String?> setPhoto(String id, (List<int>, String) photo) async =>
      (await serverUpload('PUT', '/recipes/${_q(id)}/photo', files: {'photo': photo}) as Map)['image']
          as String?;

  /// Prices as typed ("12.90", "" for none); the server parses them.
  static Future<void> setPrices(String id, List<({String line, String price})> lines) =>
      server('PUT', '/recipes/${_q(id)}/prices', [
        for (final l in lines) {'line': l.line, 'price': l.price}
      ]);

  // ---- the book's own cookbooks ----

  static Future<void> renameCollection(int id, String title) =>
      server('PATCH', '/collections/$id', {'title': title});

  static Future<void> setCollectionCover(int id, (List<int>, String) photo) =>
      serverUpload('PUT', '/collections/$id/cover', files: {'photo': photo});

  /// Back to the newest recipe's photo.
  static Future<void> resetCollectionCover(int id) => server('DELETE', '/collections/$id/cover');

  /// The cookbook only; its recipes stay in the book.
  static Future<void> deleteCollection(int id) => server('DELETE', '/collections/$id');

  /// A copy of the whole cookbook into the friend's book.
  /// Copies every recipe while you wait: up to 100, so the slow deadline.
  static Future<void> sendCollection(int id, String to, String note) =>
      server('POST', '/collections/$id/send', {'to': to, 'note': note}, slowCall);

  // ---- friends and the inbox ----

  /// A single-use link, valid for a week.
  static Future<String> createInvite() async =>
      (await server('POST', '/friends/invites') as Map)['url'] as String;

  /// Works before this account is let in: accepting is what lets it in.
  static Future<Friend> acceptInvite(String token) async =>
      Friend(await server('POST', '/friends/invites/${_q(token)}/accept') as Map<String, dynamic>);

  static Future<void> removeFriend(String uid) => server('DELETE', '/friends/${_q(uid)}');

  // ---- admin ----

  static bool get isAdmin => RemoteConfig.instance.me?['admin'] == true;

  static Future<List<AdminUser>> adminUsers() async =>
      [for (final u in await server('GET', '/admin/users') as List) AdminUser(u as Map<String, dynamic>)];

  static Future<void> setBlocked(String uid, bool blocked) =>
      server('PUT', '/admin/users/${_q(uid)}/blocked', {'blocked': blocked});

  static Future<List<InboxItem>> inbox() async =>
      [for (final i in await server('GET', '/inbox') as List) InboxItem(i as Map<String, dynamic>)];

  /// [keep] leaves the copies in the book; otherwise they are deleted.
  static Future<void> settle(int id, {required bool keep}) =>
      server('POST', '/inbox/$id/${keep ? 'keep' : 'discard'}');

  // ---- the kitchen screen ----

  static Future<PanelInfo> panel() async => PanelInfo(await server('GET', '/panel') as Map<String, dynamic>);

  /// The font or size of what the screen draws, from its next wake.
  static Future<PanelInfo> setPanelStyle({String? font, String? scale}) async => PanelInfo(
      await server('PATCH', '/panel', {'font': ?font, 'scale': ?scale}) as Map<String, dynamic>);

  /// The idle screen (calendars) on the screen's next wake.
  static Future<void> showIdle() => server('POST', '/panel/idle');

  /// With the code the unlinked screen shows.
  static Future<PanelState> linkPanel(String code) async =>
      _panel(await server('POST', '/panel/link', {'code': code}));

  static PanelState _panel(dynamic j) => PanelState.values.byName((j as Map)['state'] as String);

  static Future<void> unlinkPanel() => server('DELETE', '/panel');

  static Future<List<CalendarFeed>> calendars() async =>
      [for (final c in await server('GET', '/calendars') as List) CalendarFeed(c as Map<String, dynamic>)];

  /// Returns how many events it has in the next month.
  static Future<int> addCalendar(String url, String name) async =>
      (await server('POST', '/calendars', {'url': url, 'name': name}) as Map)['upcoming'] as int? ?? 0;

  static Future<void> renameCalendar(int index, String name) =>
      server('PATCH', '/calendars/$index', {'name': name});

  static Future<void> deleteCalendar(int index) => server('DELETE', '/calendars/$index');
}
