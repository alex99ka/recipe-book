import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

import '../core/errors.dart';
import '../recipes/api.dart';
import '../recipes/export.dart';
import 'recipe_widgets.dart';
import '../core/i18n.dart';

/// Settings › "ייצוא הספר": reads the book with a progress dialog, then hands
/// over two files.
Future<void> exportBookFiles(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final progress = ValueNotifier<(int, int)>((0, 0));
  final nav = Navigator.of(context);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (c) => AlertDialog(
      title: Text(t('מכין את הייצוא')),
      content: ValueListenableBuilder(
        valueListenable: progress,
        builder: (_, p, _) => Column(mainAxisSize: MainAxisSize.min, children: [
          LinearProgressIndicator(value: p.$2 == 0 ? null : p.$1 / p.$2),
          const SizedBox(height: 12),
          Text(p.$2 == 0 ? t('קורא את רשימת המתכונים…') : t('{0} מתוך {1} מתכונים', [p.$1, p.$2])),
        ]),
      ),
    ),
  );
  final BookExport export;
  try {
    export = await exportBook(progress: progress);
  } catch (e) {
    nav.pop();
    showError(messenger, e, t('הייצוא נכשל'));
    return;
  }
  nav.pop();
  final day = DateTime.now().toIso8601String().substring(0, 10);
  final files = [
    _named('recipes-$day.json', utf8.encode(export.json), 'application/json'),
    _named('recipes-$day.csv', utf8.encode(export.csv), 'text/csv'),
  ];
  await _handOver(messenger, files, t('ספר המתכונים'));
}

/// A file with its name kept beside it: off the web, XFile.fromData drops the
/// name (its `name` comes from the empty path), and share_plus then writes to
/// the bare temp folder — "Is a directory".
(String, XFile) _named(String name, List<int> bytes, String mime) =>
    (name, XFile.fromData(Uint8List.fromList(bytes), name: name, mimeType: mime));

/// Windows: a folder to save them in. Android and the web: the share sheet
/// (on the web it downloads them).
Future<void> _handOver(
    ScaffoldMessengerState messenger, List<(String, XFile)> files, String title) async {
  try {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      final dir = await getDirectoryPath(confirmButtonText: t('שמירה כאן'));
      if (dir == null) return;
      for (final (name, f) in files) {
        await f.saveTo('$dir\\$name');
      }
      messenger.showSnackBar(SnackBar(content: Text(t('נשמר בתיקייה {0}', [dir]))));
    } else {
      await SharePlus.instance.share(ShareParams(
        files: [for (final (_, f) in files) f],
        fileNameOverrides: [for (final (name, _) in files) name],
        title: title,
      ));
    }
  } catch (e) {
    showError(messenger, e, t('שמירת הקבצים נכשלה'));
  }
}

/// The recipe page's "ייצוא": PDF (with the photo), text or Markdown.
Future<void> exportRecipeFile(BuildContext context, Recipe r, List<String> lines) async {
  final messenger = ScaffoldMessenger.of(context);
  final kind = await showItemMenu(context, t('ייצוא המתכון'), [
    (Icons.picture_as_pdf_outlined, t('PDF עם התמונה')),
    (Icons.notes, t('טקסט (TXT)')),
    (Icons.code, 'Markdown (MD)'),
  ]);
  if (kind == null) return;
  // Hebrew file names are fine on every system; only what breaks paths goes.
  final cleaned = r.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ').trim();
  final name = cleaned.isEmpty ? 'recipe' : cleaned;
  final (String, XFile) file;
  try {
    file = switch (kind) {
      0 => _named(
          '$name.pdf',
          await recipePdf(r, lines,
              font: (await rootBundle.load('assets/fonts/Rubik.ttf')).buffer.asUint8List(),
              photo: await _photo(r)),
          'application/pdf'),
      1 => _named('$name.txt', utf8.encode(recipeText(r, lines)), 'text/plain'),
      _ => _named('$name.md', utf8.encode(recipeMarkdown(r, lines)), 'text/markdown'),
    };
  } catch (e) {
    showError(messenger, e, t('הייצוא נכשל'));
    return;
  }
  await _handOver(messenger, [file], r.title);
}

/// The recipe's photo, or null: a PDF without it beats no PDF.
Future<Uint8List?> _photo(Recipe r) async {
  final url = Api.imageUrl(r.image);
  if (url == null) return null;
  try {
    final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
    return res.statusCode == 200 ? res.bodyBytes : null;
  } catch (_) {
    return null;
  }
}
