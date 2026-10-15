import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_book/recipes/api.dart';
import 'package:recipe_book/ui/recipe_screen.dart';

void main() {
  test('stars: set, same star again is a half, half on the first clears', () {
    expect(nextRating(null, 4), 4);
    expect(nextRating(4, 4), 3.5);
    expect(nextRating(3.5, 4), 4);
    expect(nextRating(1, 1), 0.5);
    expect(nextRating(0.5, 1), null);
  });

  test('TikTok links, short ones included, and nothing else', () {
    expect(isTikTok('https://www.tiktok.com/@a/video/1'), isTrue);
    expect(isTikTok('https://vt.tiktok.com/xyz'), isTrue);
    expect(isTikTok('https://nottiktok.com/x'), isFalse);
    expect(isTikTok(''), isFalse);
  });

  test('signed image paths resolve against the server origin', () {
    expect(Api.imageUrl('/api/v1/images/r1?v=2&sig=s'),
        'https://pi5-home-server-ts.tail4f470e.ts.net/api/v1/images/r1?v=2&sig=s');
    expect(Api.imageUrl(null), isNull);
  });
}
