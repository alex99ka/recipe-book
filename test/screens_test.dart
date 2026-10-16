import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_book/recipes/api.dart';
import 'package:recipe_book/ui/add_recipe_screen.dart';
import 'package:recipe_book/ui/edit_recipe_screen.dart';
import 'package:recipe_book/ui/friends_screen.dart';
import 'package:recipe_book/ui/inbox_screen.dart';
import 'package:recipe_book/ui/panel_screen.dart';
import 'package:recipe_book/ui/theme.dart';

/// The new 5.1.0 screens build on a phone-sized RTL screen without layout
/// errors. There's no Firebase here, so screens that load show their error.
Future<void> pump(WidgetTester t, Widget screen) async {
  t.view.physicalSize = const Size(360, 780);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(
    theme: appTheme(Brightness.light),
    home: Directionality(textDirection: TextDirection.rtl, child: screen),
  ));
  await t.pump(const Duration(milliseconds: 100));
}

final recipe = Recipe({
  'id': 'r1',
  'title': 'שקשוקה',
  'name': 'Shakshuka',
  'tags': ['ארוחת בוקר'],
  'categories': ['ביצים'],
  'sourceUrl': 'https://example.com/shakshuka',
  'prices': [
    {'line': '4 ביצים', 'price': 6.5, 'was': null},
    {'line': 'רסק עגבניות', 'price': null, 'was': '1 רסק עגבניות'},
  ],
  'collections': <int>[],
});

void main() {
  testWidgets('new recipe: link by default, then text and file modes', (t) async {
    await pump(t, const AddRecipeScreen());
    final add = find.widgetWithText(FilledButton, 'הוספה');
    expect(t.widget<FilledButton>(add).onPressed, isNull); // nothing typed yet
    await t.enterText(find.byType(TextField), 'https://example.com/r');
    await t.pump();
    expect(t.widget<FilledButton>(add).onPressed, isNotNull);
    await t.tap(find.text('צילום או PDF'));
    await t.pump();
    expect(find.text('תמונה של המנה (לא חובה)'), findsOneWidget);
    await t.tap(find.text('טקסט'));
    await t.pump();
    expect(t.widget<FilledButton>(add).onPressed, isNull);
  });

  testWidgets('edit: fields filled in, prices listed, delete at the bottom', (t) async {
    await pump(t, EditRecipeScreen(recipe));
    expect(find.text('Shakshuka'), findsOneWidget);
    expect(find.text('ארוחת בוקר'), findsOneWidget);
    expect(find.text('6.5'), findsOneWidget);
    expect(find.text('תומחר כשהשורה הייתה: 1 רסק עגבניות'), findsOneWidget);
    await t.scrollUntilVisible(find.text('מחיקת המתכון'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('מחיקת המתכון'), findsOneWidget);
  });

  for (final (name, screen) in [
    ('friends', const FriendsScreen()),
    ('inbox', const InboxScreen()),
    ('screen', const PanelScreen()),
  ]) {
    testWidgets('$name builds and shows a load error without a server', (t) async {
      await pump(t, screen);
      await t.pump(const Duration(seconds: 1));
      expect(t.takeException(), isNull);
      expect(find.text('לנסות שוב'), findsOneWidget);
    });
  }
}
