import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_book/ui/recipe_widgets.dart';

void main() {
  Future<List<String>> run(WidgetTester t, {required bool undo}) async {
    final log = <String>[];
    final key = GlobalKey<ScaffoldMessengerState>();
    await t.pumpWidget(MaterialApp(scaffoldMessengerKey: key, home: const Scaffold()));
    deleteWithUndo(key.currentState!,
        said: 'נמחק',
        hide: () => log.add('hide'),
        restore: () => log.add('restore'),
        delete: () async => log.add('delete'),
        failed: 'x');
    await t.pumpAndSettle();
    if (undo) {
      await t.tap(find.text('ביטול'));
    } else {
      await t.pump(const Duration(seconds: 6));
    }
    await t.pumpAndSettle();
    return log;
  }

  testWidgets('undo brings it back and nothing is deleted', (t) async {
    expect(await run(t, undo: true), ['hide', 'restore']);
  });

  testWidgets('no undo: deleted on the server once the toast goes', (t) async {
    expect(await run(t, undo: false), ['hide', 'delete']);
  });
}
