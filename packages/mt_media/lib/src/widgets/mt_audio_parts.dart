import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

import '../models/playlist_item.dart';
import '../playback/audio_handler.dart';
import 'media_time.dart';
import 'mt_extra_button.dart';
import 'mt_progress_slider.dart';
import 'mt_tilted_artwork.dart';

/// The source chip, the title and the artist line under the cover.
class MTAudioTitles extends StatelessWidget {
  const MTAudioTitles({
    super.key,
    required this.item,
    required this.media,
    required this.index,
    required this.total,
    this.playlistName,
    this.showSourceChip = true,
    this.favorite = false,
    this.onFavorite,
  });

  final PlaylistItem item;
  final MediaItem media;
  final int index;
  final int total;
  final String? playlistName;
  final bool showSourceChip;

  /// The heart beside the title, shown when [onFavorite] is given.
  final bool favorite;
  final VoidCallback? onFavorite;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final l10n = context.mtl;
    final parts = [
      if (media.artist != null && media.artist!.isNotEmpty) media.artist!,
      if (playlistName != null) '«$playlistName»',
      if (total > 1) mtLtrRun(l10n.playlistOf(index + 1, total)),
    ];
    final title = MTForeignText(
      media.title,
      center: true,
      maxLines: 2,
      style: text.titleLarge!.copyWith(fontSize: 19),
    );
    return Column(
      children: [
        if (showSourceChip) ...[
          MTSourceChip(local: item.hasLocal),
          const SizedBox(height: MTSpace.sm),
        ],
        if (onFavorite case final toggle?)
          Row(
            children: [
              // Balances the heart, so the title stays centred.
              const SizedBox(width: kMinInteractiveDimension),
              Expanded(child: title),
              MTFavoriteButton(favorite: favorite, onPressed: toggle),
            ],
          )
        else
          title,
        if (parts.isNotEmpty) ...[
          const SizedBox(height: MTSpace.xxs),
          Text(
            parts.join(' · '),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall!.copyWith(color: p.ink3),
          ),
        ],
      ],
    );
  }
}

/// The progress bar, fed by the player's position.
class MTAudioSlider extends StatelessWidget {
  const MTAudioSlider({super.key, required this.handler, required this.media});

  final MTAudioHandler handler;
  final MediaItem media;

  @override
  Widget build(BuildContext context) => StreamBuilder<Duration>(
    stream: handler.positionStream,
    builder: (context, snapshot) => MTProgressSlider(
      position: snapshot.data ?? Duration.zero,
      duration: media.duration,
      onSeek: handler.seek,
    ),
  );
}

/// The line under the controls: **speed at one end and the queue at the
/// other, as light marks** (mobile plan, page 02), and an app's extra
/// between them. Two framed pills with their names written out ("Speed
/// 1.0×", "Queue 12") were heavier than the transport above them; the
/// names stay for screen readers.
class MTAudioSubControls extends StatelessWidget {
  const MTAudioSubControls({
    super.key,
    required this.handler,
    this.onQueue,
    this.extra,
  });

  final MTAudioHandler handler;

  /// Null where the queue is already on screen, as a tab beside the player.
  final VoidCallback? onQueue;
  final MTExtraAction? extra;

  @override
  Widget build(BuildContext context) {
    final l10n = context.mtl;
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    return StreamBuilder<PlaybackState>(
      stream: handler.playbackState,
      builder: (context, snapshot) {
        final speed = snapshot.data?.speed ?? 1.0;
        return Row(
          children: [
            _Mark(
              onTap: () => handler.setSpeed(mtNextSpeed(speed)),
              label: l10n.playbackSpeed,
              child: Text(
                '${mtFormatSpeed(speed)}×',
                style: text.labelLarge!.copyWith(color: p.ink2).tabular,
              ),
            ),
            const Spacer(),
            if (extra case final extra?) MTExtraButton(extra: extra),
            const Spacer(),
            if (onQueue case final open?)
              _Mark(
                onTap: open,
                label: l10n.queueLabel,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.queue_music_rounded, size: 20, color: p.ink2),
                    const SizedBox(width: MTSpace.xxs),
                    Text(
                      '${handler.items.length}',
                      style: text.labelSmall!.copyWith(color: p.ink2),
                    ),
                  ],
                ),
              )
            else
              // Keeps the extra in the middle when the queue is elsewhere.
              const SizedBox(width: _Mark.size),
          ],
        );
      },
    );
  }
}

/// A light tappable mark: no frame, a finger-sized target, its name read
/// out rather than written.
class _Mark extends StatelessWidget {
  const _Mark({required this.onTap, required this.label, required this.child});

  final VoidCallback onTap;
  final String label;
  final Widget child;

  static const double size = 48;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(MTRadius.chip),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: size, minHeight: size),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: MTSpace.sm),
          child: Center(widthFactor: 1, child: child),
        ),
      ),
    ),
  );
}
