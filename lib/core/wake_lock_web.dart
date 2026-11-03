import 'dart:js_interop';
import 'package:web/web.dart' as web;

web.WakeLockSentinel? _sentinel;

Future<void> setWebWakeLock(bool enabled) async {
  if (enabled) {
    _sentinel ??= await web.window.navigator.wakeLock.request('screen').toDart;
  } else {
    final current = _sentinel;
    _sentinel = null;
    if (current != null) await current.release().toDart;
  }
}
