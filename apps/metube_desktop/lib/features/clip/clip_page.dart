import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../data/library_data.dart';
import '../../di.dart';
import '../../router.dart';
import '../../shell/pill.dart';
import '../../shell/shell_metrics.dart';
import '../../shell/shell_state.dart';
import '../library/platform_label.dart';
import '../lists/list_dialogs.dart';
import 'clip_actions.dart';
import 'clip_menu.dart';
import 'clip_stage.dart';
import 'clip_state.dart';
import 'copy_pills.dart';
import 'tags_dialog.dart';

/// One clip: its picture in the content (a 16:9 stage, or a 9:16 column
/// for a short), its title, and what can be done with it. The side panel
/// beside follows it with the transcript.
///
/// **A short is watched in its lane**: ↑/↓ or the wheel move to the next
/// short of the list it came from, each one loops, and a double click
/// marks it a favourite. There is no swipe player on a computer.
///
/// F11 fills the screen, Esc comes back.
class ClipPage extends ConsumerStatefulWidget {
  const ClipPage({super.key, required this.canonicalUrl});

  final String canonicalUrl;

  @override
  ConsumerState<ClipPage> createState() => _ClipPageState();
}

class _ClipPageState extends ConsumerState<ClipPage> {
  late final MTPlayer _player = ref.read(playerProvider);
  DateTime _lastWheel = DateTime.fromMillisecondsSinceEpoch(0);

  /// One wheel notch is one short; a flick of the wheel sends a burst.
  static const _wheelPause = Duration(milliseconds: 350);

  @override
  void dispose() {
    // The loop belongs to watching shorts here; left playing in the bar,
    // the lane moves on by itself.
    unawaited(_player.setLooping(false));
    super.dispose();
  }

  void _fullScreen(bool on) =>
      ref.read(windowControlsProvider).setFullScreen(on);

  void _onWheel(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final now = DateTime.now();
    if (now.difference(_lastWheel) < _wheelPause) return;
    _lastWheel = now;
    unawaited(
      event.scrollDelta.dy > 0
          ? _player.skipToNext()
          : _player.skipToPrevious(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controls = ref.watch(windowControlsProvider);
    final library = ref.watch(libraryItemsProvider).valueOrNull ?? const [];
    return StreamBuilder<MTPlayerState>(
      stream: _player.states,
      initialData: _player.state,
      builder: (context, snap) {
        final current = (snap.data ?? _player.state).current;
        final listed = library
            .where((i) => i.canonicalUrl == widget.canonicalUrl)
            .firstOrNull;
        final opened = listed != null
            ? toPlaylistItem(listed)
            : current?.canonicalUrl == widget.canonicalUrl
            ? current
            : null;
        if (opened == null) {
          return Center(
            child: MTEmptyFrame(
              title: context.mtl.itemUnavailable,
              message: widget.canonicalUrl,
            ),
          );
        }
        // In the lane the page follows the player from short to short.
        final short = opened.isShortForm;
        final item = short && (current?.isShortForm ?? false)
            ? current!
            : opened;
        final entry = library
            .where((i) => i.canonicalUrl == item.canonicalUrl)
            .firstOrNull;
        final isCurrent = current?.canonicalUrl == item.canonicalUrl;
        if (short && isCurrent) unawaited(_player.setLooping(true));
        final stage = ClipMenuArea(
          item: item,
          child: ClipStage(
            item: item,
            cover: entry?.thumbnail,
            isCurrent: isCurrent,
            audioOnly: ref.watch(audioOnlyProvider),
            onPlay: () => unawaited(_player.playItems([item])),
          ),
        );
        // Its keys (F11, Esc, and ↑/↓ between shorts) are the window's:
        // see EmberKeyboard.
        return ValueListenableBuilder<bool>(
          valueListenable: controls.fullScreen,
          builder: (context, full, _) => full
              ? _Shorts.wrap(short, stage, this)
              : short
              ? _ShortsLayout(
                  stage: _Shorts.wrap(true, stage, this),
                  item: item,
                )
              : _ClipLayout(
                  stage: stage,
                  item: item,
                  entry: entry,
                  isCurrent: isCurrent,
                  onFullScreen: () => _fullScreen(true),
                ),
        );
      },
    );
  }
}

/// A short's stage: the 9:16 column, the wheel and the double click.
abstract final class _Shorts {
  static Widget wrap(bool short, Widget stage, _ClipPageState page) {
    if (!short) return stage;
    return Listener(
      onPointerSignal: page._onWheel,
      child: GestureDetector(
        onDoubleTap: () {
          final url = page._player.state.current?.canonicalUrl;
          if (url != null) {
            unawaited(page.ref.read(clipActionsProvider).toggleFavorite(url));
          }
        },
        child: Center(
          child: AspectRatio(aspectRatio: 9 / 16, child: stage),
        ),
      ),
    );
  }
}

class _ShortsLayout extends StatelessWidget {
  const _ShortsLayout({required this.stage, required this.item});

  final Widget stage;
  final PlaylistItem item;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(MTSpace.xl),
      child: Column(
        children: [
          Expanded(child: stage),
          const SizedBox(height: MTSpace.md),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            textDirection: mtTextDirectionOf(
              item.title,
              Directionality.of(context),
            ),
            style: text.titleSmall?.copyWith(color: p.ink),
          ),
          const SizedBox(height: MTSpace.xxs),
          Text(
            context.mtl.desktopShortsHint,
            textAlign: TextAlign.center,
            style: text.labelSmall?.copyWith(color: p.ink3),
          ),
        ],
      ),
    );
  }
}

