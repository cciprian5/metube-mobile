import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_media/library.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../di.dart';
import '../../router.dart';
import '../clip/clip_actions.dart';
import 'copy_file.dart';

/// The keys of a chosen clip in a list, as the right-click menu and the
/// shortcuts sheet write them. Enter is any button's own key: it plays.
///
/// The reading room takes Ctrl, since R alone is the window's repeat key
/// wherever focus is.
abstract final class ClipKeys {
  static const play = 'Enter';
  static const playNext = 'Shift Enter';
  static const reading = 'Ctrl R';
  static const favorite = 'F';
  static const copyLink = 'Ctrl C';

  /// Shift beside the link's own key: the file, where Ctrl C is the link.
  static const copyFile = 'Ctrl Shift C';
}

/// Queues [item] after what plays, and says so: nothing on screen moves.
Future<void> playNextOf(
  BuildContext context,
  WidgetRef ref,
  LibraryItem item,
) async {
  await ref.read(playerProvider).playNext(toPlaylistItem(item));
  if (!context.mounted) return;
  showMTNotice(context, message: context.mtl.desktopPlaysNext);
}

void openReadingOf(BuildContext context, String url) =>
    GoRouter.of(context).go(EmberRoutes.reading(url));

Future<void> copyLinkOf(BuildContext context, String url) async {
  await Clipboard.setData(ClipboardData(text: url));
  if (!context.mounted) return;
  showMTNotice(context, message: context.mtl.desktopLinkCopied);
}

/// Which copy a key asks for: Ctrl C the link, Ctrl Shift C the file.
enum ClipCopy { link, file }

/// The copy [event] asks for, or null for any other key.
ClipCopy? clipCopyOf(KeyEvent event) {
  if (event is! KeyDownEvent) return null;
  final keys = HardwareKeyboard.instance;
  if (!keys.isControlPressed || keys.isAltPressed || keys.isMetaPressed) {
    return null;
  }
  if (event.physicalKey != PhysicalKeyboardKey.keyC) return null;
  return keys.isShiftPressed ? ClipCopy.file : ClipCopy.link;
}

Future<void> runClipCopy(
  BuildContext context,
  ClipCopy copy,
  LibraryItem item,
) => switch (copy) {
  ClipCopy.link => copyLinkOf(context, item.canonicalUrl),
  ClipCopy.file => copyFileOf(context, item),
};

/// Answers [ClipKeys] while focus is on a clip inside [child]. Letters go
/// by the key's place, so F and R work with an Arabic layout too.
///
/// It also notes the clip the mouse is over ([pointed]): a mouse user never
/// gives a clip focus, since a click opens it, so the copy keys fall back on
/// that clip. Only they do; F or Enter pressed in passing over a clip would
/// change the library or start playing without being meant.
class ClipKeyArea extends ConsumerStatefulWidget {
  const ClipKeyArea({super.key, required this.item, required this.child});

  final LibraryItem item;
  final Widget child;

  /// The clip under the mouse now, or null.
  static LibraryItem? get pointed {
    final over = _ClipKeyAreaState._over;
    return over != null && over.mounted ? over.widget.item : null;
  }

  @override
  ConsumerState<ClipKeyArea> createState() => _ClipKeyAreaState();
}

class _ClipKeyAreaState extends ConsumerState<ClipKeyArea> {
  /// One pointer, so one clip under it at a time.
  static _ClipKeyAreaState? _over;

  void _leave() {
    if (identical(_over, this)) _over = null;
  }

  @override
  void dispose() {
    // A list scrolled or left under a still mouse sends no exit.
    _leave();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    opaque: false,
    onEnter: (_) => _over = this,
    onExit: (_) => _leave(),
    child: Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (_, event) => _key(event),
      child: widget.child,
    ),
  );

  KeyEventResult _key(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final keys = HardwareKeyboard.instance;
    final control = keys.isControlPressed;
    final shift = keys.isShiftPressed;
    if (keys.isAltPressed || keys.isMetaPressed) {
      return KeyEventResult.ignored;
    }
    final item = widget.item;
    final url = item.canonicalUrl;
    final enter =
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter;
    final copy = clipCopyOf(event);
    final Future<void> Function()? run = switch (event.physicalKey) {
      _ when copy != null => () => runClipCopy(context, copy, item),
      _ when enter && shift && !control => () => playNextOf(context, ref, item),
      PhysicalKeyboardKey.keyR when control && !shift =>
        () async => openReadingOf(context, url),
      PhysicalKeyboardKey.keyF when !control && !shift =>
        () => ref.read(clipActionsProvider).toggleFavorite(url),
      _ => null,
    };
    if (run == null) return KeyEventResult.ignored;
    unawaited(run());
    return KeyEventResult.handled;
  }
}
