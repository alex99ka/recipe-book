import 'package:flutter/material.dart';

import '../core/errors.dart';
import '../recipes/api.dart';
import 'recipe_widgets.dart';
import 'skeleton.dart';

/// The kitchen's e-ink screen: link it to this book with the code it shows,
/// and pick the calendars its idle page lists.
class PanelScreen extends StatefulWidget {
  const PanelScreen({super.key});

  @override
  State<PanelScreen> createState() => _PanelScreenState();
}

class _PanelScreenState extends State<PanelScreen> {
  PanelState? _panel;
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
      final calendars = panel == PanelState.mine ? await Api.calendars() : null;
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ביטול')),
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
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('ביטול')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(ok)),
          ],
        ),
      ) ==
      true;

  Future<void> _link() async {
    final code = await _ask('חיבור המסך', 'חיבור', hint: 'הקוד שעל המסך', type: TextInputType.number);
    if (code == null) return;
    try {
      await Api.linkPanel(code);
      _messenger.showSnackBar(const SnackBar(content: Text('המסך מחובר. בלחיצה הבאה הוא יציג את הספר.')));
      await _load();
    } catch (e) {
      showError(_messenger, e, 'המסך לא חובר');
    }
  }

  Future<void> _unlink() async {
    if (!await _confirm('לנתק את המסך?',
        'עד שיחובר שוב, המסך יציג רק קוד חיבור. היומנים נשמרים אם תחברו אותו שוב לספר הזה.', 'ניתוק')) {
      return;
    }
    try {
      await Api.unlinkPanel();
      if (mounted) setState(() { _panel = PanelState.free; _calendars = null; });
    } catch (e) {
      showError(_messenger, e, 'המסך לא נותק');
    }
  }

  Future<void> _addCalendar() async {
    final url = await _ask('הוספת יומן', 'הבא',
        hint: 'כתובת ICS (https://… או webcal://…)',
        help: 'ביומן Google: הגדרות היומן ← "כתובת סודית בפורמט iCal".',
        type: TextInputType.url);
    if (url == null || !mounted) return;
    final name = await _ask('שם היומן', 'הוספה', hint: 'שם קצר, למשל: עבודה', maxLength: 40) ?? '';
    setState(() => _busy = true);
    try {
      final upcoming = await Api.addCalendar(url, name);
      _messenger.showSnackBar(SnackBar(content: Text('היומן נוסף: $upcoming אירועים בחודש הקרוב')));
      final list = await Api.calendars();
      if (mounted) setState(() => _calendars = list);
    } catch (e) {
      showError(_messenger, e, 'היומן לא נוסף');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rename(CalendarFeed c) async {
    final name = await _ask('שם היומן', 'שמירה', initial: c.name, maxLength: 40);
    if (name == null || name == c.name) return;
    try {
      await Api.renameCalendar(c.index, name);
      await _load();
    } catch (e) {
      showError(_messenger, e, 'השם לא נשמר');
    }
  }

  Future<void> _remove(CalendarFeed c) async {
    if (!await _confirm('להסיר את „${c.name}”?', 'היומן עצמו לא נמחק, הוא רק לא יופיע במסך.', 'הסרה')) {
      return;
    }
    try {
      await Api.deleteCalendar(c.index);
      await _load(); // indexes shift after a removal
    } catch (e) {
      showError(_messenger, e, 'היומן לא הוסר');
    }
  }

  @override
  Widget build(BuildContext context) {
    final panel = _panel;
    final muted = TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant);
    Widget note(String text) =>
        Padding(padding: const EdgeInsets.all(16), child: Text(text, style: muted));
    return Scaffold(
      appBar: AppBar(title: const Text('המסך')),
      body: _error != null && panel == null
          ? Center(child: LoadError(_error!, retry: _load))
          : panel == null
              ? const SkeletonList(rows: 3)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(children: [
                    if (panel == PanelState.mine) ...[
                      note('המסך מחובר לספר הזה. היומנים מופיעים במסך המנוחה שלו.'),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text('יומנים', style: Theme.of(context).textTheme.titleMedium),
                      ),
                      for (final c in _calendars ?? <CalendarFeed>[])
                        ListTile(
                          leading: const Icon(Icons.calendar_month_outlined),
                          title: Text(c.name),
                          subtitle: Text(switch (c.upcoming) {
                            null => c.error.isEmpty ? 'לא הצלחתי לקרוא את היומן' : c.error,
                            0 => 'אין אירועים בחודש הקרוב · ${c.host}',
                            final n => '$n אירועים בחודש הקרוב · ${c.host}',
                          }),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(
                                tooltip: 'שינוי שם ${c.name}',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _rename(c)),
                            IconButton(
                                tooltip: 'הסרת ${c.name}',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _remove(c)),
                          ]),
                        ),
                      if (_calendars?.isEmpty ?? false) note('עוד אין יומנים.'),
                      ListTile(
                        leading: _busy
                            ? const SizedBox.square(
                                dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.add),
                        title: const Text('הוספת יומן'),
                        onTap: _busy ? null : _addCalendar,
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.link_off),
                          label: const Text('ניתוק המסך מהספר'),
                          onPressed: _unlink,
                        ),
                      ),
                    ] else ...[
                      note(panel == PanelState.taken
                          ? 'המסך מחובר כרגע לספר אחר. מי שחיבר אותו מנתק אותו שם, ואז המסך מציג קוד.'
                          : 'לחצו על הכפתור במסך. הוא יציג קוד בן 6 ספרות, שתקף לרבע שעה.'),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: FilledButton.icon(
                          icon: const Icon(Icons.link),
                          label: const Text('חיבור מסך עם קוד'),
                          onPressed: _link,
                        ),
                      ),
                    ],
                  ]),
                ),
    );
  }
}
