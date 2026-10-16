import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'api.dart';

/// Settings › "ייצוא": the whole book, every recipe in full, with the book's
/// own cookbooks. JSON keeps everything; CSV opens in Excel (one row a recipe).
class BookExport {
  BookExport(this.json, this.csv);
  final String json;
  final String csv;
}

/// [progress] counts the recipes read so far, out of the total.
Future<BookExport> exportBook({ValueNotifier<(int, int)>? progress}) async {
  final summaries = await Api.recipes();
  final collections = await Api.collections();
  final recipes = <Recipe>[];
  progress?.value = (0, summaries.length);
  // A few at a time: the server reads each from Mealie, which it throttles.
  for (var i = 0; i < summaries.length; i += 4) {
    recipes.addAll(await Future.wait([
      for (final s in summaries.skip(i).take(4)) Api.recipe(s.id),
    ]));
    progress?.value = (recipes.length, summaries.length);
  }
  final now = DateTime.now().toIso8601String();
  final json = const JsonEncoder.withIndent('  ').convert({
    'exportedAt': now,
    'book': Api.book,
    'cookbooks': [
      for (final c in collections)
        {
          'id': c.id,
          'title': c.title,
          'recipes': [for (final r in recipes) if (r.collections.contains(c.id)) r.id],
        },
    ],
    'recipes': [for (final r in recipes) r.j],
  });
  final titles = {for (final c in collections) c.id: c.title};
  final rows = [
    ['מזהה', 'שם', 'שם במקור', 'דירוג', 'מנות', 'זמן', 'עלות משוערת', 'ספרים', 'תגיות', 'מצרכים', 'אופן הכנה', 'מקור'],
    for (final r in recipes)
      [
        r.id,
        r.title,
        r.name,
        r.rating?.toString() ?? '',
        r.servings,
        r.totalTime,
        r.cost?.total.toStringAsFixed(2) ?? '',
        [for (final c in r.collections) titles[c] ?? '$c'].join(', '),
        r.allTags.join(', '),
        [for (final p in r.prices) p.line].join('\n'),
        r.steps.join('\n'),
        r.sourceUrl,
      ],
  ];
  // The BOM tells Excel it's UTF-8, or the Hebrew comes out garbled.
  return BookExport(json, '﻿${rows.map((r) => r.map(csvCell).join(',')).join('\r\n')}\r\n');
}

/// A CSV field: quoted when it holds a comma, a quote or a line break.
String csvCell(String v) =>
    RegExp(r'[",\r\n]').hasMatch(v) ? '"${v.replaceAll('"', '""')}"' : v;
