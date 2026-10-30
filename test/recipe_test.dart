import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_book/recipes/api.dart';
import 'package:recipe_book/recipes/links.dart';
import 'package:recipe_book/ui/recipe_screen.dart';

void main() {
  test('stars: set, same star again is a half, half on the first clears', () {
    expect(nextRating(null, 4), 4);
    expect(nextRating(4, 4), 3.5);
    expect(nextRating(3.5, 4), 4);
    expect(nextRating(1, 1), 0.5);
    expect(nextRating(0.5, 1), null);
  });

  test('links: TikTok, Instagram, YouTube (short ones included), or a site', () {
    expect(linkKind('https://www.tiktok.com/@a/video/1'), LinkKind.tiktok);
    expect(linkKind('https://vt.tiktok.com/xyz'), LinkKind.tiktok);
    expect(linkKind('https://nottiktok.com/x'), LinkKind.web);
    expect(linkKind('https://www.instagram.com/reel/abc/'), LinkKind.instagram);
    expect(linkKind('https://youtu.be/abc'), LinkKind.youtube);
    expect(linkKind('https://m.youtube.com/watch?v=abc'), LinkKind.youtube);
    expect(linkKind(' https://example.com/soup '), LinkKind.web);
    expect(linkKind(''), isNull);
    expect(linkKind('not a link'), isNull);
    expect(linkKind('ftp://example.com'), isNull);
  });

  test('signed image paths resolve against the server origin', () {
    expect(Api.imageUrl('/api/v1/images/r1?v=2&sig=s'),
        'https://pi5-home-server-ts.tail4f470e.ts.net/api/v1/images/r1?v=2&sig=s');
    expect(Api.imageUrl(null), isNull);
  });
}
