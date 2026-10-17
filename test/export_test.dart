import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_book/recipes/api.dart';
import 'package:recipe_book/recipes/export.dart';

final _recipe = Recipe({
  'id': 'r1',
  'title': 'שקשוקה',
  'servings': '4',
  'totalTime': '30 דקות',
  'steps': ['מחממים שמן', 'מוסיפים ביצים'],
  'sourceUrl': 'https://example.com/shakshuka',
});
const _lines = ['8 ביצים', 'רסק עגבניות'];

void main() {
  test('CSV cells are quoted only when they must be', () {
    expect(csvCell('שקשוקה'), 'שקשוקה');
    expect(csvCell('ביצים, עגבניות'), '"ביצים, עגבניות"');
    expect(csvCell('2 כוסות\nקמח'), '"2 כוסות\nקמח"');
    expect(csvCell('אומרים "וואו"'), '"אומרים ""וואו"""');
  });

  test('a recipe as text and Markdown: the shown amounts, numbered steps, source', () {
    expect(recipeText(_recipe, _lines), '''שקשוקה
4 מנות · 30 דקות

מצרכים
• 8 ביצים
• רסק עגבניות

אופן ההכנה
1. מחממים שמן
2. מוסיפים ביצים

מקור: https://example.com/shakshuka''');
    final md = recipeMarkdown(_recipe, _lines);
    expect(md, startsWith('# שקשוקה\n'));
    expect(md, contains('## מצרכים\n\n- 8 ביצים\n- רסק עגבניות\n'));
    expect(md, contains('2. מוסיפים ביצים'));
    expect(md, endsWith('[מקור](https://example.com/shakshuka)'));
  });

  test('a recipe as PDF, with the photo and without one it cannot read', () async {
    final font = File('assets/fonts/Rubik.ttf').readAsBytesSync();
    final photo = File('assets/icon.png').readAsBytesSync();
    final withPhoto = await recipePdf(_recipe, _lines, font: font, photo: photo);
    final without = await recipePdf(_recipe, _lines, font: font, photo: Uint8List(8));
    expect(String.fromCharCodes(withPhoto.take(5)), '%PDF-');
    expect(String.fromCharCodes(withPhoto), contains('/XObject'));
    expect(String.fromCharCodes(without), isNot(contains('/XObject')));
  });
}
