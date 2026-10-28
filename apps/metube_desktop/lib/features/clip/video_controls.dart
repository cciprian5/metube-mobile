import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../di.dart';
import '../../shell/player_controls.dart';
import '../../shell/seek_bar.dart';
import '../../shell/shell_state.dart';
import '../../shell/volume_slider.dart';
import 'clip_state.dart';

/// The controls over a playing picture: the seek bar with its times, the
/// speed, theater and full screen. They show while the pointer moves over
/// the picture and fade a moment after it rests, the pointer with them,
/// so nothing covers what is watched; paused, they stay.
///
/// The player bar keeps every one of these too: this is the same player
/// within reach of the picture. **In full screen the bar is gone** and
/// these take its place: previous, play, next and the volume join them,
/// so a clip that ends goes on to the next in full screen and can still be
/// stepped through, paused or turned down without leaving it.
class ClipVideoControls extends ConsumerStatefulWidget {
  const ClipVideoControls({
    super.key,
    required this.short,
    required this.child,
  });

  /// A short in its lane: no theater, which is for the 16:9 stage.
  final bool short;

  /// The picture.
  final Widget child;

  /// How long the pointer rests before the controls fade.
  static const linger = Duration(milliseconds: 2500);

  @override
  ConsumerState<ClipVideoControls> createState() => _ClipVideoControlsState();
}

class _ClipVideoControlsState extends ConsumerState<ClipVideoControls> {
  late final MTPlayer _player = ref.read(playerProvider);
  bool _awake = false;
  Timer? _rest;

  @override
  void dispose() {
    _rest?.cancel();
    super.dispose();
  }

  void _wake() {
    _rest?.cancel();
    _rest = Timer(ClipVideoControls.linger, _sleep);
    if (!_awake) setState(() => _awake = true);
  }

  void _sleep() {
    _rest?.cancel();
    if (mounted && _awake) setState(() => _awake = false);
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<MTPlayerState>(
    stream: _player.states,
    initialData: _player.state,
    builder: (context, snap) {
      final state = snap.data ?? _player.state;
      final shown = _awake || !state.playing;
      return MouseRegion(
        onEnter: (_) => _wake(),
        onHover: (_) => _wake(),
        onExit: (_) => _sleep(),
        cursor: shown ? MouseCursor.defer : SystemMouseCursors.none,
        child: Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            Align(
              alignment: Alignment.bottomCenter,
              // Never in the focus order, shown or not: the arrows are
              // the window's (seeking, the volume, the next short), and a
              // focused seek bar here would take them too.
              child: ExcludeFocus(
                child: IgnorePointer(
                  ignoring: !shown,
                  child: AnimatedOpacity(
                    opacity: shown ? 1 : 0,
                    duration: MTMotion.fast,
                    child: _Bar(
                      player: _player,
                      state: state,
                      short: widget.short,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// The row itself, on the picture's own shade. It keeps the direction of
/// time in Arabic, as the player bar's transport does.
class _Bar extends ConsumerWidget {
  const _Bar({required this.player, required this.state, required this.short});

  final MTPlayer player;
  final MTPlayerState state;
  final bool short;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MTThemeX.of(context).palette;
    final l = context.mtl;
    final controls = ref.watch(windowControlsProvider);
    final theater = ref.watch(theaterProvider);
    final speeds = PlaybackSpeeds.options;
    final nextSpeed = speeds[(speeds.indexOf(state.speed) + 1) % speeds.length];
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, MTPalette.fullscreenScrim],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          MTSpace.md,
          MTSpace.xl,
          MTSpace.xs,
          MTSpace.xs,
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: ValueListenableBuilder<bool>(
            valueListenable: controls.fullScreen,
            builder: (context, full, _) => EmberSeekBar(
              player: player,
              duration: state.duration,
              onPicture: true,
              leading: full ? _transport(context, l) : null,
              // A narrow short's column shrinks the buttons rather than
              // spill past its edge.
              trailing: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (full) ...[
                      const EmberVolumeSlider(onPicture: true),
                      const SizedBox(width: MTSpace.xs),
                    ],
                    MTShortcutTooltip(
                      message: l.playbackSpeed,
                      child: TextButton(
                        onPressed: () => player.setSpeed(nextSpeed),
                        child: Semantics(
                          label: l.playbackSpeed,
                          value: mtLtrRun('${state.speed}×'),
                          excludeSemantics: true,
                          child: Text(
                            mtLtrRun('${state.speed}×'),
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.tabular
                                .copyWith(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                    if (!short && !full)
                      EmberPlayerControl(
                        icon: MTIcons.theater,
                        label: l.desktopTheater,
                        selected: theater,
                        ink: Colors.white,
                        color: p.accent,
                        onTap: () =>
                            ref.read(theaterProvider.notifier).state = !theater,
                      ),
                    EmberPlayerControl(
                      icon: full ? MTIcons.collapse : MTIcons.fullscreen,
                      label: full ? l.exitFullscreen : l.enterFullscreen,
                      shortcut: 'F11',
                      ink: Colors.white,
                      onTap: () => controls.setFullScreen(!full),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Previous, play and next, in full screen where the player bar is not.
  Widget _transport(BuildContext context, MTLocalizations l) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      EmberPlayerControl(
        icon: MTIcons.prev,
        label: l.previous,
        ink: Colors.white,
        onTap: player.skipToPrevious,
      ),
      EmberPlayerControl(
        icon: state.playing ? MTIcons.pause : MTIcons.playFill,
        label: state.playing ? l.pause : l.play,
        shortcut: 'Space',
        ink: Colors.white,
        onTap: state.playing ? player.pause : player.play,
      ),
      EmberPlayerControl(
        icon: MTIcons.next,
        label: l.next,
        ink: Colors.white,
        onTap: player.skipToNext,
      ),
      const SizedBox(width: MTSpace.xs),
    ],
  );
}
