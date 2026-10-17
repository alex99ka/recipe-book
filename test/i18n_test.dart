import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_book/config.dart';
import 'package:recipe_book/core/errors.dart';
import 'package:recipe_book/core/home_widgets.dart';
import 'package:recipe_book/core/i18n.dart';
import 'package:recipe_book/core/i18n_table.dart';
import 'package:recipe_book/core/notifications.dart';
import 'package:recipe_book/core/settings_store.dart';
import 'package:recipe_book/core/tour.dart';

/// A Dart '...' literal's text, for the escapes the app's strings use.
String unescape(String s) => s.replaceAllMapped(
    RegExp(r'\\(.)'), (m) => switch (m[1]!) { 'n' => '\n', final c => c });

/// Every Hebrew word the app shows: what t('...') is called with in the
/// code, and the texts kept as data and translated where they are shown.
Set<String> needed() => {
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>())
        if (f.path.endsWith('.dart'))
          for (final m in RegExp(r"\bt\('((?:[^'\\]|\\.)*)'").allMatches(f.readAsStringSync()))
            unescape(m[1]!),
      for (final e in Errors.all) ...[e.why, e.todo],
      for (final s in fullTour) ...[s.title, s.body],
      ...notificationTypes.values,
      ...widgets.values,
      AppConfig.name,
    };

void main() {
  tearDown(() => SettingsStore.instance.lang = 'he');

  test('every word the app shows has its Russian and English', () {
    final missing = needed().where((he) => !translations.containsKey(he)).toList();
    // Printed as JSON so a missing batch can be pasted straight into the table.
    expect(missing, isEmpty, reason: const JsonEncoder.withIndent(' ').convert(missing));
  });

  test('a translation keeps every {n} of its Hebrew', () {
    final slot = RegExp(r'\{\d\}');
    for (final MapEntry(key: he, value: (ru, en)) in translations.entries) {
      final want = slot.allMatches(he).map((m) => m[0]).toSet();
      expect(slot.allMatches(ru).map((m) => m[0]).toSet(), want, reason: 'ru: $he');
      expect(slot.allMatches(en).map((m) => m[0]).toSet(), want, reason: 'en: $he');
    }
  });

  test('t fills the slots, and Hebrew is the default and the fallback', () {
    expect(t('גרסה {0}', ['5.11.0']), 'גרסה 5.11.0');
    SettingsStore.instance.lang = 'en';
    expect(t('גרסה {0}', ['5.11.0']), 'Version 5.11.0');
    expect(t('לא בטבלה'), 'לא בטבלה');
    SettingsStore.instance.lang = 'ru';
    expect(errorText(Errors.noConnection), startsWith('Нет подключения к интернету.'));
  });
}
