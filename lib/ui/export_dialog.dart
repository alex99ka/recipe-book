import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../core/errors.dart';
import '../recipes/export.dart';

/// Settings › "ייצוא הספר": reads the book with a progress dialog, then hands
/// over two files. Windows: a folder to save them in. Android and the web:
/// the share sheet (on the web it downloads them).
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
        title: 'ספר המתכונים',
      ));
    }
  } catch (e) {
    showError(messenger, e, 'שמירת הקבצים נכשלה');
  }
}
