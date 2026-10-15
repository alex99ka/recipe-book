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
  const RecipeTile(this.r, {super.key});
  final Summary r;

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
            context, MaterialPageRoute<void>(builder: (_) => RecipeScreen(r.id, title: r.title))),
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

/// "ספר מתכונים חדש": the title, or null when cancelled.
Future<String?> askTitle(BuildContext context, String header) async {
  final c = TextEditingController();
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
        FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('יצירה')),
      ],
    ),
  );
  return title?.trim().isEmpty ?? true ? null : title!.trim();
}
