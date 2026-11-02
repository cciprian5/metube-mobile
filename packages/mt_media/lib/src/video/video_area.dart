import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

import '../models/playlist_item.dart';
import '../widgets/mt_chapters.dart';
import '../widgets/mt_up_next_list.dart';
import 'mt_captions.dart';
import 'mt_video_controls.dart';
import 'mt_video_frame.dart';
import 'mt_video_session.dart';

/// The video and its controls in the player: a band at the top of the
/// screen upright, or the whole screen when [fill] is set.
class VideoArea extends StatelessWidget {
  const VideoArea({
    super.key,
    required this.session,
    required this.onBack,
    required this.onFullscreen,
    required this.onQueue,
    this.artwork,
    this.playlistName,
    this.membershipLine,
    this.fill = false,
    this.captions,
    this.chapters,
  });

  /// The share of the screen's height the player takes on a phone upright.
  static const double share = 0.32;

  /// Fills the screen in landscape instead of 32% of its height.
  final bool fill;
  final MTArtworkBuilder? artwork;
  final MTCaptions? Function(PlaylistItem item)? captions;
  final List<MTChapter> Function(PlaylistItem item)? chapters;

  final MTVideoSession session;
  final VoidCallback onBack;
  final VoidCallback onFullscreen;
  final VoidCallback onQueue;
  final String? playlistName;
  final String? membershipLine;

  @override
  Widget build(BuildContext context) {
    final controller = session.controller;
    final ready = controller != null && controller.value.isInitialized;
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: fill
            ? double.infinity
            : MediaQuery.sizeOf(context).height * share,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: MTPalette.serverCardBg),
            if (ready)
              Center(
                child: MTVideoFrame(
                  controller: controller,
                  item: session.current,
                  artwork: artwork,
                ),
              )
            else
              Center(
                child: session.error != null
                    ? Icon(
                        Icons.error_outline_rounded,
                        color: MTPalette.serverCardInk,
                      )
                    : const CircularProgressIndicator(),
              ),
            if (ready)
              MTVideoControls(
                session: session,
                captions: switch (session.current) {
                  final item? => captions?.call(item),
                  null => null,
                },
                chapters: switch (session.current) {
                  final item? => chapters?.call(item) ?? const [],
                  null => const [],
                },
                playlistName: playlistName,
                membershipLine: membershipLine,
                onBack: onBack,
                onToggleFullscreen: onFullscreen,
                onQueue: onQueue,
              ),
          ],
        ),
      ),
    );
  }
}
