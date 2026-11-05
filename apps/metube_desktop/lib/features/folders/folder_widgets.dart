import 'package:flutter/material.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../shell/shell_metrics.dart';
import '../../shell/ember_dialog.dart';

/// The name of a new folder, nested when typed with a slash. It is made on
/// the server by the first download saved into it.
Future<String?> askNewFolder(BuildContext context, String parent) async {
  final typed = await showEmberDialog<String>(
    context: context,
    builder: (_) => _NewFolderDialog(parent: parent),
  );
  final clean = ServerPath.cleanFolder(typed ?? '');
  return clean.isEmpty ? null : clean;
}

/// The dialog owns its controller, so it is disposed only once the route
/// is gone, not while the closing animation still builds the field.
class _NewFolderDialog extends StatefulWidget {
  const _NewFolderDialog({required this.parent});

  final String parent;

  @override
  State<_NewFolderDialog> createState() => _NewFolderDialogState();
}

class _NewFolderDialogState extends State<_NewFolderDialog> {
  late final _controller = TextEditingController(
    text: widget.parent.isEmpty ? '' : '${widget.parent}/',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.mtl;
    return AlertDialog(
      title: Text(l.newFolder),
      content: SizedBox(
        width: EmberShellSize.smallDialog,
        child: TextField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(hintText: l.newFolderHint),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(l.create),
        ),
      ],
    );
  }
}

/// A help text in its own dialog.
Future<void> showFolderHelp(BuildContext context, String title, String body) =>
    showEmberDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: EmberShellSize.formDialog,
          child: SingleChildScrollView(child: Text(body)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.mtl.done),
          ),
        ],
      ),
    );

/// A line a picker must say before its list: the server refuses folders,
/// or ignores them.
class FolderNotice extends StatelessWidget {
  const FolderNotice({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: MTSpace.xs),
      padding: const EdgeInsets.all(MTSpace.sm),
      decoration: BoxDecoration(
        color: p.cardAlt,
        border: BorderDirectional(
          start: BorderSide(color: p.err, width: MTSpace.xxs),
        ),
      ),
      child: Text(text, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

/// The (?) that opens a help text: **still and grey**, found by whoever
/// wants it. It used to pulse three times in a circle of the accent as the
/// picker opened, a light that asked for attention nobody had asked for.
class FolderHelp extends StatelessWidget {
  const FolderHelp({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final mark = Directionality.of(context) == TextDirection.rtl ? '؟' : '?';
    return MTShortcutTooltip(
      message: label,
      child: Material(
        shape: CircleBorder(
          side: BorderSide(
            color: p.line2,
            width: MTThemeX.of(context).hairline,
          ),
        ),
        color: Colors.transparent,
        // A button by its name, not by the question mark it shows: the
        // tooltip says nothing to a screen reader.
        child: Semantics(
          button: true,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox.square(
              dimension: MTSpace.xl,
              child: Center(
                child: Text(
                  mark,
                  semanticsLabel: label,
                  style: text.labelMedium?.copyWith(color: p.ink2),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
