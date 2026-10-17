import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../core/errors.dart';
import 'api.dart';
import '../core/i18n.dart';

/// A friend's invite link (`…/invite/TOKEN`) that opened the app, waiting to
/// be accepted once someone is signed in.
final pendingInvite = ValueNotifier<String?>(null);

String? inviteToken(String path) => RegExp(r'^/invite/([^/?#]+)').firstMatch(path)?.group(1);

/// Before runApp: the link that started the app (on the web, the page's own
/// address), and any link that arrives while it runs (an Android App Link).
void listenForInvites() {
  pendingInvite.value =
      inviteToken(kIsWeb ? Uri.base.path : PlatformDispatcher.instance.defaultRouteName);
  WidgetsBinding.instance.addObserver(_Links());
}

class _Links with WidgetsBindingObserver {
  @override
  Future<bool> didPushRouteInformation(RouteInformation info) async {
    final token = inviteToken(info.uri.path);
    if (token == null) return false;
    pendingInvite.value = token;
    return true; // handled: the app has no named routes for it
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
