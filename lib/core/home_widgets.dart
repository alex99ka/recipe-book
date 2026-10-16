import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

/// Android home screen widgets (android/.../HomeWidgets.kt): the newest
/// recipes, and a "מתכון חדש" button. While the app runs it keeps the list fresh.
const _package = 'com.alex99ka.recipes';
const widgets = {'SummaryWidget': 'נוספו לאחרונה', 'QuickAddWidget': 'מתכון חדש'};

bool get homeWidgetsSupported =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

String? _last;

/// Cheap to call on every rebuild: writes only when the data changed.
void updateHomeWidgets(List<String> newest) {
  if (!homeWidgetsSupported) return;
  final data = jsonEncode({'titles': newest.take(3).toList()});
  if (data == _last) return;
  _last = data;
  () async {
    try {
      await HomeWidget.saveWidgetData('summary', data);
      await HomeWidget.updateWidget(
          qualifiedAndroidName: '$_package.SummaryWidget');
    } catch (_) {} // the widget keeps its last data
  }();
}

/// Taps on a widget open the app with `recipebook://<action>`; [onAction] gets
/// the action ("add", "open"), also when the tap is what launched the app.
StreamSubscription<Uri?>? listenWidgetTaps(void Function(String action) onAction) {
  if (!homeWidgetsSupported) return null;
  HomeWidget.initiallyLaunchedFromHomeWidget().then((uri) {
    if (uri != null) onAction(uri.host);
  });
  return HomeWidget.widgetClicked.listen((uri) {
    if (uri != null) onAction(uri.host);
  });
}

/// Settings › "הוספת וידג׳ט": the launcher's own pin dialog, or how to add
/// it by hand where the launcher can't.
Future<void> pinHomeWidget(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final name = await showModalBottomSheet<String>(
    context: context,
    builder: (c) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        for (final e in widgets.entries)
          ListTile(title: Text(e.value), onTap: () => Navigator.pop(c, e.key)),
      ]),
    ),
  );
  if (name == null) return;
  try {
    if (await HomeWidget.isRequestPinWidgetSupported() == true) {
      await HomeWidget.requestPinWidget(qualifiedAndroidName: '$_package.$name');
      return;
    }
  } catch (_) {}
  messenger.showSnackBar(const SnackBar(
      content: Text('לחיצה ארוכה על מסך הבית › וידג׳טים › בוחרים את האפליקציה')));
}
