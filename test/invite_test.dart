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

  test("a kitchen screen's QR gives its 6-digit code", () {
    expect(panelCode('/panel/042517'), '042517');
    expect(panelCode('/panel/042517/'), '042517');
    expect(panelCode('/panel/04251'), isNull);
    expect(panelCode('/panel/0425178'), isNull);
    expect(panelCode('/invite/042517'), isNull);
  });
}
