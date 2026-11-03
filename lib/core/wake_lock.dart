import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'wake_lock_web_stub.dart' if (dart.library.js_interop) 'wake_lock_web.dart' as web;

const _channel = MethodChannel('app/system');

Future<void> setCookingMode(bool enabled) async {
  if (kIsWeb) {
    await web.setWebWakeLock(enabled);
  } else {
    await _channel.invokeMethod<void>('cookingMode', enabled);
  }
}
