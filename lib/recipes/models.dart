/// The recipe server's JSON shapes, read through zero-cost extension types.
///
/// These declarations stay separate from the HTTP methods so the wire format
/// and the operations that use it can be navigated independently.
library;

extension type Book(Map<String, dynamic> j) {
  String get key => j['key'] as String;
  String get title => j['title'] as String? ?? '';
}

extension type Summary(Map<String, dynamic> j) {
  String get id => j['id'] as String;

  /// Hebrew once translated, otherwise the original name.
  String get title => j['title'] as String? ?? '';

  /// The name in the source's language (what editing changes).
  String get name => j['name'] as String? ?? '';
  String? get image => j['image'] as String?;
  double? get rating => (j['rating'] as num?)?.toDouble();
  List<String> get tags => _strings(j['tags']);
  List<String> get categories => _strings(j['categories']);
  bool get translated => j['translated'] == true;

  /// Marked "want to make this week" (the server drops it after 7 days).
  DateTime? get plannedAt => DateTime.tryParse(j['plannedAt'] as String? ?? '')?.toLocal();
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

  /// A photo someone chose, not the newest recipe's.
  bool get customCover => j['customCover'] as bool? ?? false;
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

  /// The name they chose for themselves, and the one I gave them ('' for none).
  String get chosen => j['chosen'] as String? ?? name;
  String get alias => j['alias'] as String? ?? '';

  /// In the household: shares the book already, so never sent to or removed.
  bool get mate => j['mate'] as bool? ?? false;
}

/// An account, on the admin screen.
extension type AdminUser(Map<String, dynamic> j) {
  String get uid => j['uid'] as String;
  String get name => j['name'] as String? ?? '';
  String get email => j['email'] as String? ?? '';
  bool get blocked => j['blocked'] as bool? ?? false;
  bool get admin => j['admin'] as bool? ?? false;
  DateTime get firstSeen => DateTime.parse(j['firstSeen'] as String).toLocal();
  DateTime get lastSeen => DateTime.parse(j['lastSeen'] as String).toLocal();

  /// The books it reads: {title, recipes, createdThisMonth}.
  List<Map<String, dynamic>> get books => (j['books'] as List).cast<Map<String, dynamic>>();
}

/// Something a friend sent. The copies are already in the book.
extension type InboxItem(Map<String, dynamic> j) {
  int get id => j['id'] as int;
  String get from => j['from'] as String? ?? '';
  String get title => j['title'] as String? ?? '';
  int get count => j['count'] as int? ?? 0;
  String get note => j['note'] as String? ?? '';

  /// Set for a single recipe.
  String? get recipeId => j['recipeId'] as String?;

  /// Set for a whole cookbook (its copy in this book).
  int? get collectionId => j['collectionId'] as int?;
}

/// A calendar on the kitchen screen's idle page; the address stays on the server.
extension type CalendarFeed(Map<String, dynamic> j) {
  int get index => j['index'] as int;
  String get name => j['name'] as String? ?? '';
  String get host => j['host'] as String? ?? '';

  /// Events in the next 30 days; null when the feed couldn't be read.
  int? get upcoming => j['upcoming'] as int?;
  String get error => j['error'] as String? ?? '';
}

/// Whose the kitchen screen is: this book's, nobody's (it shows a code), or another book's.
enum PanelState { mine, free, taken }

/// The kitchen screen; everything but [state] only for the book it is linked to.
extension type PanelInfo(Map<String, dynamic> j) {
  PanelState get state => PanelState.values.byName(j['state'] as String);
  Map<String, dynamic> get _battery => j['battery'] as Map<String, dynamic>? ?? const {};
  int? get batteryPct => _battery['pct'] as int?;
  DateTime? get chargedAt => DateTime.tryParse(_battery['charged_at'] as String? ?? '')?.toLocal();

  /// When it will need charging; null until a few days of readings measure the drain.
  DateTime? get emptyAt => DateTime.tryParse(_battery['empty_at'] as String? ?? '')?.toLocal();
  double? get daysLeft => (_battery['days_left'] as num?)?.toDouble();
  DateTime? get lastSeen => DateTime.tryParse(j['last_seen_at'] as String? ?? '')?.toLocal();
  bool get idleQueued => j['idle_queued'] as bool? ?? false;
  String get font => j['font'] as String? ?? '';
  String get scale => j['scale'] as String? ?? '';
  List<({String key, String label})> get fonts => _choices(j['fonts']);
  List<({String key, String label})> get scales => _choices(j['scales']);
}

List<({String key, String label})> _choices(Object? v) => [
      for (final c in v as List? ?? const [])
        (key: (c as Map)['key'] as String, label: c['label'] as String)
    ];

List<String> _strings(Object? v) => [for (final x in v as List? ?? const []) '$x'];
List<Comment> _comments(Object? v) =>
    [for (final c in v as List? ?? const []) Comment(c as Map<String, dynamic>)];

