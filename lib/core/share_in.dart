import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Something shared to the app from another one (Android only): a link or
/// text, or a photo or PDF as bytes with its file name.
typedef Shared = ({String? text, List<int>? bytes, String? name});

const _channel = MethodChannel('app/share');

bool get _android => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// Bumps when a share arrives while the app is running.
final shareArrived = ValueNotifier<int>(0);

void listenForShares() {
  if (!_android) return;
  _channel.setMethodCallHandler((call) async {
    if (call.method == 'shared') shareArrived.value++;
  });
}

/// The waiting share, once (MainActivity forgets it after this), or null.
Future<Shared?> takeShared() async {
  if (!_android) return null;
  final m = await _channel.invokeMapMethod<String, dynamic>('take');
  if (m == null) return null;
  final bytes = m['bytes'] as Uint8List?;
  final text = (m['text'] as String?)?.trim();
  if (bytes == null && (text == null || text.isEmpty)) return null;
  return (text: text, bytes: bytes, name: m['name'] as String?);
}

/// The first web address in shared text ("Look at this: https://…"), or null.
String? firstUrl(String? text) =>
    text == null ? null : RegExp(r'https?://[^\s]+').firstMatch(text)?.group(0);
