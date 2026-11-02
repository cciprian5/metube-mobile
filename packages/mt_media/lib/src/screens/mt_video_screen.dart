import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

import '../models/playlist_item.dart';
import '../video/mt_orientation.dart';
import '../video/mt_picture_in_picture.dart';
import '../video/mt_video_fullscreen.dart';
import '../video/mt_video_open.dart';
import '../video/mt_video_session.dart';
import '../video/video_area.dart';
import '../video/video_side_panel.dart';
import '../widgets/mt_queue_panel.dart';
import '../widgets/mt_up_next_list.dart';
import 'video_info_sheet.dart';
import '../video/mt_captions.dart';
import '../widgets/mt_chapters.dart';

/// One action in the portrait player (offline, share, add to a list…).
/// The app supplies them, because mt_media knows neither the server nor
/// the indexes.
class MTPlayerAction {
  const MTPlayerAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
    this.main = false,
    this.inMenu = false,
  });

  final MTIconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlighted;

  /// The one pill outlined in the ink: what the sheet is mostly for.
  final bool main;

  /// Under the ⋮ at the end of the row rather than a pill of its own
  /// (sharing, the original link); the reels' side buttons show it anyway.
  final bool inMenu;
}

/// The portrait video player (Wahaj reference B): the video leads with a
/// light sheet beneath it, running title, then actions, then mode, then the
/// "up next" list. Going back offers "continue as background audio?" from
/// the same second.
class MTVideoScreen extends StatelessWidget {
  const MTVideoScreen({
    super.key,
    required this.session,
    this.actions = const [],
    this.artwork,
    this.subtitleBuilder,
    this.onShowPlaylist,
    this.onContinueAsAudio,
    this.shouldOfferContinueAsAudio,
    this.playlistName,
    this.membershipLine,
    this.byline,
    this.fullscreenPanel,
    this.captions,
    this.chapters,
    this.chaptersFolded,
  });

  final MTVideoSession session;

  /// The subtitles of the item playing, asked again as the queue moves;
  /// null, or a null answer, draws none and offers no CC button.
  final MTCaptions? Function(PlaylistItem item)? captions;
  final List<MTPlayerAction> actions;

  /// A panel the app offers beside the video in full screen, for the item
  /// playing; portrait offers the same through [actions].
  final MTVideoPanel? Function(PlaylistItem item)? fullscreenPanel;
  final MTArtworkBuilder? artwork;

  /// The meta line under the title (platform, uploader), supplied by the
  /// app.
  final String Function(BuildContext context, PlaylistItem item)?
  subtitleBuilder;
  final VoidCallback? onShowPlaylist;

  /// Smart handover: continue the same item as audio from the same second.
  /// **Awaited before closing the screen:** it used to be
  /// called without awaiting and the player closed immediately, so the
  /// session provider was disposed (autoDispose) while the handover sat on
  /// an `await`. Either a `StateError` meant the audio never started, or
  /// `duration` became nothing, so a position near the end was **saved
  /// rather than cleared** and the clip "resumed" at the credits forever.
  final Future<void> Function(PlaylistItem item, Duration position)?
  onContinueAsAudio;

  /// **When the question is asked** (field report 2026-09-02: "after
  /// continuing in the background and pressing back the message appears; it
  /// should not"). The condition used to be `onContinueAsAudio == null`
  /// alone, so it asked on every exit, even after the user had already
  /// moved the clip to audio. Only the app knows the audio player's state,
  /// so the app decides.
  final bool Function()? shouldOfferContinueAsAudio;
  final String? playlistName;

  /// **Where the clip belongs** (field report 2026-09-04): "which tag it is
  /// under, or which playlist it was added to". Shown in landscape beneath
  /// the title; portrait shows it through [subtitleBuilder] in the info
  /// sheet.
  final String? membershipLine;

  /// See [MTVideoInfoSheet.byline].
  final Widget Function(BuildContext context, PlaylistItem item)? byline;

  /// The chapters of the item playing, asked again as the queue moves: cut
  /// into the progress bar, named beside the time, and listed under the
  /// buttons. Empty, or null, for a clip without any.
  final List<MTChapter> Function(PlaylistItem item)? chapters;

  /// Whether the chapters under the buttons are folded away; see
  /// [MTChapterSection.folded].
  final ValueNotifier<bool>? chaptersFolded;

  MTPictureInPicture get _pip => MTPictureInPicture.instance;

  bool get _offersAudio =>
      onContinueAsAudio != null && (shouldOfferContinueAsAudio?.call() ?? true);

  /// **A tilt opens full screen and tilting back closes it** (decision
  /// 2026-09-05), and the button stays for anyone who has locked rotation
  /// in their system settings.
  @override
  Widget build(BuildContext context) => MTRotationScope(
    open: (byRotation) => _openFullscreen(context, byRotation),
    builder: (context, openFullscreen) => _body(context, openFullscreen),
  );

  /// **A tablet on its side shows the video and its details together**:
  /// a phone on its side has too little height for both, so there the video
  /// fills the screen, but a tablet has room for the queue beside it. The
  /// shorter side tells them apart, so a phone held sideways never gets it.
  static bool _isWide(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return size.width >= MTBreakpoint.expanded &&
        size.shortestSide >= MTBreakpoint.tabletSide;
  }

