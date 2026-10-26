import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_transcripts/mt_transcripts.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../data/library_data.dart';
import '../../data/transcripts_data.dart';
import '../../di.dart';
import '../../shell/focus_regions.dart';
import '../../shell/shell_state.dart';
import '../library/artwork.dart';
import 'listening_lines.dart';

/// Whether the listening room was opened in the window, from its button.
/// Full screen opens it too while sound plays, without this.
final listeningProvider = StateProvider<bool>((ref) => false);

/// Opens the room in the window, or closes it wherever it is: full screen
/// too, which is the room's own while sound plays.
void toggleListening(WidgetRef ref) {
  final controls = ref.read(windowControlsProvider);
  final room = ref.read(listeningProvider.notifier);
  if (room.state || controls.fullScreen.value) {
    room.state = false;
    controls.setFullScreen(false);
  } else {
    room.state = true;
  }
}

/// Whether [item] is heard and not watched: a sound clip, or a video with
/// its picture turned off.
bool playsAsSound(PlaylistItem? item, {required bool audioOnly}) =>
    item != null && (item.isAudio || audioOnly);

/// **The listening room**: for sound left playing while the window stays
/// open. The cover large and tilted, the two embers behind it at a larger
/// scale, moving while it plays and drawing back when paused, and the
/// transcript flowing past beside it in large lines.
///
/// With animations turned off the embers stay still and the lines step
/// rather than glide.
class ListeningRoom extends ConsumerStatefulWidget {
  const ListeningRoom({super.key, required this.item, required this.onClose});

  final PlaylistItem item;
  final VoidCallback onClose;

  /// The cover's largest side.
  static const double cover = 360;

  @override
  ConsumerState<ListeningRoom> createState() => _ListeningRoomState();
}

class _ListeningRoomState extends ConsumerState<ListeningRoom> {
  /// The narrowest the lines get beside the cover; narrower, they go below.
  static const double _narrowest = 420;

  /// Below this the cover is left out: a small square says nothing.
  static const double _smallest = 120;

  /// The embers spread past the cover by this much more than on a phone.
  static const double _glowScale = 1.3;

  late final MTPlayer _player = ref.read(playerProvider);
  late final ValueNotifier<bool> _playing = ValueNotifier(
    _player.state.playing,
  );
  StreamSubscription<MTPlayerState>? _states;
  final _focus = FocusNode(debugLabel: 'listening', skipTraversal: true);

  @override
  void initState() {
    super.initState();
    _states = _player.states.listen((s) => _playing.value = s.playing);
    // The page under the room is out of reach; the keyboard comes here.
    focusFirstIn(_focus);
  }

  @override
  void dispose() {
    unawaited(_states?.cancel());
    _playing.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.mtl;
    final p = MTThemeX.of(context).palette;
    final item = widget.item;
    final segments =
        ref
            .watch(
              transcriptForProvider((
                canonicalUrl: item.canonicalUrl,
                serverFilename: item.serverFilename,
              )),
            )
            .valueOrNull
            ?.segments ??
        const <TranscriptSegment>[];
    return Focus(
      focusNode: _focus,
      child: ColoredBox(
        color: p.bg,
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(MTSpace.xxl),
                child: LayoutBuilder(
                  builder: (context, box) {
                    final cover = _CoverColumn(
                      item: item,
                      playing: _playing,
                      smallest: _smallest,
                      glowScale: _glowScale,
                    );
                    if (segments.isEmpty) return cover;
                    final lines = ListeningLines(
                      segments: segments,
                      player: _player,
                    );
                    final beside =
                        box.maxWidth >=
                        ListeningRoom.cover + 2 * MTSpace.xxl + _narrowest;
                    return beside
                        // Together in the middle: on a wide screen the lines
                        // keep a reading width rather than run to the edge.
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: ListeningRoom.cover + MTSpace.xxl,
                                child: cover,
                              ),
                              const SizedBox(width: MTSpace.xxl),
                              Flexible(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: MTBreakpoint.readable,
                                  ),
                                  child: lines,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              Expanded(flex: 5, child: cover),
                              Expanded(flex: 4, child: lines),
                            ],
                          );
                  },
                ),
              ),
            ),
            PositionedDirectional(
              top: MTSpace.md,
              end: MTSpace.md,
              child: MTShortcutTooltip(
                message: l.desktopListeningClose,
                shortcut: 'Esc',
                child: IconButton(
                  onPressed: widget.onClose,
                  icon: MTIcon(
                    MTIcons.close,
                    size: MTSpace.lg,
                    color: p.ink2,
                    semanticLabel: l.desktopListeningClose,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The tilted cover with the embers behind it, and the title beneath.
class _CoverColumn extends ConsumerWidget {
  const _CoverColumn({
    required this.item,
    required this.playing,
    required this.smallest,
    required this.glowScale,
  });

  final PlaylistItem item;
  final ValueListenable<bool> playing;
  final double smallest;
  final double glowScale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final library = ref.watch(libraryItemsProvider).valueOrNull ?? const [];
    // The library's cover first: it is the one found later, if the item
    // came without one.
    final art =
        library
            .where((i) => i.canonicalUrl == item.canonicalUrl)
            .firstOrNull
            ?.thumbnail ??
        item.artworkUrl;
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              // The frame around the cover reaches past it on every side.
              final size = math.min(
                ListeningRoom.cover,
                math.min(box.maxWidth, box.maxHeight) - MTSpace.xxl,
              );
              if (size < smallest) return const SizedBox();
              return Center(
                child: MTBreathingGlow(
                  playing: playing,
                  size: size * glowScale,
                  // Its own layer: the blurred shadow is drawn once, not on
                  // every frame the embers behind it move.
                  child: RepaintBoundary(
                    child: MTTiltedArtwork(
                      item: item,
                      size: size,
                      artwork: (context, _) => artworkFor(
                        ref,
                        context,
                        art,
                        width: size,
                        height: size,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: MTSpace.lg),
        Text(
          item.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          textDirection: mtTextDirectionOf(
            item.title,
            Directionality.of(context),
          ),
          style: text.titleLarge?.copyWith(color: p.ink),
        ),
        if (item.uploader case final who?) ...[
          const SizedBox(height: MTSpace.xxs),
          Text(
            who,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: p.ink3),
          ),
        ],
      ],
    );
  }
}
