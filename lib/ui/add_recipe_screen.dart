import 'package:flutter/material.dart';

import '../core/errors.dart';
import '../core/share_in.dart';
import '../recipes/api.dart';
import 'pick.dart';
import 'recipe_screen.dart';

enum _Mode { link, text, file }

/// A new recipe from a link (a site or a cooking video), pasted text, or a
/// photo or PDF of one. Opens the recipe once the server has read it.
class AddRecipeScreen extends StatefulWidget {
  const AddRecipeScreen({super.key, this.shared});

  /// Shared from another app: starts filled in with it.
  final Shared? shared;

  @override
  State<AddRecipeScreen> createState() => _AddRecipeScreenState();
}

class _AddRecipeScreenState extends State<AddRecipeScreen> {
  var _mode = _Mode.link;
  final _url = TextEditingController();
  final _text = TextEditingController();
  Picked? _source;
  Picked? _dish;
  List<Shelf> _collections = [];
  final _chosen = <int>{};
  bool _busy = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    if (widget.shared case final s?) {
      final url = firstUrl(s.text);
      if (s.bytes != null) {
        _mode = _Mode.file;
        _source = (s.bytes!, s.name ?? 'shared.jpg');
      } else if (url != null) {
        _url.text = url;
      } else {
        _mode = _Mode.text;
        _text.text = s.text ?? '';
      }
    }
    Api.collections().then((c) {
      if (mounted) setState(() => _collections = c);
    }, onError: (_) {}); // only the "also add to" list; adding works without it
    for (final c in [_url, _text]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _url.dispose();
    _text.dispose();
    super.dispose();
  }

  bool get _ready => switch (_mode) {
        _Mode.link => RegExp(r'^https?://\S+$').hasMatch(_url.text.trim()),
        _Mode.text => _text.text.trim().length > 20,
        _Mode.file => _source != null,
      };

  Future<void> _add() async {
    setState(() {
      _busy = true;
      _error = '';
    });
    final collections = _chosen.toList();
    try {
      final id = switch (_mode) {
        _Mode.file => await Api.uploadRecipe(_source!, _dish, collections),
        _Mode.link => await Api.createRecipe(url: _url.text.trim(), collections: collections),
        _Mode.text => await Api.createRecipe(text: _text.text.trim(), collections: collections),
      };
      if (!mounted) return;
      Navigator.pushReplacement(
          context, MaterialPageRoute<void>(builder: (_) => RecipeScreen(id)));
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e, 'המתכון לא נוסף'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pick(bool source) async {
    final p = await pickPhoto(context, pdf: source);
    if (p != null && mounted) setState(() => source ? _source = p : _dish = p);
  }

  @override
  Widget build(BuildContext context) {
    final muted = TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return Scaffold(
      appBar: AppBar(title: const Text('מתכון חדש')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        SegmentedButton<_Mode>(
          segments: const [
            ButtonSegment(value: _Mode.link, label: Text('קישור')),
            ButtonSegment(value: _Mode.text, label: Text('טקסט')),
            ButtonSegment(value: _Mode.file, label: Text('צילום או PDF')),
          ],
          selected: {_mode},
          onSelectionChanged: _busy ? null : (s) => setState(() => _mode = s.first),
        ),
        const SizedBox(height: 16),
        ...switch (_mode) {
          _Mode.link => [
              TextField(
                controller: _url,
                enabled: !_busy,
                keyboardType: TextInputType.url,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'קישור',
                  hintText: 'https://…',
                  helperText: 'אתר מתכונים, או סרטון מטיקטוק, אינסטגרם או יוטיוב.',
                ),
              ),
            ],
          _Mode.text => [
              TextField(
                controller: _text,
                enabled: !_busy,
                minLines: 8,
                maxLines: null,
                decoration: const InputDecoration(
                  labelText: 'המתכון',
                  hintText: 'מדביקים כאן מצרכים ואופן הכנה, בכל שפה',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          _Mode.file => [
              _FileRow(
                title: 'צילום של המתכון או קובץ PDF',
                picked: _source,
                onPick: _busy ? null : () => _pick(true),
              ),
              _FileRow(
                title: 'תמונה של המנה (לא חובה)',
                picked: _dish,
                onPick: _busy ? null : () => _pick(false),
              ),
            ],
        },
        if (_collections.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('להוסיף גם לספרים', style: Theme.of(context).textTheme.titleSmall),
          for (final c in _collections)
            CheckboxListTile(
              title: Text(c.title),
              value: _chosen.contains(c.id),
              onChanged: _busy ? null : (v) => setState(() => v! ? _chosen.add(c.id!) : _chosen.remove(c.id)),
            ),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _busy || !_ready ? null : _add,
          icon: _busy
              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.add),
          label: Text(_busy ? 'קורא את המתכון…' : 'הוספה'),
        ),
        if (_busy)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('סרטון יכול לקחת עד שתי דקות. התרגום לעברית ממשיך אחר כך ברקע.',
                style: muted),
          ),
        if (_error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
      ]),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({required this.title, required this.picked, required this.onPick});
  final String title;
  final Picked? picked;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title),
        subtitle: picked == null ? null : Text(picked!.$2, textDirection: TextDirection.ltr),
        trailing: OutlinedButton(
            onPressed: onPick, child: Text(picked == null ? 'בחירה' : 'החלפה')),
      );
}
