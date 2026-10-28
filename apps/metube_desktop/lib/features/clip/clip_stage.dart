import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../shell/shell_state.dart';
import '../../shell/video_surface.dart';
import '../library/artwork.dart';
import 'video_controls.dart';

/// Where a clip is watched: its picture while it plays, with its controls
/// over it, otherwise its cover, with a play button when it is not the
/// clip playing.
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
    final picture = isCurrent && !item.isAudio && !audioOnly;
    // Square in full screen, where the picture meets the screen's edges.
    return ValueListenableBuilder<bool>(
      valueListenable: ref.watch(windowControlsProvider).fullScreen,
      builder: (context, full, child) => ClipRRect(
        borderRadius: BorderRadius.circular(full ? 0 : MTCorners.desktop.card),
        child: child,
      ),
      child: _stage(context, ref, picture),
    );
  }

  Widget _stage(BuildContext context, WidgetRef ref, bool picture) {
    final p = MTThemeX.of(context).palette;
    return ColoredBox(
      color: MTPalette.fullscreenScrim,
      child: picture
          ? ClipVideoControls(
              short: item.isShortForm,
              child: ref.watch(videoSurfaceProvider).build(context),
            )
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
    );
  }
}
