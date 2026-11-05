import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';

/// How dropped links reach the app: Windows' drop target in the app, a
/// plain pass-through in tests, which have no native drag and drop.
typedef LinkDropBuilder = Widget Function(
  Widget child,
  ValueChanged<String> onText,
);

Widget _noDrop(Widget child, ValueChanged<String> onText) => child;

/// Overridden in main with the Windows drop target.
final linkDropProvider = Provider<LinkDropBuilder>((ref) => _noDrop);

/// The clipboard's text when it holds at least one link, else empty.
Future<String> clipboardLinks() async {
  try {
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
    return UrlKit.extractAllUrls(text).isEmpty ? '' : text;
  } on Object {
    return '';
  }
}

/// **Ctrl+V anywhere opens the add dialog when the clipboard holds a
/// link** — except in a text field, where it pastes as always, and while a
/// dialog is open over the window. Nothing is read from the clipboard
/// until the keys are pressed.
class AddShortcut extends StatefulWidget {
  const AddShortcut({super.key, required this.onLinks, required this.child});

  final ValueChanged<String> onLinks;
  final Widget child;

  @override
  State<AddShortcut> createState() => _AddShortcutState();
}

class _AddShortcutState extends State<AddShortcut> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.physicalKey != PhysicalKeyboardKey.keyV ||
        !HardwareKeyboard.instance.isControlPressed) {
      return false;
    }
    final focused = FocusManager.instance.primaryFocus?.context;
    final typing =
        focused != null &&
        (focused.widget is EditableText ||
            focused.findAncestorWidgetOfExactType<EditableText>() != null);
    final covered = ModalRoute.of(context)?.isCurrent == false;
    if (typing || covered) return false;
    unawaited(
      clipboardLinks().then((text) {
        if (text.isNotEmpty && mounted) widget.onLinks(text);
      }),
    );
    return true;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
