import 'i18n_table.dart';
import 'settings_store.dart';

/// The app's words in Russian or English, looked up by the Hebrew they stand
/// for: the Hebrew stays written where it is used, so the code reads as
/// before. {0}, {1}… are filled from [args]. A word missing from the table
/// shows in Hebrew (test/i18n_test.dart keeps the table complete).
String t(String he, [List<Object?> args = const []]) {
  final lang = SettingsStore.instance.lang;
  var s = lang == 'he' ? he : (translations[he]?.pick(lang) ?? he);
  for (var i = 0; i < args.length; i++) {
    s = s.replaceAll('{$i}', '${args[i] ?? ''}');
  }
  return s;
}

/// The languages, by code, as each calls itself.
const languages = {'he': 'עברית', 'ru': 'Русский', 'en': 'English'};

extension on (String, String) {
  String pick(String lang) => lang == 'ru' ? $1 : $2;
}
