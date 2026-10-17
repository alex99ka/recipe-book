import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:pdf/widgets.dart' as pw;

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

/// The recipe page's "ייצוא": one recipe as plain text, Markdown or a PDF.
/// [lines] are the ingredients as shown (scaled ×1/×2/×3).
String recipeText(Recipe r, List<String> lines) => [
      r.title,
      if (_meta(r).isNotEmpty) _meta(r),
      '',
      'מצרכים',
      for (final l in lines) '• $l',
      if (r.steps.isNotEmpty) ...['', 'אופן ההכנה', for (final (i, s) in r.steps.indexed) '${i + 1}. $s'],
      if (r.sourceUrl.isNotEmpty) ...['', 'מקור: ${r.sourceUrl}'],
    ].join('\n');

String recipeMarkdown(Recipe r, List<String> lines) => [
      '# ${r.title}',
      if (_meta(r).isNotEmpty) ...['', _meta(r)],
      '',
      '## מצרכים',
      '',
      for (final l in lines) '- $l',
      if (r.steps.isNotEmpty) ...['', '## אופן ההכנה', '', for (final (i, s) in r.steps.indexed) '${i + 1}. $s'],
      if (r.sourceUrl.isNotEmpty) ...['', '[מקור](${r.sourceUrl})'],
    ].join('\n');

/// [font] needs Hebrew glyphs (the bundled Rubik); [photo] is left out when
/// null or not an image the PDF writer can read.
Future<Uint8List> recipePdf(Recipe r, List<String> lines,
    {required Uint8List font, Uint8List? photo}) async {
  try {
    return await _recipePdf(r, lines, font, photo);
  } catch (_) {
    if (photo == null) rethrow;
    return _recipePdf(r, lines, font, null); // the photo was what failed
  }
}

Future<Uint8List> _recipePdf(Recipe r, List<String> lines, Uint8List font, Uint8List? photo) {
  final image = photo == null ? null : pw.MemoryImage(photo);
  final doc = pw.Document(title: r.title);
  pw.Widget h(String t) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
      child: pw.Text(t, style: const pw.TextStyle(fontSize: 15)));
  doc.addPage(pw.MultiPage(
    theme: pw.ThemeData.withFont(base: pw.Font.ttf(ByteData.sublistView(font))),
    textDirection: pw.TextDirection.rtl,
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    build: (_) => [
      pw.Text(r.title, style: const pw.TextStyle(fontSize: 22)),
      if (_meta(r).isNotEmpty) pw.Text(_meta(r), style: const pw.TextStyle(fontSize: 10)),
      if (image != null)
        pw.Padding(
            padding: const pw.EdgeInsets.only(top: 10),
            child: pw.Image(image, height: 154, fit: pw.BoxFit.cover)),
      h('מצרכים'),
      for (final l in lines)
        pw.Padding(padding: const pw.EdgeInsets.only(bottom: 4), child: pw.Text('•  $l')),
      if (r.steps.isNotEmpty) ...[
        h('אופן ההכנה'),
        for (final (i, s) in r.steps.indexed)
          pw.Padding(padding: const pw.EdgeInsets.only(bottom: 4), child: pw.Text('${i + 1}. $s')),
      ],
      if (r.sourceUrl.isNotEmpty)
        pw.Padding(
            padding: const pw.EdgeInsets.only(top: 14),
            child: pw.Text('מקור: ${r.sourceUrl}', style: const pw.TextStyle(fontSize: 9))),
    ],
  ));
  return doc.save();
}

String _meta(Recipe r) =>
    [if (r.servings.isNotEmpty) '${r.servings} מנות', if (r.totalTime.isNotEmpty) r.totalTime].join(' · ');
