import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../core/remote_config.dart';
import '../core/server.dart';

/// The recipe server's /api/v1 (cld/server/api.py). The shapes are the JSON
/// as the server sends it, read through zero-cost extension types.

extension type Book(Map<String, dynamic> j) {
  String get key => j['key'] as String;
  String get title => j['title'] as String? ?? '';
}

extension type Summary(Map<String, dynamic> j) {
  String get id => j['id'] as String;

  /// Hebrew once translated, otherwise the original name.
  String get title => j['title'] as String? ?? '';
  String? get image => j['image'] as String?;
  double? get rating => (j['rating'] as num?)?.toDouble();
  List<String> get tags => _strings(j['tags']);
  bool get translated => j['translated'] == true;
}

/// A scanned cookbook (source tag) or one of the book's own (a collection).
extension type Shelf(Map<String, dynamic> j) {
  /// The scanned cookbook's slug; null for a collection.
  String? get slug => j['slug'] as String?;

  /// The collection's id; null for a scanned cookbook.
  int? get id => j['id'] as int?;
  String get title => j['title'] as String? ?? '';
  String? get cover => j['cover'] as String?;
  int get count => j['count'] as int? ?? 0;
}

extension type PriceLine(Map<String, dynamic> j) {
  String get line => j['line'] as String;
  double? get price => (j['price'] as num?)?.toDouble();

  /// The old text, when the line changed since it was priced.
  String? get was => j['was'] as String?;
}

extension type Cost(Map<String, dynamic> j) {
  double get total => (j['total'] as num).toDouble();
  double? get servings => (j['servings'] as num?)?.toDouble();
  double? get perServing => (j['per_serving'] as num?)?.toDouble();
  int get missing => j['missing'] as int? ?? 0;
  int get stale => j['stale'] as int? ?? 0;
}

extension type Recipe(Map<String, dynamic> j) implements Summary {
  List<String> get steps => _strings(j['steps']);
  String get servings => j['servings'] as String? ?? '';
  String get totalTime => j['totalTime'] as String? ?? '';
  String get sourceUrl => j['sourceUrl'] as String? ?? '';
  List<String> get allTags => [..._strings(j['categories']), ..._strings(j['tags'])];

  /// The ingredient lines as the server shows them, each with its price.
  List<PriceLine> get prices =>
      [for (final p in j['prices'] as List? ?? const []) PriceLine(p as Map<String, dynamic>)];
  Cost? get cost => j['cost'] == null ? null : Cost(j['cost'] as Map<String, dynamic>);
  bool get translating => j['translating'] == true;
  List<int> get collections => [for (final c in j['collections'] as List? ?? const []) c as int];
}

extension type Comment(Map<String, dynamic> j) {
  int get id => j['id'] as int;
  String get author => j['author'] as String? ?? '';
  String get body => j['body'] as String? ?? '';
  bool get mine => j['mine'] == true;
  DateTime? get createdAt => DateTime.tryParse(j['createdAt'] as String? ?? '')?.toLocal();
}

extension type Thread(Map<String, dynamic> j) {
  String get copyId => j['copyId'] as String;
  String get friend => j['friend'] as String? ?? '';
  List<Comment> get comments => _comments(j['comments']);
}

extension type Comments(Map<String, dynamic> j) {
  List<Comment> get comments => _comments(j['comments']);

  /// On a copy a friend sent: who sent it (they see these comments too).
  String? get sentBy => j['sentBy'] as String?;

  /// On an original: one conversation per friend it was sent to.
  List<Thread> get threads =>
      [for (final t in j['threads'] as List? ?? const []) Thread(t as Map<String, dynamic>)];
}

extension type Friend(Map<String, dynamic> j) {
  String get uid => j['uid'] as String;
  String get name => j['name'] as String? ?? '';
}

List<String> _strings(Object? v) => [for (final x in v as List? ?? const []) '$x'];
List<Comment> _comments(Object? v) =>
    [for (final c in v as List? ?? const []) Comment(c as Map<String, dynamic>)];

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

  /// Images and covers come as signed paths under the server (`/api/v1/...`).
  static String? imageUrl(String? path) =>
      path == null ? null : Uri.parse(AppConfig.serverUrl).resolve(path).toString();

  // ---- reading ----

  static Future<List<Summary>> recipes({String q = '', String? cookbook, int? collection}) async {
    final query = {
      if (q.isNotEmpty) 'q': q,
      'cookbook': ?cookbook,
      'collection': ?collection?.toString(),
    };
    final list = await server('GET', Uri(path: '/recipes', queryParameters: query.isEmpty ? null : query).toString()) as List;
    return [for (final r in list) Summary(r as Map<String, dynamic>)];
  }

  static Future<List<Shelf>> cookbooks() async =>
      [for (final c in await server('GET', '/cookbooks') as List) Shelf(c as Map<String, dynamic>)];

  static Future<List<Shelf>> collections() async =>
      [for (final c in await server('GET', '/collections') as List) Shelf(c as Map<String, dynamic>)];

  static Future<Recipe> recipe(String id) async =>
      Recipe(await server('GET', '/recipes/${_q(id)}') as Map<String, dynamic>);

  static Future<Comments> comments(String id) async =>
      Comments(await server('GET', '/recipes/${_q(id)}/comments') as Map<String, dynamic>);

  static Future<List<Friend>> friends() async =>
      [for (final f in await server('GET', '/friends') as List) Friend(f as Map<String, dynamic>)];

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

  /// A copy into the friend's book; the note opens a conversation in it.
  static Future<void> send(String id, String to, String note) =>
      server('POST', '/recipes/${_q(id)}/send', {'to': to, 'note': note});

  /// [thread]: a copy of this recipe, to answer in the conversation with that friend.
  static Future<void> addComment(String id, String body, {String? thread}) =>
      server('POST', '/recipes/${_q(id)}/comments', {'body': body, 'thread': ?thread});

  static Future<void> deleteComment(int id) => server('DELETE', '/comments/$id');
}
