import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_book/core/errors.dart';
import 'package:recipe_book/recipes/offline.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('offline: the last answer comes back, and says so', () async {
    expect(await cached('recipes', () async => ['a']), ['a']);
    expect(offline.value, isFalse);
    expect(await cached('recipes', () async => throw Errors.noConnection), ['a']);
    expect(offline.value, isTrue);
    expect(await cached('recipes', () async => ['b']), ['b']);
    expect(offline.value, isFalse);
  });

  test('nothing saved, or a real error: the error stands', () async {
    expect(cached('new', () async => throw Errors.noConnection), throwsA(Errors.noConnection));
    await cached('x', () async => 1);
    expect(cached('x', () async => throw const ServerException(404, '')), throwsA(isA<ServerException>()));
  });

  test('only the newest opened recipes are kept', () async {
    for (var i = 0; i < keepRecipes + 5; i++) {
      await cached('recipe.$i', () async => {'id': '$i'}, recipe: true);
    }
    final prefs = await SharedPreferences.getInstance();
    final kept = prefs.getKeys().where((k) => k.contains('.recipe.')).length;
    expect(kept, keepRecipes);
    expect(prefs.getString('cache..recipe.0'), isNull); // the oldest went first
  });
}
