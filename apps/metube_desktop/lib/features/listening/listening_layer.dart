import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../di.dart';
import '../../shell/focus_regions.dart';
import '../clip/clip_state.dart';
import 'listening_room.dart';

/// Lays the listening room over [child] while sound plays and the room is
/// asked for ([full], or its button), and dims the player [bar] beneath it.
/// Everything under the room keeps its state, out of reach of the mouse,
/// the keyboard and a screen reader until the room closes.
class ListeningLayer extends ConsumerStatefulWidget {
  const ListeningLayer({
    super.key,
    required this.full,
    required this.onClose,
    required this.child,
    required this.bar,
  });

  /// The window fills the screen: for sound, the room is what fills it.
  final bool full;
  final VoidCallback onClose;
  final Widget child;
  final Widget bar;

  @override
  ConsumerState<ListeningLayer> createState() => _ListeningLayerState();
}

class _ListeningLayerState extends ConsumerState<ListeningLayer> {
  late final MTPlayer _player = ref.read(playerProvider);

  /// Only a change of clip matters here, not every pause or seek.
  late final Stream<PlaylistItem?> _currents = _player.states
      .map((s) => s.current)
      .distinct();
  var _open = false;

  void _settle(bool open, bool sound) {
    final was = _open;
    _open = open;
    // The room closed under the keyboard: it goes back to the page.
    if (was && !open) focusFirstIn(ref.read(contentFocusProvider));
    // Asked for, then the sound ended or became a picture: the room is
    // not left waiting to jump up at the next sound.
    if (!sound && ref.read(listeningProvider)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(listeningProvider.notifier).state = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final asked = widget.full || ref.watch(listeningProvider);
    final audioOnly = ref.watch(audioOnlyProvider);
    final fade = mtMotionDuration(context, MTMotion.medium);
    return StreamBuilder<PlaylistItem?>(
      stream: _currents,
      initialData: _player.state.current,
      builder: (context, snap) {
        final item = snap.data;
        final sound = playsAsSound(item, audioOnly: audioOnly);
        final open = sound && asked;
        _settle(open, sound);
        return Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ExcludeFocus(
                    excluding: open,
                    child: ExcludeSemantics(
                      excluding: open,
                      child: IgnorePointer(
                        ignoring: open,
                        child: AnimatedOpacity(
                          opacity: open ? 0 : 1,
                          duration: fade,
                          child: widget.child,
                        ),
                      ),
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: fade,
                    child: open
                        ? inRegion(
                            EmberRegion.content,
                            ListeningRoom(
                              key: ValueKey(item!.canonicalUrl),
                              item: item,
                              onClose: widget.onClose,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            // A picture in full screen has its own controls over it (see
            // ClipVideoControls); the bar would only cut the picture short.
            if (!widget.full || open) _Dimmed(dim: open, child: widget.bar),
          ],
        );
      },
    );
  }
}

/// The player bar faint under the room, back in full under the mouse or
/// the keyboard.
class _Dimmed extends StatefulWidget {
  const _Dimmed({required this.dim, required this.child});

  final bool dim;
  final Widget child;

  @override
  State<_Dimmed> createState() => _DimmedState();
}

class _DimmedState extends State<_Dimmed> {
  /// How much of the bar shows while it waits.
  static const _faint = 0.35;

  var _hovered = false;
  var _focused = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hovered = true),
    onExit: (_) => setState(() => _hovered = false),
    child: Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (on) => setState(() => _focused = on),
      child: AnimatedOpacity(
        opacity: widget.dim && !_hovered && !_focused ? _faint : 1,
        duration: mtMotionDuration(context, MTMotion.medium),
        child: widget.child,
      ),
    ),
  );
}
