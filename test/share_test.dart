import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_book/core/share_in.dart';

void main() {
  test('the link inside shared text', () {
    expect(firstUrl('תראו את זה https://vt.tiktok.com/ZS123/ מעולה'), 'https://vt.tiktok.com/ZS123/');
    expect(firstUrl('https://example.com/r?a=1'), 'https://example.com/r?a=1');
    expect(firstUrl('רק טקסט של מתכון'), isNull);
    expect(firstUrl(null), isNull);
  });
}
