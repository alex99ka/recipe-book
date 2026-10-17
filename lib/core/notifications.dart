import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'errors.dart';
import 'server.dart';
import 'i18n.dart';

/// Pushes come from the home server (push.py), which keeps each device's
/// token and the per-type switches. Android and the web get them; Windows has
/// no FCM, so it gets none.
///
/// Keep in sync with push.TYPES on the server.
const notificationTypes = <String, String>{
  'inbox': 'כשחבר שולח לי מתכון',
  'comments': 'תגובות על מתכונים',
  'translated': 'כשמתכון חדש מוכן בעברית',
};

bool get pushSupported => kIsWeb || defaultTargetPlatform == TargetPlatform.android;

bool _listening = false;
String? _token;
// The home screen of whoever is signed in now (a new one after switching accounts).
ScaffoldMessengerState? _messenger;
void Function(Map<String, dynamic> data)? _onOpen;

Future<void> _register(String token) async {
  _token = token;
  await server('PUT', '/me/push', {'token': token});
}

/// Called each time a user is let in. [onOpen] gets a tapped notification's
/// data ({"recipe": id, "title": ...} or {"inbox": "1"}).
Future<void> setUpNotifications(
  ScaffoldMessengerState messenger, {
  required void Function(Map<String, dynamic> data) onOpen,
}) async {
  if (!pushSupported) return;
  _messenger = messenger;
  _onOpen = onOpen;
  final fcm = FirebaseMessaging.instance;
  if (!_listening) {
    _listening = true;
    fcm.onTokenRefresh.listen((t) => _register(t).ignore());
    // In the app already: the system shows nothing, so the app does.
    FirebaseMessaging.onMessage.listen((m) {
      final n = m.notification;
      if (n == null) return;
      _messenger?.showSnackBar(SnackBar(
        content: Text('${n.title}\n${n.body ?? ''}'),
        action: SnackBarAction(label: t('פתיחה'), onPressed: () => _onOpen?.call(m.data)),
      ));
    });
    if (!kIsWeb) {
      FirebaseMessaging.onMessageOpenedApp.listen((m) => _onOpen?.call(m.data));
      final first = await fcm.getInitialMessage();
      if (first != null) onOpen(first.data);
    }
  }
  if (kIsWeb) {
    // Allowed earlier from Settings: keep this browser registered.
    try {
      final s = await fcm.getNotificationSettings();
      if (s.authorizationStatus == AuthorizationStatus.authorized) {
        final t = await fcm.getToken();
        if (t != null) await _register(t);
      }
    } catch (_) {}
    return;
  }
  try {
    await fcm.requestPermission(); // Android 13+ asks once
    final t = await fcm.getToken();
    if (t != null) await _register(t);
  } catch (_) {
    // Offline: registered next launch or on token refresh.
  }
}

/// Settings › "התראות במכשיר הזה" on the web. Safari asks only straight from
/// a tap; on an iPad only in the Home Screen app (iOS 16.4+).
Future<String> enableWebNotifications() async {
  try {
    final s = await FirebaseMessaging.instance.requestPermission();
    if (s.authorizationStatus != AuthorizationStatus.authorized) {
      return errorText(Errors.notificationsBlocked);
    }
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await _register(token);
    return t('ההתראות פעילות במכשיר הזה.');
  } catch (_) {
    return errorText(Errors.notificationsNeedHomeScreen);
  }
}

/// Before signing out: this device stops getting the account's pushes.
Future<void> forgetThisDevice() async {
  final t = _token;
  if (t == null) return;
  try {
    await server('POST', '/me/push/forget', {'token': t})
        .timeout(const Duration(seconds: 5));
  } catch (_) {}
  _token = null;
}

/// The per-type switches, default on.
Future<Map<String, bool>> notificationPrefs() async =>
    Map<String, bool>.from(await server('GET', '/me/notify') as Map);

Future<Map<String, bool>> setNotificationPref(String type, bool on) async =>
    Map<String, bool>.from(await server('PATCH', '/me/notify', {type: on}) as Map);
