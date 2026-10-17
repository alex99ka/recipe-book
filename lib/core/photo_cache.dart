import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Recipe photos kept on disk (Android, Windows), so each is downloaded once.
/// A photo URL names one version of one photo (the server's v and sig), so a
/// saved file never goes stale. The web leaves this to the browser's cache:
/// the server marks photos immutable.
class CachedPhoto extends ImageProvider<CachedPhoto> {
  const CachedPhoto(this.url);
  final String url;

  @override
  Future<CachedPhoto> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(CachedPhoto key, ImageDecoderCallback decode) =>
      MultiFrameImageStreamCompleter(
        codec: _bytes(url).then(ImmutableBuffer.fromUint8List).then(decode),
        scale: 1,
      );

  @override
  bool operator ==(Object other) => other is CachedPhoto && other.url == url;

  @override
  int get hashCode => url.hashCode;
}

/// Room for thousands of thumbnails (each is tens of KB). Past it, the
/// photos not looked at for longest go first.
const photoCacheBytes = 300 * 1024 * 1024;

Future<Directory>? _dir;
Future<Directory> _photos() => _dir ??= () async {
      final d = Directory('${(await getApplicationCacheDirectory()).path}/photos');
      await d.create(recursive: true);
      trimPhotos(d, photoCacheBytes).ignore(); // once a launch, off the first frame
      return d;
    }();

Future<Uint8List> _bytes(String url) async {
  final f = File('${(await _photos()).path}/${sha1.convert(utf8.encode(url))}');
  if (await f.exists()) {
    f.setLastModified(DateTime.now()).ignore(); // recently seen: trimmed last
    return f.readAsBytes();
  }
  final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
  if (res.statusCode != 200) throw HttpException('photo ${res.statusCode}', uri: Uri.parse(url));
  // Written aside and renamed, so a crash never leaves half a photo.
  final part = File('${f.path}.part');
  await part.writeAsBytes(res.bodyBytes);
  await part.rename(f.path);
  return res.bodyBytes;
}

/// Deletes the least recently seen files until [d] is under 80% of [maxBytes].
Future<void> trimPhotos(Directory d, int maxBytes) async {
  final files = [
    for (final e in await d.list().toList())
      if (e is File) (e, await e.stat()),
  ];
  var total = files.fold<int>(0, (n, f) => n + f.$2.size);
  if (total <= maxBytes) return;
  files.sort((a, b) => a.$2.modified.compareTo(b.$2.modified));
  for (final (file, stat) in files) {
    if (total <= maxBytes * 0.8) break;
    await file.delete();
    total -= stat.size;
  }
}
