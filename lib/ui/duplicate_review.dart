import 'package:flutter/material.dart';

import '../core/errors.dart';
import '../core/i18n.dart';
import '../recipes/api.dart';

/// Finds recipes with the same normalized displayed title in the current book.
Future<void> reviewDuplicateRecipes(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final recipes = await Api.recipes();
    if (!context.mounted) return;
    final groups = <String, List<Summary>>{};
    for (final recipe in recipes) {
      final sourceName = recipe.name.trim();
      final key = (sourceName.isEmpty ? recipe.title : sourceName)
          .toLowerCase()
          .replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (key.isNotEmpty) groups.putIfAbsent(key, () => []).add(recipe);
    }
    final duplicates = groups.values.where((group) => group.length > 1).toList();
    if (duplicates.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(t('לא נמצאו מתכונים כפולים'))));
      return;
    }

    final markedForDeletion = <String>{};
    final delete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(t('נמצאו מתכונים כפולים')),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t('בחרו את המתכונים למחיקה. מתכונים שלא סומנו יישארו בספר.')),
                const SizedBox(height: 12),
                for (final group in duplicates) ...[
                  Text(group.first.title, style: Theme.of(context).textTheme.titleSmall),
                  for (var index = 0; index < group.length; index++)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: markedForDeletion.contains(group[index].id),
                      title: Text(group[index].title),
                      subtitle: Text(t('עותק {0} · {1}', [index + 1, group[index].id])),
                      onChanged: (checked) => setDialogState(() {
                        if (checked == true) {
                          markedForDeletion.add(group[index].id);
                        } else {
                          markedForDeletion.remove(group[index].id);
                        }
                      }),
                    ),
                  const Divider(),
                ],
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(t('ביטול'))),
            FilledButton(
              onPressed: markedForDeletion.isEmpty ? null : () => Navigator.pop(dialogContext, true),
              child: Text(t('מחיקת {0} מתכונים', [markedForDeletion.length])),
            ),
          ],
        ),
      ),
    );
    if (delete != true || markedForDeletion.isEmpty) return;

    final count = markedForDeletion.length;
    for (final id in markedForDeletion) {
      await Api.deleteRecipe(id);
    }
    messenger.showSnackBar(SnackBar(content: Text(t('נמחקו {0} מתכונים כפולים', [count]))));
  } catch (error) {
    showError(messenger, error, t('בדיקת המתכונים נכשלה'));
  }
}
