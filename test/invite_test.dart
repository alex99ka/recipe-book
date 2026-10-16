import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_book/recipes/invite.dart';

void main() {
  test('invite links give their token', () {
    expect(inviteToken('/invite/abc-123_X'), 'abc-123_X');
    expect(inviteToken('/invite/abc/'), 'abc');
    expect(inviteToken('/'), isNull);
    expect(inviteToken('/invite/'), isNull);
    expect(inviteToken('/recipes/invite/abc'), isNull);
  });
}