  Widget _wide(BuildContext context, VoidCallback openFullscreen) => Row(
    children: [
      Expanded(
        child: VideoArea(
          session: session,
          captions: captions,
          chapters: chapters,
          artwork: artwork,
          fill: true,
          playlistName: playlistName,
          membershipLine: membershipLine,
          onBack: () => Navigator.of(context).maybePop(),
          onFullscreen: openFullscreen,
          onQueue: () => _openQueue(context),
        ),
      ),
      SizedBox(
        width: MTBreakpoint.sidePanel,
        child: SafeArea(
          left: false,
          right: false,
          child: Padding(
            padding: const EdgeInsets.only(top: MTSpace.lg),
            child: MTVideoInfoSheet(
              session: session,
              actions: actions,
              artwork: artwork,
              subtitleBuilder: subtitleBuilder,
              playlistName: playlistName,
              onShowPlaylist: onShowPlaylist,
              byline: byline,
              chapters: chapters,
              chaptersFolded: chaptersFolded,
            ),
          ),
        ),
      ),
    ],
  );

  Widget _body(BuildContext context, VoidCallback openFullscreen) => PopScope(
    canPop: !_offersAudio,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _askContinueAsAudio(context);
    },
    child: Scaffold(
      backgroundColor: MTThemeX.of(context).palette.bg,
      body: ListenableBuilder(
        listenable: Listenable.merge([session, _pip.active]),
        // **In landscape the video alone fills the screen** (field report
        // 2026-09-05): leaving full screen by hand left a squeezed video
        // over a light sheet. Landscape is a form of this screen, and so is
        // a corner of the screen, which an upright clip shapes upright.
        builder: (context, _) => !_pip.active.value && _isWide(context)
            ? _wide(context, openFullscreen)
            : _pip.active.value ||
                  MediaQuery.orientationOf(context) == Orientation.landscape
            ? VideoArea(
                session: session,
                captions: captions,
                chapters: chapters,
                artwork: artwork,
                fill: true,
                playlistName: playlistName,
                membershipLine: membershipLine,
                onBack: () => Navigator.of(context).maybePop(),
                onFullscreen: openFullscreen,
                onQueue: () => _openQueue(context),
              )
            : Column(
                children: [
                  VideoArea(
                    session: session,
                    captions: captions,
                    chapters: chapters,
                    artwork: artwork,
                    playlistName: playlistName,
                    membershipLine: membershipLine,
                    onBack: () => Navigator.of(context).maybePop(),
                    onFullscreen: openFullscreen,
                    onQueue: () => _openQueue(context),
                  ),
                  Expanded(
                    child: MTVideoInfoSheet(
                      session: session,
                      actions: actions,
                      artwork: artwork,
                      subtitleBuilder: subtitleBuilder,
                      playlistName: playlistName,
                      onShowPlaylist: onShowPlaylist,
                      byline: byline,
                      chapters: chapters,
                      chaptersFolded: chaptersFolded,
                    ),
                  ),
                ],
              ),
      ),
    ),
  );

  Future<void> _openFullscreen(BuildContext context, bool byRotation) =>
      Navigator.of(context).push(
        mtFullscreenRoute(
          session.controller,
          from: byRotation || _isWide(context)
              ? null
              : mtUprightPlayerPlace(context, VideoArea.share),
          (_) => MTVideoFullscreenPage(
            session: session,
            byRotation: byRotation,
            artwork: artwork,
            playlistName: playlistName,
            membershipLine: membershipLine,
            onShowPlaylist: onShowPlaylist,
            panel: fullscreenPanel,
            captions: captions,
            chapters: chapters,
          ),
        ),
      );

  void _openQueue(BuildContext context) {
    final ordered = session.orderedItems;
    final currentUrl = session.current?.canonicalUrl;
    showMTQueueSheet(
      context,
      items: ordered,
      currentIndex: ordered.indexWhere((i) => i.canonicalUrl == currentUrl),
      artwork: artwork,
      playlistName: playlistName,
      // Only this page is popped once the queue sheet is done; see
      // _askContinueAsAudio.
      liveness: session,
      paused: () => !session.isPlaying,
      onShowAll: onShowPlaylist,
      onSelect: (index) =>
          session.jumpTo(session.items.indexOf(ordered[index])),
    );
  }

  /// Asks whether to carry on as audio from the same second, then leaves.
  Future<void> _askContinueAsAudio(BuildContext context) async {
    final item = session.current;
    final navigator = Navigator.of(context);
    // **We only pop our own page** (field report 2026-09-03): the handover
    // to audio can take a while, and the user may have left another way in
    // the meantime, so a blind `pop()` afterwards popped **the shell
    // itself** and nothing was left: a black screen.
    final route = ModalRoute.of(context);
    void popSelf() {
      if (route == null || route.isCurrent) navigator.pop();
    }

    if (item == null) return popSelf();
    final position = session.position;
    await session.savePosition();
    if (!context.mounted) return;
    final l10n = context.mtl;

    final choice = await showMTDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.continueAsAudioTitle),
        content: Text(l10n.continueAsAudioBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.continueAsAudioNo),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.continueAsAudio),
          ),
        ],
      ),
    );
    if (choice == true) await onContinueAsAudio?.call(item, position);
    popSelf();
  }
}
