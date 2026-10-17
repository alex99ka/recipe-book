import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_book/core/photo_cache.dart';

void main() {
  test('trimming drops the least recently seen photos, down to 80%', () async {
    final d = await Directory.systemTemp.createTemp('photos');
    addTearDown(() => d.delete(recursive: true));
    final now = DateTime.now();
    for (var i = 0; i < 5; i++) {
      final f = File('${d.path}/$i')..writeAsBytesSync(List.filled(100, 0));
      f.setLastModifiedSync(now.subtract(Duration(hours: 5 - i))); // 0 is the oldest
    }
    await trimPhotos(d, 1000); // under the limit: nothing goes
    expect(d.listSync(), hasLength(5));
    await trimPhotos(d, 400); // 500 bytes > 400: down to 320 at most
    expect(d.listSync().map((f) => f.uri.pathSegments.last).toSet(), {'2', '3', '4'});
  });
}
