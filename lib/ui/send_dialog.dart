import 'package:flutter/material.dart';

import '../core/errors.dart';
import '../recipes/api.dart';
import 'friends_screen.dart';
import '../core/i18n.dart';

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
    showError(messenger, e, t('החברים לא נטענו'));
    return false;
  }
  if (!context.mounted) return false;
  if (friends.isEmpty) {
    final invite = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t('עוד אין לכם חברים')),
        content: Text(t('מזמינים חבר בקישור, ואז אפשר לשלוח לו מתכונים וספרים.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t('ביטול'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(t('הזמנת חבר'))),
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
        title: Text(t('לשלוח את „{0}”', [title])),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(t('החבר יקבל עותק משלו. שינויים שתעשו אחר כך לא יעברו אליו.')),
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
              decoration: InputDecoration(
                  labelText: t('הערה (לא חובה)'),
                  hintText: t('למשל: נסו עם כבש'),
                  helperText: t('כששולחים מתכון, ההערה פותחת שיחה ששניכם רואים בתוך המתכון'),
                  helperMaxLines: 2),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('ביטול'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t('שליחה'))),
        ],
      ),
    ),
  );
  if (go != true) return false;
  try {
    await send(to.uid, note.text.trim());
    messenger.showSnackBar(SnackBar(content: Text(t('נשלח ל{0}', [to.name]))));
    return true;
  } catch (e) {
    showError(messenger, e, t('השליחה נכשלה'));
    return false;
  }
}
