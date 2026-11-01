import 'package:flutter/material.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

/// The name of a new folder, nested when typed with a slash. It is made on
/// the server by the first download saved into it.
Future<String?> askNewFolder(BuildContext context, String parent) async {
  final typed = await showMTDialog<String>(
    context: context,
    builder: (_) => NewFolderDialog(parent: parent),
  );
  final clean = ServerPath.cleanFolder(typed ?? '');
  return clean.isEmpty ? null : clean;
}

/// **The dialog owns its controller**, so it is disposed only once the
/// route is gone: disposing it when `showDialog` returns runs during the
/// closing animation, while the field is still being built.
class NewFolderDialog extends StatefulWidget {
  const NewFolderDialog({super.key, required this.parent});

  final String parent;

  @override
  State<NewFolderDialog> createState() => _NewFolderDialogState();
}

class _NewFolderDialogState extends State<NewFolderDialog> {
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
    final l10n = context.mtl;
    return AlertDialog(
      title: Text(l10n.newFolder),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(hintText: l10n.newFolderHint),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(l10n.create),
        ),
      ],
    );
  }
}

/// A line the picker must say before the list: the server refuses folders,
/// or ignores them.
class FolderNotice extends StatelessWidget {
  const FolderNotice({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    // Told by its words in the error colour alone, not a box and a bar as
    // well.
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: MTSpace.pagePad,
        vertical: MTSpace.xs,
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall!.copyWith(color: p.err),
      ),
    );
  }
}
