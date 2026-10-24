import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../shell/video_surface.dart';
import '../library/artwork.dart';

/// Where a clip is watched: its picture while it plays, otherwise its
/// cover, with a play button when it is not the clip playing.
class ClipStage extends ConsumerWidget {
  const ClipStage({
    super.key,
    required this.item,
    required this.cover,
    required this.isCurrent,
    required this.audioOnly,
    required this.onPlay,
  });

  final PlaylistItem item;

  /// The cover's address or path, from the library; null shows the
  /// placeholder.
  final String? cover;
  final bool isCurrent;
  final bool audioOnly;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MTThemeX.of(context).palette;
    final corner = BorderRadius.circular(MTCorners.desktop.card);
    final picture = isCurrent && !item.isAudio && !audioOnly;
    return ClipRRect(
      borderRadius: corner,
      child: ColoredBox(
        color: MTPalette.fullscreenScrim,
        child: picture
            ? ref.watch(videoSurfaceProvider).build(context)
            : LayoutBuilder(
                builder: (context, box) => Stack(
                  fit: StackFit.expand,
                  children: [
                    artworkFor(
                          ref,
                          context,
                          cover,
                          width: box.maxWidth,
                          height: box.maxHeight,
                        ) ??
                        Center(
                          child: mtCoverPlaceholder(
                            context,
                            size: MTSpace.xxl,
                            color: p.ink3,
                            audio: item.isAudio,
                          ),
                        ),
                    if (!isCurrent)
                      Center(
                        child: MTShortcutTooltip(
                          message: context.mtl.play,
                          child: Material(
                            color: p.accent,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: onPlay,
                              child: Padding(
                                padding: const EdgeInsets.all(MTSpace.lg),
                                child: MTIcon(
                                  MTIcons.play,
                                  size: MTSpace.xxl,
                                  color: p.onAccent,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}
