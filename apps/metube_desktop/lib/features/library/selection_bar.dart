import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_media/library.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../shell/error_text.dart';
import '../../shell/player_controls.dart';
import '../clip/clip_actions.dart';
import '../clip/clip_state.dart';
import '../clip/tags_dialog.dart';
import '../lists/list_dialogs.dart';
import 'selection.dart';

/// A list of clips that can be chosen from: the list, and while any is
/// chosen a bar of what can be done to them all at its foot. Esc lets
/// go of the choice and Ctrl+A takes every clip shown.
class SelectionFrame extends ConsumerStatefulWidget {
  const SelectionFrame({super.key, required this.items, required this.child});

  /// The clips as shown, in order.
  final List<LibraryItem> items;
  final Widget child;

  @override
  ConsumerState<SelectionFrame> createState() => _SelectionFrameState();
}

class _SelectionFrameState extends ConsumerState<SelectionFrame> {
  late final LibrarySelectionNotifier _selection;

  @override
  void initState() {
    super.initState();
    _selection = ref.read(librarySelectionProvider.notifier);
    HardwareKeyboard.instance.addHandler(_key);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_key);
    // A choice belongs to the list it was made in.
    Future.microtask(_selection.clear);
    super.dispose();
  }

  bool _key(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final focused = FocusManager.instance.primaryFocus?.context;
    // A text field keeps its own Esc and Ctrl+A.
    if (focused?.findAncestorWidgetOfExactType<EditableText>() != null ||
        focused?.widget is EditableText) {
      return false;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape &&
        ref.read(librarySelectionProvider).urls.isNotEmpty) {
      _selection.clear();
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyA &&
        HardwareKeyboard.instance.isControlPressed &&
        ModalRoute.of(context)?.isCurrent != false) {
      _selection.selectAll([for (final i in widget.items) i.canonicalUrl]);
      return true;
    }
    return false;
  }

  /// The choice the bar shows, kept while it leaves.
  List<LibraryItem> _shown = const [];

  @override
  Widget build(BuildContext context) {
    final chosen = ref.watch(librarySelectionProvider).urls;
    final items = [
      for (final i in widget.items)
        if (chosen.contains(i.canonicalUrl)) i,
    ];
    // The bar rises a few points as it fades in and drops back quicker as
    // it leaves, holding the last choice while it goes.
    if (items.isNotEmpty) _shown = items;
    final shown = items.isNotEmpty;
    return Stack(
      children: [
        widget.child,
        if (_shown.isNotEmpty)
          PositionedDirectional(
            start: MTSpace.xl,
            end: MTSpace.xl,
            bottom: MTSpace.lg,
            child: IgnorePointer(
              ignoring: !shown,
              child: AnimatedSlide(
                offset: shown ? Offset.zero : const Offset(0, 0.25),
                duration: mtMotionDuration(
                  context,
                  shown ? MTMotion.page : MTMotion.fast,
                ),
                curve: shown ? MTMotion.entrance : MTMotion.exit,
                child: AnimatedOpacity(
                  opacity: shown ? 1 : 0,
                  duration: mtMotionDuration(
                    context,
                    shown ? MTMotion.page : MTMotion.fast,
                  ),
                  curve: shown ? MTMotion.entrance : MTMotion.exit,
                  onEnd: () {
                    if (!shown && mounted) setState(() => _shown = const []);
                  },
                  child: Center(child: _Bar(items: _shown)),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// What can be done to every chosen clip at once.
class _Bar extends ConsumerWidget {
  const _Bar({required this.items});

  final List<LibraryItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MTThemeX.of(context).palette;
    final l = context.mtl;
    final text = Theme.of(context).textTheme;
    final selection = ref.read(librarySelectionProvider.notifier);
    final onServer = items.where((i) => i.onServer).toList();
    return Material(
      color: p.card,
      elevation: 6,
      shadowColor: p.ink.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MTCorners.desktop.card),
        side: BorderSide(color: p.line2, width: MTThemeX.of(context).hairline),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: MTSpace.md,
          vertical: MTSpace.xs,
        ),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: MTSpace.xs,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: MTSpace.sm),
              child: Text(
                l.desktopSelectedCount(items.length),
                style: text.labelLarge?.copyWith(color: p.ink),
              ),
            ),
            EmberPlayerControl(
              icon: MTIcons.play,
              label: l.play,
              onTap: () => unawaited(
                openFromList(ref, GoRouter.of(context), [
                  for (final i in items) toPlaylistItem(i),
                ], 0),
              ),
            ),
            EmberPlayerControl(
              icon: MTIcons.queue,
              label: l.addToPlaylist,
              onTap: () => unawaited(
                showAddAllToPlaylistDialog(context, [
                  for (final i in items) toPlaylistItem(i),
                ]),
              ),
            ),
            EmberPlayerControl(
              icon: MTIcons.tags,
              label: l.tags,
              onTap: () => unawaited(
                showTagsDialogFor(context, [
                  for (final i in items) i.canonicalUrl,
                ]),
              ),
            ),
            if (onServer.isNotEmpty)
              EmberPlayerControl(
                icon: MTIcons.trash,
                label: l.deleteFromServer,
                onTap: () => unawaited(_delete(context, ref, onServer)),
              ),
            EmberPlayerControl(
              icon: MTIcons.close,
              label: l.desktopClearSelection,
              shortcut: 'Esc',
              onTap: selection.clear,
            ),
          ],
        ),
      ),
    );
  }

  /// From the server, by each clip's canonical link, after asking once.
  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    List<LibraryItem> onServer,
  ) async {
    final l = context.mtl;
    final sure = await showMTConfirm(
      context,
      title: l.deleteFromServer,
      message: l.desktopDeleteSelectedConfirm(onServer.length),
      confirmLabel: l.delete,
      cancelLabel: l.cancel,
      destructive: true,
    );
    if (!sure) return;
    final actions = ref.read(clipActionsProvider);
    try {
      for (final item in onServer) {
        await actions.deleteFromServer(item.canonicalUrl);
      }
    } on Object catch (e) {
      // Those deleted before the refusal are gone; the rest stay chosen.
      if (context.mounted) {
        showMTNotice(
          context,
          message: errorText(l, e),
          kind: MTNoticeKind.failed,
        );
      }
      return;
    }
    ref.read(librarySelectionProvider.notifier).clear();
    if (context.mounted) {
      showMTNotice(context, message: l.deletedFromServer);
    }
  }
}
