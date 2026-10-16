import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/errors.dart';
import '../core/server.dart';

/// The kitchen without a connection: the last copy of the home lists and of
/// the recipes opened lately, shown when the network or the home server
/// can't be reached. Kept per book; only reading, never writing.
final offline = ValueNotifier<bool>(false);

const _recentKey = 'cache.recent';
const keepRecipes = 40;

/// No network (N1, N2) or the home server down (S1): a saved copy will do.
bool _unreachable(Object e) => const {'N1', 'N2', 'S1'}.contains(classify(e).code);

/// [fetch], keeping its answer under [key]; the kept one when unreachable.
/// [recipe]: one of the opened recipes, of which the newest [keepRecipes] stay.
Future<dynamic> cached(String key, Future<dynamic> Function() fetch, {bool recipe = false}) async {
  final prefs = await SharedPreferences.getInstance();
  final k = 'cache.${serverHeaders['X-Book'] ?? ''}.$key';
  try {
    final v = await fetch();
    offline.value = false;
    await prefs.setString(k, jsonEncode(v));
    if (recipe) await _remember(prefs, k);
    return v;
  } catch (e) {
    final saved = prefs.getString(k);
    if (saved == null || !_unreachable(e)) rethrow;
    offline.value = true;
    return jsonDecode(saved);
  }
}

Future<void> _remember(SharedPreferences prefs, String k) async {
  final recent = [k, ...?prefs.getStringList(_recentKey)?.where((x) => x != k)];
  for (final old in recent.skip(keepRecipes)) {
    await prefs.remove(old);
  }
  await prefs.setStringList(_recentKey, recent.take(keepRecipes).toList());
}

/// A strip saying what's shown is the saved copy.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
        valueListenable: offline,
        builder: (context, off, _) => !off
            ? const SizedBox.shrink()
            : Material(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(children: [
                    Icon(Icons.cloud_off, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                        child: Text('אין חיבור לשרת: מוצג מה שנשמר במכשיר.')),
                  ]),
                ),
              ),
      );
}
