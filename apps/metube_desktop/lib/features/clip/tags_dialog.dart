import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../data/library_data.dart';
import '../../shell/shell_metrics.dart';
import '../../shell/ember_dialog.dart';

/// One clip's tags: every tag in the library to tick or untick, and a
/// field for a new one. Each change is written at once, as on the phone,
/// so closing the dialog any way keeps it. **A name still in the field
/// counts too**: Done, and the button beside the field, add it; typed and
/// closed without Enter, it used to vanish, which read as "tags are never
/// made".
Future<void> showTagsDialog(BuildContext context, String canonicalUrl) =>
    showTagsDialogFor(context, [canonicalUrl]);

/// The same for several clips at once: a tag some of them carry shows a
/// dash, and ticking it gives it to them all.
Future<void> showTagsDialogFor(BuildContext context, List<String> urls) =>
    showEmberDialog<void>(context: context, builder: (_) => _TagsDialog(urls));

class _TagsDialog extends ConsumerStatefulWidget {
  const _TagsDialog(this.urls);

  final List<String> urls;

  @override
  ConsumerState<_TagsDialog> createState() => _TagsDialogState();
}

class _TagsDialogState extends ConsumerState<_TagsDialog> {
  final _field = TextEditingController();
  List<String> _all = const [];

  /// How many of the clips carry each tag.
  Map<String, int> _carried = const {};

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
    final carried = <String, int>{};
    for (final url in widget.urls) {
      for (final tag in await _index.tagsOf(url)) {
        carried[tag] = (carried[tag] ?? 0) + 1;
      }
    }
    if (!mounted) return;
    setState(() {
      // The favourites mark is a tag underneath, but it has its own heart.
      _all =
          counts.keys.where((t) => t != MTConstants.favoritesSystemTag).toList()
            ..sort();
      _carried = carried;
    });
  }

  /// True when every clip carries [tag], false for none, null for some.
  bool? _state(String tag) {
    final n = _carried[tag] ?? 0;
    return n == 0 ? false : (n >= widget.urls.length ? true : null);
  }

  /// All carry it: it comes off them all. Otherwise all get it.
  Future<void> _toggle(String tag) async {
    final give = _state(tag) != true;
    for (final url in widget.urls) {
      final has = (await _index.tagsOf(url)).contains(tag);
      if (has != give) await _index.toggleTag(url, tag);
    }
    ref.invalidate(libraryItemsProvider);
    await _load();
  }

  /// The last new name hit [MTConstants.maxTags].
  bool _full = false;

  /// False when the name was refused for the limit, so Done keeps the
  /// dialog open on the reason rather than close as if it were made.
  Future<bool> _add(String raw) async {
    final tag = raw.trim();
    if (tag.isEmpty || tag == MTConstants.favoritesSystemTag) {
      _field.clear();
      return true;
    }
    final full = !_all.contains(tag) && _all.length >= MTConstants.maxTags;
    setState(() => _full = full);
    if (full) return false;
    _field.clear();
    if (_state(tag) == true) return true;
    await _toggle(tag);
    return true;
  }

  /// What is still in the field is added before the dialog closes.
  Future<void> _done(BuildContext context) async {
    final navigator = Navigator.of(context);
    if (_field.text.trim().isNotEmpty && !await _add(_field.text)) return;
    navigator.pop();
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
              inputFormatters: [
                LengthLimitingTextInputFormatter(MTConstants.maxTagLength),
              ],
              decoration: InputDecoration(
                hintText: l.newTagHint,
                suffixIcon: IconButton(
                  tooltip: l.create,
                  icon: MTIcon(MTIcons.plus, color: p.accentInk),
                  onPressed: () => unawaited(_add(_field.text)),
                ),
              ),
              onSubmitted: (v) => unawaited(_add(v)),
            ),
            if (_full) ...[
              const SizedBox(height: MTSpace.xs),
              Text(
                l.tagLimitReached(MTConstants.maxTags),
                style: text.bodySmall?.copyWith(color: p.err),
              ),
            ],
            const SizedBox(height: MTSpace.sm),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final tag in _all)
                      CheckboxListTile(
                        dense: true,
                        tristate: true,
                        value: _state(tag),
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
          onPressed: () => unawaited(_done(context)),
          child: Text(l.done),
        ),
      ],
    );
  }
}
