import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/i18n.dart';
import '../core/settings_store.dart';

const _fontLabels = {
  'Rubik': 'Rubik', 'NotoSans': 'Noto Sans', 'NotoSerif': 'Noto Serif',
  'Heebo': 'Heebo', 'Assistant': 'Assistant', 'Alef': 'Alef',
  'FrankRuhlLibre': 'Frank Ruhl Libre', 'DavidLibre': 'David Libre',
  'SecularOne': 'Secular One', 'Roboto': 'Roboto', 'OpenSans': 'Open Sans',
  'Montserrat': 'Montserrat', 'Inter': 'Inter',
  'SourceSans3': 'Source Sans 3', 'Merriweather': 'Merriweather',
  'PlayfairDisplay': 'Playfair Display',
};

class PreferencesPage extends StatelessWidget {
  const PreferencesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = SettingsStore.instance;
    return Scaffold(
      appBar: AppBar(title: Text(t('העדפות'))),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
        _PreferenceSection(
          icon: _PreferenceIcon.language,
          title: t('שפה'),
          child: SegmentedButton<String>(
            segments: [for (final e in languages.entries) ButtonSegment(value: e.key, label: Text(e.value))],
            selected: {store.lang},
            onSelectionChanged: (s) => store.setLang(s.first),
          ),
        ),
        const SizedBox(height: 12),
        _PreferenceSection(
          icon: _PreferenceIcon.theme,
          title: t('ערכת נושא'),
          child: ListenableBuilder(
            listenable: store,
            builder: (context, _) => SegmentedButton<ThemeMode>(
              segments: [
                ButtonSegment(value: ThemeMode.system, label: Text(t('כמו במכשיר'))),
                ButtonSegment(value: ThemeMode.light, label: Text(t('בהיר'))),
                ButtonSegment(value: ThemeMode.dark, label: Text(t('כהה'))),
              ],
              selected: {store.themeMode},
              onSelectionChanged: (s) => store.setThemeMode(s.first),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _PreferenceSection(
          icon: _PreferenceIcon.type,
          title: t('גופן וגודל טקסט'),
          child: ListenableBuilder(
            listenable: store,
            builder: (context, _) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              DropdownButtonFormField<String>(
                initialValue: store.font,
                decoration: InputDecoration(labelText: t('גופן'), border: const OutlineInputBorder()),
                items: [
                  for (final key in fontKeysFor(store.lang))
                    DropdownMenuItem(
                      value: key,
                      child: Text(_fontLabels[key]!, style: TextStyle(fontFamily: key)),
                    ),
                ],
                onChanged: (v) { if (v != null) store.setFont(v); },
              ),
              const SizedBox(height: 12),
              Text(t('גודל הטקסט · {0}%', [(store.textScale * 100).round()])),
              Slider(
                value: store.textScale,
                min: .8,
                max: 1.6,
                divisions: 8,
                label: '${(store.textScale * 100).round()}%',
                onChanged: store.setTextScale,
              ),
              Text('Aa  אבג  ДИ', style: TextStyle(fontFamily: store.font, fontSize: 20 * store.textScale)),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _PreferenceSection extends StatelessWidget {
  const _PreferenceSection({required this.icon, required this.title, required this.child});

  final _PreferenceIcon icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _SvgSectionIcon(icon),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleSmall),
            ]),
            const SizedBox(height: 14),
            child,
          ]),
        ),
      );
}

enum _PreferenceIcon { language, theme, type }

class _SvgSectionIcon extends StatelessWidget {
  const _SvgSectionIcon(this.icon);
  final _PreferenceIcon icon;

  @override
  Widget build(BuildContext context) {
    final color = '#${Theme.of(context).colorScheme.primary.toARGB32().toRadixString(16).substring(2)}';
    final mark = switch (icon) {
      _PreferenceIcon.language => '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3a15 15 0 0 1 0 18M12 3a15 15 0 0 0 0 18"/>',
      _PreferenceIcon.theme => '<circle cx="12" cy="12" r="9"/><path d="M12 3v18a9 9 0 0 0 0-18Z"/>',
      _PreferenceIcon.type => '<path d="M4 20 10 4h4l6 16M6 15h12M3 22h18"/>',
    };
    return SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="$color" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">$mark</svg>',
      width: 18,
      height: 18,
      semanticsLabel: null,
    );
  }
}
