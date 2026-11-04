import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'server.dart';

/// Per-device choices that change how the app looks.
class SettingsStore extends ChangeNotifier {
  SettingsStore._();
  static final instance = SettingsStore._();

  ThemeMode themeMode = ThemeMode.system;

  /// Early users only: install prereleases. On until they turn it off.
  bool beta = true;

  /// Off: the screen stays upright even when the phone or tablet is turned.
  bool rotate = true;

  /// 'he', 'ru' or 'en': the app's words, and the recipes the server sends.
  String lang = 'he';

  /// Text size on top of the device's own, 1 = as the device has it.
  double textScale = 1;

  /// Selected bundled typeface; Noto companions fill any missing script glyphs.
  String font = 'Rubik';

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getString('theme');
      themeMode = ThemeMode.values.firstWhere((m) => m.name == v,
          orElse: () => ThemeMode.system);
      beta = prefs.getBool('beta') ?? true;
      rotate = prefs.getBool('rotate') ?? true;
      lang = prefs.getString('lang') ?? 'he';
      textScale = prefs.getDouble('textScale') ?? 1;
      font = prefs.getString('font') ?? 'Rubik';
      if (!fontKeysFor(lang).contains(font)) font = defaultFontFor(lang);
      _applyLang();
    } catch (_) {}
    _applyRotate();
  }

  // An empty list lets the system (and its own rotation lock) decide.
  void _applyRotate() => SystemChrome.setPreferredOrientations(
      rotate ? const [] : const [DeviceOrientation.portraitUp]).ignore();

  // Hebrew is the server's default, so it needs no header.
  void _applyLang() => lang == 'he' ? serverHeaders.remove('X-Lang') : serverHeaders['X-Lang'] = lang;

  Future<void> setLang(String code) async {
    lang = code;
    if (!fontKeysFor(code).contains(font)) font = defaultFontFor(code);
    _applyLang();
    notifyListeners();
    try {
      await (await SharedPreferences.getInstance()).setString('lang', code);
    } catch (_) {}
  }

  Future<void> setTextScale(double s) async {
    textScale = s;
    notifyListeners();
    try {
      await (await SharedPreferences.getInstance()).setDouble('textScale', s);
    } catch (_) {}
  }

  Future<void> setFont(String value) async {
    font = value;
    notifyListeners();
    try { await (await SharedPreferences.getInstance()).setString('font', value); } catch (_) {}
  }

  Future<void> setRotate(bool on) async {
    rotate = on;
    notifyListeners();
    _applyRotate();
    try {
      await (await SharedPreferences.getInstance()).setBool('rotate', on);
    } catch (_) {}
  }

  Future<void> setBeta(bool on) async {
    beta = on;
    notifyListeners();
    try {
      await (await SharedPreferences.getInstance()).setBool('beta', on);
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode m) async {
    themeMode = m;
    notifyListeners();
    try {
      await (await SharedPreferences.getInstance()).setString('theme', m.name);
    } catch (_) {}
  }
}

const _hebrewFontKeys = [
  'Rubik', 'NotoSans', 'NotoSerif', 'Heebo', 'Assistant', 'Alef',
  'FrankRuhlLibre', 'DavidLibre', 'SecularOne', 'OpenSans',
];
const _latinCyrillicFontKeys = [
  'Roboto', 'OpenSans', 'Rubik', 'Montserrat', 'NotoSans', 'Inter',
  'SourceSans3', 'Merriweather', 'PlayfairDisplay', 'NotoSerif',
];
List<String> fontKeysFor(String language) =>
    language == 'he' ? _hebrewFontKeys : _latinCyrillicFontKeys;
String defaultFontFor(String language) => fontKeysFor(language).first;
