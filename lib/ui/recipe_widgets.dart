import 'package:flutter/material.dart';

import '../core/errors.dart';
import '../recipes/api.dart';
import 'recipe_screen.dart';
import 'theme.dart';

/// A signed server image, or a quiet placeholder while it loads or when
/// there's none.
class NetImage extends StatelessWidget {
  const NetImage(this.path, {super.key, this.width, this.height, this.icon = Icons.restaurant});

  final String? path;
  final double? width;
  final double? height;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final url = Api.imageUrl(path);
    final blank = Container(
      width: width,
      height: height,
      color: skeletonColor(context),
      alignment: Alignment.center,
      child: Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
    if (url == null) return blank;
    return Image.network(url,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => blank,
        frameBuilder: (_, child, frame, sync) => sync || frame != null ? child : blank);
  }
}

class RecipeTile extends StatelessWidget {
  const RecipeTile(this.r, {super.key, this.onBack});
  final Summary r;

  /// After the recipe closes: it may have been edited or deleted.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: NetImage(r.image, width: 56, height: 56),
        ),
        title: Text(r.title),
        subtitle: r.tags.isEmpty ? null : Text(r.tags.join(' · ')),
        trailing: r.rating == null ? null : Text('★ ${pretty1(r.rating!)}'),
        onTap: () => Navigator.push(
                context, MaterialPageRoute<void>(builder: (_) => RecipeScreen(r.id, title: r.title)))
            .then((_) => onBack?.call()),
      );
}

/// 4.0 reads as 4, 3.5 stays 3.5.
String pretty1(double x) => x == x.roundToDouble() ? '${x.round()}' : '$x';

/// What a list says when it failed to load: what, why, what to do, the code.
class LoadError extends StatelessWidget {
  const LoadError(this.error, {super.key, required this.retry});
  final Object error;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(errorText(error, 'לא נטען'), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: retry, child: const Text('לנסות שוב')),
        ]),
      );
}

/// A cookbook's title ("ספר מתכונים חדש", or renaming one), or null when cancelled.
Future<String?> askTitle(BuildContext context, String header,
    {String initial = '', String ok = 'יצירה'}) async {
  final c = TextEditingController(text: initial);
  final title = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(header),
      content: TextField(
        controller: c,
        autofocus: true,
        maxLength: 80,
        decoration: const InputDecoration(hintText: 'למשל: ארוחות שישי'),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ביטול')),
        FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: Text(ok)),
      ],
    ),
  );
  return title?.trim().isEmpty ?? true ? null : title!.trim();
}

/// A delete that can be taken back: [hide] at once, a 5-second toast with
/// "ביטול", and [delete] on the server only when the toast goes unanswered.
/// shortcut: an app killed within those 5 seconds keeps the item; fine for comments and cookbooks.
Future<void> deleteWithUndo(
  ScaffoldMessengerState messenger, {
  required String said,
  required VoidCallback hide,
  required VoidCallback restore,
  required Future<void> Function() delete,
  required String failed,
}) async {
  hide();
  messenger.hideCurrentSnackBar();
  final closed = await messenger
      .showSnackBar(SnackBar(
        duration: const Duration(seconds: 5),
        persist: false, // with an action it would otherwise wait for a tap forever
        content: Text(said),
        action: SnackBarAction(label: 'ביטול', onPressed: () {}),
      ))
      .closed;
  if (closed == SnackBarClosedReason.action) return restore();
  try {
    await delete();
  } catch (e) {
    restore();
    showError(messenger, e, failed);
  }
}