class _ClipLayout extends ConsumerWidget {
  const _ClipLayout({
    required this.stage,
    required this.item,
    required this.entry,
    required this.isCurrent,
    required this.onFullScreen,
  });

  final Widget stage;
  final PlaylistItem item;
  final LibraryItem? entry;
  final bool isCurrent;
  final VoidCallback onFullScreen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.mtl;
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final actions = ref.read(clipActionsProvider);
    final audioOnly = ref.watch(audioOnlyProvider);
    final theater = ref.watch(theaterProvider);
    final favorite = entry?.favorite ?? false;
    final url = item.canonicalUrl;
    final meta = mtMetaLine([
      ?item.uploader,
      platformLabel(l, MediaPlatform.detect(url)),
      if (item.duration case final d?) mtFormatDuration(d),
    ]);
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        padding: const EdgeInsets.all(MTSpace.xl),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: math.min(EmberShellSize.clipMax, box.maxWidth),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(aspectRatio: 16 / 9, child: stage),
                const SizedBox(height: MTSpace.lg),
                Text(
                  item.title,
                  textDirection: mtTextDirectionOf(
                    item.title,
                    Directionality.of(context),
                  ),
                  style: text.titleLarge?.copyWith(color: p.ink),
                ),
                const SizedBox(height: MTSpace.xxs),
                Text(meta, style: text.bodySmall?.copyWith(color: p.ink3)),
                const SizedBox(height: MTSpace.md),
                Wrap(
                  spacing: MTSpace.sm,
                  runSpacing: MTSpace.sm,
                  children: [
                    if (entry case final entry?)
                      ...copyPills(context, ref, entry),
                    EmberPill(
                      label: favorite
                          ? l.removeFromFavorites
                          : l.addToFavorites,
                      icon: favorite ? MTIcons.favoriteOn : MTIcons.favorite,
                      selected: favorite,
                      onTap: () => unawaited(actions.toggleFavorite(url)),
                    ),
                    EmberPill(
                      label: l.tags,
                      icon: MTIcons.tags,
                      selected: false,
                      onTap: () => unawaited(showTagsDialog(context, url)),
                    ),
                    EmberPill(
                      label: l.addToPlaylist,
                      icon: MTIcons.queue,
                      selected: false,
                      onTap: () =>
                          unawaited(showAddToPlaylistDialog(context, item)),
                    ),
                    if (isCurrent && !item.isAudio)
                      EmberPill(
                        label: l.audioOnly,
                        icon: MTIcons.headphones,
                        selected: audioOnly,
                        onTap: () => unawaited(
                          ref.read(audioOnlyProvider.notifier).set(!audioOnly),
                        ),
                      ),
                    if (!item.isAudio) ...[
                      EmberPill(
                        label: l.desktopTheater,
                        icon: MTIcons.theater,
                        selected: theater,
                        onTap: () =>
                            ref.read(theaterProvider.notifier).state = !theater,
                      ),
                      EmberPill(
                        label: l.enterFullscreen,
                        icon: MTIcons.fullscreen,
                        selected: false,
                        onTap: onFullScreen,
                      ),
                    ],
                    EmberPill(
                      label: l.desktopReadingRoom,
                      icon: MTIcons.reading,
                      selected: false,
                      onTap: () =>
                          GoRouter.of(context).go(EmberRoutes.reading(url)),
                    ),
                    EmberPill(
                      label: l.openOriginalLink,
                      icon: MTIcons.external,
                      selected: false,
                      onTap: () => unawaited(actions.openOriginal(url)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
