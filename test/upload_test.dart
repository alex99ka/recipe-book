import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_book/core/server.dart';

void main() {
  test('uploads are labelled as the server expects', () {
    expect(mimeOf('IMG_1.JPG'), 'image/jpeg');
    expect(mimeOf('scaled_x.jpeg'), 'image/jpeg');
    expect(mimeOf('page.png'), 'image/png');
    expect(mimeOf('recipe.pdf'), 'application/pdf');
    expect(mimeOf('noext'), 'application/octet-stream');
  });
}
