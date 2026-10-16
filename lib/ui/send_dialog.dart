import 'package:flutter/material.dart';

import '../core/errors.dart';
import '../recipes/api.dart';
import 'friends_screen.dart';

/// Picks a friend and a note, then [send]s a copy of a recipe or a whole
/// cookbook. True once it went; with no friends yet it offers an invite.
Future<bool> sendToFriend(
  BuildContext context, {
  required String title,
  required Future<void> Function(String uid, String note) send,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final List<Friend> friends;
  try {
    friends = await Api.friends();
  } catch (e) {
    showError(messenger, e, 'החברים לא נטענו');
    return false;
  }
  if (!context.mounted) return false;
  if (friends.isEmpty) {
    final invite = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('עוד אין לכם חברים'),
        content: const Text('מזמינים חבר בקישור, ואז אפשר לשלוח לו מתכונים וספרים.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('ביטול')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('הזמנת חבר')),
        ],
      ),
    );
    if (invite == true && context.mounted) {
      await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const FriendsScreen()));
    }
    return false;
  }
  var to = friends.first;
  final note = TextEditingController();
  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text('לשלוח את „$title”'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('החבר יקבל עותק משלו. שינויים שתעשו אחר כך לא יעברו אליו.'),
            RadioGroup<String>(
              groupValue: to.uid,
              onChanged: (v) => set(() => to = friends.firstWhere((f) => f.uid == v)),
              child: Column(children: [
                for (final f in friends) RadioListTile<String>(title: Text(f.name), value: f.uid),
              ]),
            ),
            TextField(
              controller: note,
              maxLength: 1000,
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(
                  labelText: 'הערה (לא חובה)',
                  hintText: 'למשל: נסו עם כבש',
                  helperText: 'כששולחים מתכון, ההערה פותחת שיחה ששניכם רואים בתוך המתכון',
                  helperMaxLines: 2),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ביטול')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('שליחה')),
        ],
      ),
    ),
  );
  if (go != true) return false;
  try {
    await send(to.uid, note.text.trim());
    messenger.showSnackBar(SnackBar(content: Text('נשלח ל${to.name}')));
    return true;
  } catch (e) {
    showError(messenger, e, 'השליחה נכשלה');
    return false;
  }
}
