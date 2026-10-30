import 'package:flutter/material.dart';

import '../core/errors.dart';
import '../recipes/api.dart';
import 'recipe_widgets.dart';
import 'skeleton.dart';
import '../core/i18n.dart';

/// The kitchen's e-ink screen: link it to this book with the code it shows,
/// see its battery, set how it draws, and pick the calendars its idle page lists.
class PanelScreen extends StatefulWidget {
  const PanelScreen({super.key});

  @override
  State<PanelScreen> createState() => _PanelScreenState();
}

class _PanelScreenState extends State<PanelScreen> {
  PanelInfo? _panel;
  List<CalendarFeed>? _calendars;
  Object? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  ScaffoldMessengerState get _messenger => ScaffoldMessenger.of(context);

  Future<void> _load() async {
    try {
      final panel = await Api.panel();
      final calendars = panel.state == PanelState.mine ? await Api.calendars() : null;
      if (mounted) setState(() { _panel = panel; _calendars = calendars; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  /// One text field in a dialog; null when cancelled or left empty.
  Future<String?> _ask(String title, String ok,
      {String? hint, String? help, String initial = '', TextInputType? type, int? maxLength}) async {
    final c = TextEditingController(text: initial);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: type,
          maxLength: maxLength,
          textDirection: type == TextInputType.url ? TextDirection.ltr : null,
          decoration: InputDecoration(hintText: hint, helperText: help, helperMaxLines: 3),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('ביטול'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: Text(ok)),
        ],
      ),
    );
    return v == null || v.trim().isEmpty ? null : v.trim();
  }

  Future<bool> _confirm(String title, String body, String ok) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t('ביטול'))),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(ok)),
          ],
        ),
      ) ==
      true;

  Future<void> _link() async {
    final code = await _ask(t('חיבור המסך'), t('חיבור'), hint: t('הקוד שעל המסך'), type: TextInputType.number);
    if (code == null) return;
    try {
      await Api.linkPanel(code);
      _messenger.showSnackBar(SnackBar(content: Text(t('המסך מחובר. בלחיצה הבאה הוא יציג את הספר.'))));
      await _load();
    } catch (e) {
      showError(_messenger, e, t('המסך לא חובר'));
    }
  }

  Future<void> _unlink() async {
    if (!await _confirm(t('לנתק את המסך?'),
        t('עד שיחובר שוב, המסך יציג רק קוד חיבור. היומנים נשמרים אם תחברו אותו שוב לספר הזה.'), t('ניתוק'))) {
      return;
    }
    try {
      await Api.unlinkPanel();
      await _load();
    } catch (e) {
      showError(_messenger, e, t('המסך לא נותק'));
    }
  }

  Future<void> _style({String? font, String? scale}) async {
    setState(() => _busy = true);
    try {
      final p = await Api.setPanelStyle(font: font, scale: scale);
      if (mounted) setState(() => _panel = p);
      _messenger.showSnackBar(SnackBar(content: Text(t('התצוגה עודכנה. היא תופיע בלחיצה הבאה על כפתור במסך.'))));
    } catch (e) {
      showError(_messenger, e, t('התצוגה לא עודכנה'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showIdle() async {
    try {
      await Api.showIdle();
      await _load();
    } catch (e) {
      showError(_messenger, e, t('מסך המנוחה לא הוזמן'));
    }
  }

  Future<void> _addCalendar() async {
    final url = await _ask(t('הוספת יומן'), t('הבא'),
        hint: t('כתובת ICS (https://… או webcal://…)'),
        help: t('ביומן Google: הגדרות היומן ← "כתובת סודית בפורמט iCal".'),
        type: TextInputType.url);
    if (url == null || !mounted) return;
    final name = await _ask(t('שם היומן'), t('הוספה'), hint: t('שם קצר, למשל: עבודה'), maxLength: 40) ?? '';
    setState(() => _busy = true);
    try {
      final upcoming = await Api.addCalendar(url, name);
      _messenger.showSnackBar(SnackBar(content: Text(t('היומן נוסף: {0} אירועים בחודש הקרוב', [upcoming]))));
      final list = await Api.calendars();
      if (mounted) setState(() => _calendars = list);
    } catch (e) {
      showError(_messenger, e, t('היומן לא נוסף'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rename(CalendarFeed c) async {
    final name = await _ask(t('שם היומן'), t('שמירה'), initial: c.name, maxLength: 40);
    if (name == null || name == c.name) return;
    try {
      await Api.renameCalendar(c.index, name);
      await _load();
    } catch (e) {
      showError(_messenger, e, t('השם לא נשמר'));
    }
  }

  Future<void> _remove(CalendarFeed c) async {
    if (!await _confirm(t('להסיר את „{0}”?', [c.name]), t('היומן עצמו לא נמחק, הוא רק לא יופיע במסך.'), t('הסרה'))) {
      return;
    }
    try {
      await Api.deleteCalendar(c.index);
      await _load(); // indexes shift after a removal
    } catch (e) {
      showError(_messenger, e, t('היומן לא הוסר'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final panel = _panel;
    final muted = TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant);
    Widget note(String text) =>
        Padding(padding: const EdgeInsets.all(16), child: Text(text, style: muted));
    return Scaffold(
      appBar: AppBar(title: Text(t('המסך'))),
      body: _error != null && panel == null
          ? Center(child: LoadError(_error!, retry: _load))
          : panel == null
              ? const SkeletonList(rows: 3)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(children: [
                    if (panel.state == PanelState.mine) ...[
                      note(t('המסך מחובר לספר הזה. היומנים מופיעים במסך המנוחה שלו.')),
                      ListTile(
                        leading: Icon(_batteryIcon(panel.batteryPct)),
                        title: Text(panel.batteryPct == null
                            ? t('סוללה: עוד לא דווחה')
                            : t('סוללה: {0}%', [panel.batteryPct])),
                        subtitle: Text([
                          if (panel.chargedAt case final c?) t('נטען לאחרונה ב-{0}', [_day(c)]),
                          switch ((panel.daysLeft, panel.emptyAt)) {
                            (final d?, final e?) => t('לטעון בעוד כ-{0} ימים (בסביבות {1})', [d.round(), _day(e)]),
                            _ => t('עוד אין מספיק קריאות כדי להעריך מתי לטעון'),
                          },
                          if (panel.lastSeen case final l?) t('התעורר לאחרונה ב-{0}', [_when(l)]),
                        ].join('\n')),
                        isThreeLine: true,
                      ),
                      ListTile(
                        leading: const Icon(Icons.font_download_outlined),
                        title: Text(t('גופן')),
                        trailing: DropdownButton<String>(
                          value: panel.fonts.any((f) => f.key == panel.font) ? panel.font : null,
                          items: [
                            for (final f in panel.fonts) DropdownMenuItem(value: f.key, child: Text(f.label)),
                          ],
                          onChanged: _busy ? null : (v) => _style(font: v),
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.format_size),
                        title: Text(t('גודל הטקסט במסך')),
                        trailing: DropdownButton<String>(
                          value: panel.scales.any((f) => f.key == panel.scale) ? panel.scale : null,
                          items: [
                            for (final f in panel.scales) DropdownMenuItem(value: f.key, child: Text(f.label)),
                          ],
                          onChanged: _busy ? null : (v) => _style(scale: v),
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.event_note_outlined),
                        title: Text(t('להציג את מסך המנוחה')),
                        subtitle: Text(panel.idleQueued
                            ? t('יוצג כשהמסך יתעורר בפעם הבאה')
                            : t('השעה, היומנים ומזג האוויר, במקום המתכון')),
                        onTap: panel.idleQueued ? null : _showIdle,
                      ),
                      const Divider(),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(t('יומנים'), style: Theme.of(context).textTheme.titleMedium),
                      ),
                      for (final c in _calendars ?? <CalendarFeed>[])
                        ListTile(
                          leading: const Icon(Icons.calendar_month_outlined),
                          title: Text(c.name),
                          subtitle: Text(switch (c.upcoming) {
                            null => c.error.isEmpty ? t('לא הצלחתי לקרוא את היומן') : c.error,
                            0 => t('אין אירועים בחודש הקרוב · {0}', [c.host]),
                            final n => t('{0} אירועים בחודש הקרוב · {1}', [n, c.host]),
                          }),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(
                                tooltip: t('שינוי שם {0}', [c.name]),
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _rename(c)),
                            IconButton(
                                tooltip: t('הסרת {0}', [c.name]),
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _remove(c)),
                          ]),
                        ),
                      if (_calendars?.isEmpty ?? false) note(t('עוד אין יומנים.')),
                      ListTile(
                        leading: _busy
                            ? const SizedBox.square(
                                dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.add),
                        title: Text(t('הוספת יומן')),
                        onTap: _busy ? null : _addCalendar,
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.link_off),
                          label: Text(t('ניתוק המסך מהספר')),
                          onPressed: _unlink,
                        ),
                      ),
                    ] else ...[
                      note(panel.state == PanelState.taken
                          ? t('המסך מחובר כרגע לספר אחר. כדי לחבר אותו לכאן, לוחצים על הכפתור הראשון במסך 8 שניות: הוא עובר למצב חיבור.')
                          : t('המסך במצב חיבור: הוא מציג קוד QR וקוד בן 6 ספרות, שתקפים לחצי שעה. סורקים את הקוד במצלמה, או מקלידים את המספר כאן. מסך מחובר עובר למצב חיבור בלחיצה של 8 שניות על הכפתור הראשון.')),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: FilledButton.icon(
                          icon: const Icon(Icons.link),
                          label: Text(t('חיבור מסך עם קוד')),
                          onPressed: _link,
                        ),
                      ),
                    ],
                  ]),
                ),
    );
  }
}

IconData _batteryIcon(int? pct) => switch (pct) {
      null => Icons.battery_unknown_outlined,
      < 15 => Icons.battery_alert,
      < 40 => Icons.battery_2_bar,
      < 75 => Icons.battery_4_bar,
      _ => Icons.battery_full,
    };

String _day(DateTime d) => '${d.day}/${d.month}';
String _when(DateTime d) => '${_day(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
