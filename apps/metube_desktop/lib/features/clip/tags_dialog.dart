import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../data/library_data.dart';
import '../../shell/shell_metrics.dart';

/// One clip's tags: every tag in the library to tick or untick, and a
/// field for a new one. Each change is written at once, as on the phone,
/// so closing the dialog any way keeps it.
Future<void> showTagsDialog(BuildContext context, String canonicalUrl) =>
    showDialog<void>(
      context: context,
      builder: (_) => _TagsDialog(canonicalUrl),
    );

class _TagsDialog extends ConsumerStatefulWidget {
  const _TagsDialog(this.canonicalUrl);

  final String canonicalUrl;

  @override
  ConsumerState<_TagsDialog> createState() => _TagsDialogState();
}

class _TagsDialogState extends ConsumerState<_TagsDialog> {
  final _field = TextEditingController();
  List<String> _all = const [];
  Set<String> _mine = const {};

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  TagsIndex get _index => ref.read(tagsIndexProvider);

  Future<void> _load() async {
    final counts = await _index.allTagsWithCounts();
    final mine = await _index.tagsOf(widget.canonicalUrl);
    if (!mounted) return;
    setState(() {
      // The favourites mark is a tag underneath, but it has its own heart.
      _all =
          counts.keys.where((t) => t != MTConstants.favoritesSystemTag).toList()
            ..sort();
      _mine = mine.toSet();
    });
  }

  Future<void> _toggle(String tag) async {
    await _index.toggleTag(widget.canonicalUrl, tag);
    ref.invalidate(libraryItemsProvider);
    await _load();
  }

  Future<void> _add(String raw) async {
    final tag = raw.trim();
    _field.clear();
    if (tag.isEmpty || tag == MTConstants.favoritesSystemTag) return;
    if (_mine.contains(tag)) return;
    await _toggle(tag);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.mtl;
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    return AlertDialog(
      title: Text(l.tags),
      content: SizedBox(
        width: EmberShellSize.smallDialog,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _field,
              autofocus: true,
              decoration: InputDecoration(hintText: l.newTagHint),
              onSubmitted: (v) => unawaited(_add(v)),
            ),
            const SizedBox(height: MTSpace.sm),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final tag in _all)
                      CheckboxListTile(
                        dense: true,
                        value: _mine.contains(tag),
                        title: Text(
                          tag,
                          style: text.bodySmall?.copyWith(color: p.ink),
                        ),
                        onChanged: (_) => unawaited(_toggle(tag)),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.done),
        ),
      ],
    );
  }
}
