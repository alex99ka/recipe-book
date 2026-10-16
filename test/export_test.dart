import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_book/recipes/export.dart';

void main() {
  test('CSV cells are quoted only when they must be', () {
    expect(csvCell('שקשוקה'), 'שקשוקה');
    expect(csvCell('ביצים, עגבניות'), '"ביצים, עגבניות"');
    expect(csvCell('2 כוסות\nקמח'), '"2 כוסות\nקמח"');
    expect(csvCell('אומרים "וואו"'), '"אומרים ""וואו"""');
  });
}
