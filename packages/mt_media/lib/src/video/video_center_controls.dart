import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

import 'mt_video_session.dart';

/// Screen centre: ten seconds back and forward around a play button in the
/// accent colour.
class MTVideoCenterControls extends StatelessWidget {
  const MTVideoCenterControls({super.key, required this.session});

  final MTVideoSession session;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final l10n = context.mtl;
    // **Pinned left to right, like the timeline under them.** Media time
    // runs left to right in every language, so buttons that followed the
    // interface direction would read as reversed (see MTProgressSlider).
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _Seek(
            icon: MTIcons.back10,
            label: l10n.seekBackward10,
            onTap: () => session.seekBy(const Duration(seconds: -10)),
          ),
          const SizedBox(width: MTSpace.xxl),
          Material(
            color: p.accent.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: session.playPause,
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                width: 58,
                height: 58,
                child: MTIconSwap(
                  icon: session.isPlaying ? MTIcons.pause : MTIcons.playFill,
                  size: 26,
                  color: p.onAccent,
                ),
              ),
            ),
          ),
          const SizedBox(width: MTSpace.xxl),
          _Seek(
            icon: MTIcons.forward10,
            label: l10n.seekForward10,
            onTap: () => session.seekBy(const Duration(seconds: 10)),
          ),
        ],
      ),
    );
  }
}

class _Seek extends StatelessWidget {
  const _Seek({required this.icon, required this.label, required this.onTap});

  final MTIconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onTap,
    tooltip: label,
    icon: MTIcon(icon, size: 28, color: MTPalette.serverCardInk),
  );
}
