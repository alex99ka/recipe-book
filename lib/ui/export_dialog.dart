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
      title: const Text('מכין את הייצוא'),
      content: ValueListenableBuilder(
        valueListenable: progress,
        builder: (_, p, _) => Column(mainAxisSize: MainAxisSize.min, children: [
          LinearProgressIndicator(value: p.$2 == 0 ? null : p.$1 / p.$2),
          const SizedBox(height: 12),
          Text(p.$2 == 0 ? 'קורא את רשימת המתכונים…' : '${p.$1} מתוך ${p.$2} מתכונים'),
        ]),
      ),
    ),
  );
  final BookExport export;
  try {
    export = await exportBook(progress: progress);
  } catch (e) {
    nav.pop();
    showError(messenger, e, 'הייצוא נכשל');
    return;
  }
  nav.pop();
  final day = DateTime.now().toIso8601String().substring(0, 10);
  final files = [
    XFile.fromData(utf8.encode(export.json), name: 'recipes-$day.json', mimeType: 'application/json'),
    XFile.fromData(utf8.encode(export.csv), name: 'recipes-$day.csv', mimeType: 'text/csv'),
  ];
  await _handOver(messenger, files, 'ספר המתכונים');
}

/// Windows: a folder to save them in. Android and the web: the share sheet
/// (on the web it downloads them).
Future<void> _handOver(ScaffoldMessengerState messenger, List<XFile> files, String title) async {
  try {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      final dir = await getDirectoryPath(confirmButtonText: 'שמירה כאן');
      if (dir == null) return;
      for (final f in files) {
        await f.saveTo('$dir\\${f.name}');
      }
      messenger.showSnackBar(SnackBar(content: Text('נשמר בתיקייה $dir')));
    } else {
      await SharePlus.instance.share(ShareParams(
        files: files,
        fileNameOverrides: [for (final f in files) f.name],
        title: title,
      ));
    }
  } catch (e) {
    showError(messenger, e, 'שמירת הקבצים נכשלה');
  }
}

/// The recipe page's "ייצוא": PDF (with the photo), text or Markdown.
Future<void> exportRecipeFile(BuildContext context, Recipe r, List<String> lines) async {
  final messenger = ScaffoldMessenger.of(context);
  final kind = await showItemMenu(context, 'ייצוא המתכון', const [
    (Icons.picture_as_pdf_outlined, 'PDF עם התמונה'),
    (Icons.notes, 'טקסט (TXT)'),
    (Icons.code, 'Markdown (MD)'),
  ]);
  if (kind == null) return;
  // Hebrew file names are fine on every system; only what breaks paths goes.
  final name = r.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ').trim();
  final XFile file;
  try {
    file = switch (kind) {
      0 => XFile.fromData(
          await recipePdf(r, lines,
              font: (await rootBundle.load('assets/fonts/Rubik.ttf')).buffer.asUint8List(),
              photo: await _photo(r)),
          name: '$name.pdf',
          mimeType: 'application/pdf'),
      1 => XFile.fromData(utf8.encode(recipeText(r, lines)), name: '$name.txt', mimeType: 'text/plain'),
      _ => XFile.fromData(utf8.encode(recipeMarkdown(r, lines)),
          name: '$name.md', mimeType: 'text/markdown'),
    };
  } catch (e) {
    showError(messenger, e, 'הייצוא נכשל');
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
