import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../l10n/bidi.dart';
import '../l10n/l10n.dart';
import '../theme/mt_theme.dart';
import '../tokens/tokens.dart';
import '../wahaj/mt_hover_lift.dart';
import 'mt_desktop_app.dart';
import 'mt_favorite.dart';
import 'mt_highlight_surface.dart';
import 'mt_media_grid_cover.dart';
import 'mt_location_badge.dart';
import 'mt_media_card.dart' show MTMediaLocation;
import 'mt_platform_chip.dart';

/// The library card **led by its cover**: a 16:9 thumbnail first, with two
/// lines of title underneath. It serves two modes:
///
/// - **Grid**, the default: two columns, so a row shows twice what the
/// list shows and scanning video visually is far quicker.
/// - **Cards** ([feed], requested 2026-09-08, the YouTube pattern): one
/// column with a wide cover and larger text, for unhurried browsing.
///
/// **The two modes share the cover on purpose**: duration, favourite and
/// "more" all live over the thumbnail, and two copies of that would
/// diverge at the first edit. The only differences are text sizes and
/// whether the location badge is shown.
///
/// Presentation only, exactly like [MTMediaCard]: it knows nothing of a
/// server or an index.
class MTMediaGridCard extends StatelessWidget {
  const MTMediaGridCard({
    super.key,
    required this.title,
    this.thumbnail,
    this.duration,
    this.platform = MTPlatformKind.other,
    this.subtitle,
    this.location = MTMediaLocation.none,
    this.locationLabel,
    this.selected = false,
    this.highlighted = false,
    this.playing = false,
    this.paused = false,
    this.favorite = false,
    this.audio = false,
    this.feed = false,
    this.onTap,
    this.onLongPress,
    this.onFavoriteToggle,
    this.onMore,
  });

  final String title;
  final Widget? thumbnail;
  final String? duration;
  final MTPlatformKind platform;
  final String? subtitle;
  final MTMediaLocation location;
  final String? locationLabel;
  final bool selected;
  final bool highlighted;
  final bool playing;

  /// [playing] means "this is the current item"; [paused] means it is
  /// suspended, so the indicator shows still instead of dancing over a clip
  /// that is not running.
  final bool paused;
  final bool favorite;

  /// An audio file: its cover carries a music-note mark.
  final bool audio;

  /// Cards mode: a single column, so there is room for larger text and a
  /// location badge.
  final bool feed;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onMore;

  String _semanticsLabel(MTLocalizations l10n) => [
    title,
    ?subtitle,
    // The length is on the cover only, which the reader is not given.
    ?duration,
    ?locationLabel,
    if (audio) l10n.filterAudio,
    if (favorite) l10n.favorites,
    if (playing) l10n.nowPlaying,
  ].join(l10n.listSeparator);

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final l10n = context.mtl;
    final text = Theme.of(context).textTheme;
    final (titleDirection, titleAlign) = mtForeignLine(context, title);

    // One node that is the button: its name, and the tap and focus of the
    // ink well beneath, which a split node had read out as an image. What
    // the card shows is in the name already, so the reader skips it; the
    // cover's own buttons stay apart, each with its own tap.
    return Semantics(
      container: true,
      button: onTap != null,
      selected: selected,
      label: _semanticsLabel(l10n),
      child: MTHoverLift(
        borderRadius: BorderRadius.circular(MTRadius.card),
        builder: (context, hovered) => MTHighlightSurface(
          selected: selected,
          highlighted: highlighted,
          borderRadius: BorderRadius.circular(MTRadius.card),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(MTRadius.card),
            onLongPress: onLongPress == null
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    onLongPress!();
                  },
            child: Padding(
              padding: const EdgeInsets.all(MTSpace.xxs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  MTMediaGridCover(
                    hovered: hovered,
                    duration: duration,
                    playing: playing,
                    paused: paused,
                    favorite: favorite,
                    audio: audio,
                    onFavoriteToggle: onFavoriteToggle,
                    onMore: onMore,
                    child: thumbnail,
                  ),
                  SizedBox(height: feed ? MTSpace.sm : MTSpace.xs),
                  ExcludeSemantics(
                    child: Text(
                      title,
                      textDirection: titleDirection,
                      textAlign: titleAlign,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: (feed ? text.bodyMedium! : text.bodySmall!)
                          .copyWith(
                            color: p.ink,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  ExcludeSemantics(
                    child: Row(
                      children: [
                        if (favorite && onFavoriteToggle == null)
                          const MTFavoriteMark(),
                        // On a computer the platform pills above the grid
                        // say it already; a coloured mark under every
                        // title only repeated them.
                        if (platform != MTPlatformKind.other &&
                            !MTDesktopApp.isDesktop(context)) ...[
                          MTPlatformChip(kind: platform),
                          const SizedBox(width: MTSpace.xxs),
                        ],
                        if (subtitle != null)
                          Flexible(
                            child: Text(
                              subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: (feed ? text.bodySmall! : text.labelSmall!)
                                  .copyWith(color: p.ink3),
                            ),
                          ),
                        // The location badge appears in cards mode only: a grid
                        // cell is half a screen wide and already carries the
                        // chip and the meta line.
                        if (feed &&
                            location != MTMediaLocation.none &&
                            locationLabel != null) ...[
                          const SizedBox(width: MTSpace.xs),
                          Flexible(
                            child: MTLocationBadge(
                              location: location,
                              label: locationLabel!,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
