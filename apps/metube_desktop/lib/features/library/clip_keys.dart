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

/// Answers [ClipKeys] while focus is on a clip inside [child]. Letters go
/// by the key's place, so F and R work with an Arabic layout too.
class ClipKeyArea extends ConsumerWidget {
  const ClipKeyArea({super.key, required this.item, required this.child});

  final LibraryItem item;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Focus(
    canRequestFocus: false,
    skipTraversal: true,
    onKeyEvent: (_, event) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;
      final keys = HardwareKeyboard.instance;
      final control = keys.isControlPressed;
      final shift = keys.isShiftPressed;
      if (keys.isAltPressed || keys.isMetaPressed) {
        return KeyEventResult.ignored;
      }
      final url = item.canonicalUrl;
      final enter =
          event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter;
      final Future<void> Function()? run = switch (event.physicalKey) {
        _ when enter && shift && !control => () => playNextOf(
          context,
          ref,
          item,
        ),
        PhysicalKeyboardKey.keyR when control && !shift =>
          () async => openReadingOf(context, url),
        PhysicalKeyboardKey.keyF when !control && !shift =>
          () => ref.read(clipActionsProvider).toggleFavorite(url),
        PhysicalKeyboardKey.keyC when control && !shift => () => copyLinkOf(
          context,
          url,
        ),
        _ => null,
      };
      if (run == null) return KeyEventResult.ignored;
      unawaited(run());
      return KeyEventResult.handled;
    },
    child: child,
  );
}
