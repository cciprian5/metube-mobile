import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

import '../data/volume.dart';
import '../di.dart';
import '../features/shortcuts/shortcuts_sheet.dart';
import 'player_bar.dart';
import 'shell_state.dart';

/// The window's keys, each with what it does.
enum EmberKey {
  playPause,
  back,
  forward,
  up,
  down,
  repeat,
  search,
  fullScreen,
  leaveFullScreen,
  shortcuts;

  /// Plain keys, which a text field types and a focused button presses;
  /// they are left to those.
  bool get plain => this != search && this != fullScreen;

  /// Held down, only seeking and the volume go on.
  bool get repeats =>
      this == back || this == forward || this == up || this == down;
}

/// Which of the window's keys [event] is, if any. Letters go by the key's
/// place on the keyboard, so R and F work with an Arabic layout too.
EmberKey? emberKeyFor(
  KeyEvent event, {
  required bool control,
  required bool shift,
}) {
  final logical = event.logicalKey;
  final physical = event.physicalKey;
  if (control) {
    return physical == PhysicalKeyboardKey.keyF && !shift
        ? EmberKey.search
        : null;
  }
  if (shift) {
    // "?" is Shift and the slash key, "؟" on an Arabic layout.
    return physical == PhysicalKeyboardKey.slash ? EmberKey.shortcuts : null;
  }
  return switch (logical) {
    LogicalKeyboardKey.space => EmberKey.playPause,
    LogicalKeyboardKey.arrowLeft => EmberKey.back,
    LogicalKeyboardKey.arrowRight => EmberKey.forward,
    LogicalKeyboardKey.arrowUp => EmberKey.up,
    LogicalKeyboardKey.arrowDown => EmberKey.down,
    LogicalKeyboardKey.f11 => EmberKey.fullScreen,
    LogicalKeyboardKey.escape => EmberKey.leaveFullScreen,
    _ => physical == PhysicalKeyboardKey.keyR ? EmberKey.repeat : null,
  };
}

/// How far ← and → move.
const seekStep = Duration(seconds: 10);

/// **The keyboard over the whole window.** One handler ahead of the focus
/// system, as Ctrl+K's, so a key works wherever focus happens to be; and
/// it stands aside for a dialog, for typing, and for Space on a focused
/// button. Seeking, the volume and play/pause wait for a clip: with none,
/// the arrows scroll and Space presses as usual.
class EmberKeyboard extends ConsumerStatefulWidget {
  const EmberKeyboard({
    super.key,
    required this.onSearch,
    required this.inShortsLane,
    required this.child,
  });

  final VoidCallback onSearch;

  /// Whether a short is open in its lane, where ↑ and ↓ move between
  /// shorts rather than the volume.
  final bool Function() inShortsLane;
  final Widget child;

  @override
  ConsumerState<EmberKeyboard> createState() => _EmberKeyboardState();
}

class _EmberKeyboardState extends ConsumerState<EmberKeyboard> {
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
    if (event is KeyUpEvent || !mounted) return false;
    if (ModalRoute.of(context)?.isCurrent == false) return false;
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isAltPressed || keyboard.isMetaPressed) return false;
    final key = emberKeyFor(
      event,
      control: keyboard.isControlPressed,
      shift: keyboard.isShiftPressed,
    );
    if (key == null) return false;
    if (event is KeyRepeatEvent && !key.repeats) return false;
    final focused = FocusManager.instance.primaryFocus?.context;
    if (key.plain && _typing(focused)) return false;
    if (key == EmberKey.playPause && _pressable(focused)) return false;
    return _run(key);
  }

  /// A text field has the keys.
  static bool _typing(BuildContext? focused) =>
      focused != null &&
      (focused.widget is EditableText ||
          focused.findAncestorWidgetOfExactType<EditableText>() != null);

  /// A focused button takes Space for itself.
  static bool _pressable(BuildContext? focused) =>
      focused != null &&
      (Actions.maybeFind<ActivateIntent>(focused)
              ?.isEnabled(const ActivateIntent()) ??
          false);

  bool _run(EmberKey key) {
    final player = ref.read(playerProvider);
    final state = player.state;
    final loaded = state.current != null;
    final controls = ref.read(windowControlsProvider);
    switch (key) {
      case EmberKey.playPause when loaded:
        unawaited(state.playing ? player.pause() : player.play());
      case EmberKey.back when loaded:
        final to = player.position - seekStep;
        unawaited(player.seek(to.isNegative ? Duration.zero : to));
      case EmberKey.forward when loaded:
        unawaited(player.seek(player.position + seekStep));
      case EmberKey.up || EmberKey.down when widget.inShortsLane():
        unawaited(
          key == EmberKey.down ? player.skipToNext() : player.skipToPrevious(),
        );
      case EmberKey.up || EmberKey.down when loaded:
        unawaited(_nudgeVolume(key == EmberKey.up ? 1 : -1));
      case EmberKey.repeat:
        final mode = nextPlayMode(state.mode);
        unawaited(player.setPlayMode(mode));
        showMTNotice(context, message: _modeName(context.mtl, mode));
      case EmberKey.search:
        widget.onSearch();
      case EmberKey.fullScreen:
        controls.setFullScreen(!controls.fullScreen.value);
      case EmberKey.leaveFullScreen when controls.fullScreen.value:
        controls.setFullScreen(false);
      case EmberKey.shortcuts:
        unawaited(showShortcutsSheet(context));
      default:
        return false;
    }
    return true;
  }

  Future<void> _nudgeVolume(int direction) async {
    await ref.read(volumeProvider.notifier).nudge(direction);
    if (!mounted) return;
    showMTNotice(
      context,
      message: context.mtl.desktopVolumeLevel(ref.read(volumeProvider).round()),
      duration: const Duration(seconds: 1),
    );
  }

  static String _modeName(MTLocalizations l, PlayMode mode) => switch (mode) {
    PlayMode.autoNext => l.modeAutoNext,
    PlayMode.repeatAll => l.modeRepeatAll,
    PlayMode.repeatOne => l.modeRepeatOne,
    PlayMode.stopAtEnd => l.modeStopAtEnd,
  };

  @override
  Widget build(BuildContext context) => widget.child;
}
