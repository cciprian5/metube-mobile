import 'package:flutter/material.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

import 'now_playing.dart';
import 'seek_bar.dart';
import 'shell_metrics.dart';

/// The player bar, fixed at the foot of the window and never hidden, so
/// sound and its controls survive every move around the app. With nothing
/// queued the controls stay in place, dimmed.
class EmberPlayerBar extends StatelessWidget {
  const EmberPlayerBar({
    super.key,
    required this.player,
    required this.onShowQueue,
    required this.onOpen,
    required this.onMini,
  });

  final MTPlayer player;
  final VoidCallback onShowQueue;

  /// Opens the playing clip's page, from a click on its title.
  final ValueChanged<String> onOpen;

  /// Turns the window into the small card above the others.
  final VoidCallback onMini;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    return Container(
      height: EmberShellSize.playerBar,
      decoration: BoxDecoration(
        color: p.bg,
        border: Border(top: BorderSide(color: p.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: MTSpace.xl),
      child: StreamBuilder<MTPlayerState>(
        stream: player.states,
        initialData: player.state,
        builder: (context, snap) {
          final state = snap.data ?? player.state;
          return Row(
            children: [
              Expanded(
                child: EmberNowPlaying(state: state, onOpen: onOpen),
              ),
              Expanded(
                flex: 2,
                child: _Transport(player: player, state: state),
              ),
              Expanded(
                child: _Extras(
                  player: player,
                  state: state,
                  onShowQueue: onShowQueue,
                  onMini: onMini,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The transport and the seek bar. **They never mirror** in Arabic: play
/// controls keep the direction of time (brief §4, 2026-09-02).
class _Transport extends StatelessWidget {
  const _Transport({required this.player, required this.state});

  final MTPlayer player;
  final MTPlayerState state;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final l = context.mtl;
    final live = !state.isEmpty;
    VoidCallback? when(VoidCallback f) => live ? f : null;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Control(
                icon: MTIcons.shuffle,
                label: l.shuffle,
                selected: state.shuffle,
                onTap: when(() => player.setShuffle(!state.shuffle)),
              ),
              _Control(
                icon: MTIcons.prev,
                label: l.previous,
                onTap: when(player.skipToPrevious),
              ),
              const SizedBox(width: MTSpace.xs),
              _PlayButton(
                playing: state.playing,
                label: state.playing ? l.pause : l.play,
                onTap: when(state.playing ? player.pause : player.play),
                accent: p.accent,
                ink: p.onAccent,
              ),
              const SizedBox(width: MTSpace.xs),
              _Control(
                icon: MTIcons.next,
                label: l.next,
                onTap: when(player.skipToNext),
              ),
              _Control(
                icon: MTIcons.repeat,
                label: mtPlayModeLabel(context, state.mode),
                selected: state.mode != PlayMode.autoNext,
                onTap: when(() => player.setPlayMode(nextPlayMode(state.mode))),
              ),
            ],
          ),
          EmberSeekBar(player: player, duration: state.duration),
        ],
      ),
    );
  }
}

class _Extras extends StatelessWidget {
  const _Extras({
    required this.player,
    required this.state,
    required this.onShowQueue,
    required this.onMini,
  });

  final MTPlayer player;
  final MTPlayerState state;
  final VoidCallback onShowQueue;
  final VoidCallback onMini;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final l = context.mtl;
    final speeds = PlaybackSpeeds.options;
    final at = speeds.indexOf(state.speed);
    final nextSpeed = speeds[(at + 1) % speeds.length];
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        MTShortcutTooltip(
          message: l.playbackSpeed,
          child: TextButton(
            onPressed: state.isEmpty ? null : () => player.setSpeed(nextSpeed),
            child: Text(
              mtLtrRun('${state.speed}×'),
              style: Theme.of(context).textTheme.labelMedium?.tabular
                  .copyWith(color: p.ink2),
            ),
          ),
        ),
        _Control(
          icon: MTIcons.pip,
          label: l.desktopMiniWindow,
          shortcut: 'Ctrl M',
          onTap: state.isEmpty ? null : onMini,
        ),
        _Control(icon: MTIcons.queue, label: l.queueLabel, onTap: onShowQueue),
      ],
    );
  }
}

class _Control extends StatelessWidget {
  const _Control({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.shortcut,
  });

  final MTIconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final String? shortcut;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final ink = onTap == null ? p.ink3 : (selected ? p.accentInk : p.ink2);
    return MTShortcutTooltip(
      message: label,
      shortcut: shortcut,
      child: IconButton(
        onPressed: onTap,
        icon: MTIcon(icon, size: MTSpace.lg, color: ink, semanticLabel: label),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.playing,
    required this.label,
    required this.onTap,
    required this.accent,
    required this.ink,
  });

  final bool playing;
  final String label;
  final VoidCallback? onTap;
  final Color accent;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    return MTShortcutTooltip(
      message: label,
      shortcut: 'Space',
      child: Material(
        color: onTap == null ? p.cardAlt : accent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MTCorners.desktop.fab),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          // Not the theme's opaque hover fill, which would hide the ember.
          hoverColor: ink.withValues(alpha: 0.12),
          child: SizedBox.square(
            dimension: MTDensity.desktop.row,
            child: Center(
              child: MTIcon(
                playing ? MTIcons.pause : MTIcons.playFill,
                size: MTSpace.lg,
                color: onTap == null ? p.ink3 : ink,
                semanticLabel: label,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The repeat button's next mode, and R's: round the four in order.
PlayMode nextPlayMode(PlayMode mode) =>
    PlayMode.values[(mode.index + 1) % PlayMode.values.length];
