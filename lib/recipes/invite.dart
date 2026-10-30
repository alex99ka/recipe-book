import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../core/errors.dart';
import 'api.dart';
import '../core/i18n.dart';

/// A friend's invite link (`…/invite/TOKEN`) that opened the app, waiting to
/// be accepted once someone is signed in.
final pendingInvite = ValueNotifier<String?>(null);

String? inviteToken(String path) => RegExp(r'^/invite/([^/?#]+)').firstMatch(path)?.group(1);

/// The code from the QR a kitchen screen shows in pairing mode (`…/panel/123456`).
final pendingPanelCode = ValueNotifier<String?>(null);

String? panelCode(String path) => RegExp(r'^/panel/(\d{6})(?:[/?#]|$)').firstMatch(path)?.group(1);

/// Before runApp: the link that started the app (on the web, the page's own
/// address), and any link that arrives while it runs (an Android App Link).
void listenForInvites() {
  _take(kIsWeb ? Uri.base.path : PlatformDispatcher.instance.defaultRouteName);
  WidgetsBinding.instance.addObserver(_Links());
}

bool _take(String path) {
  final token = inviteToken(path), code = panelCode(path);
  if (token != null) pendingInvite.value = token;
  if (code != null) pendingPanelCode.value = code;
  return token != null || code != null;
}

class _Links with WidgetsBindingObserver {
  // true = handled: the app has no named routes for these
  @override
  Future<bool> didPushRouteInformation(RouteInformation info) async => _take(info.uri.path);
}

/// Links the kitchen screen whose QR opened the app, if any; returns what to tell the user.
Future<String?> linkPendingPanel() async {
  final code = pendingPanelCode.value;
  if (code == null) return null;
  pendingPanelCode.value = null;
  try {
    await Api.linkPanel(code);
    return t('המסך מחובר. בלחיצה הבאה הוא יציג את הספר.');
  } catch (e) {
    return errorText(e, t('המסך לא חובר'));
  }
}

/// Accepts the waiting invite, if any; returns what to tell the user.
Future<String?> acceptPendingInvite() async {
  final token = pendingInvite.value;
  if (token == null) return null;
  pendingInvite.value = null;
  try {
    final f = await Api.acceptInvite(token);
    return t('עכשיו אתם חברים של {0}. אפשר לשלוח זה לזה מתכונים וספרים שלמים.', [f.name.isEmpty ? t('חבר חדש') : f.name]);
  } catch (e) {
    return errorText(e, t('ההזמנה לא התקבלה'));
  }
}
