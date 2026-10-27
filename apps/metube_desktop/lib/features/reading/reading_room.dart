import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_transcripts/mt_transcripts.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../data/library_data.dart';
import '../../data/transcripts_data.dart';
import '../../di.dart';
import '../../router.dart';
import '../../shell/pill.dart';
import '../../shell/shell_metrics.dart';
import '../../shell/video_surface.dart';
import '../clip/clip_state.dart';
import '../library/platform_label.dart';
import 'reading_article.dart';
import 'reading_export_menu.dart';
import 'reading_find.dart';
import 'reading_text.dart';

/// Where Ctrl+F goes while the reading room is open: its own find bar,
/// not the window's search. Null elsewhere.
final readingFindProvider = Provider<ValueNotifier<VoidCallback?>>((ref) {
  final hook = ValueNotifier<VoidCallback?>(null);
  ref.onDispose(hook.dispose);
  return hook;
});

/// **The reading room**: a clip's transcript read as an article, for a
/// lecture read in a third of the time it takes to hear. The picture, if
/// it is the clip playing, sits small in a corner.
class ReadingRoom extends ConsumerStatefulWidget {
  const ReadingRoom({super.key, required this.canonicalUrl});

  final String canonicalUrl;

  @override
  ConsumerState<ReadingRoom> createState() => _ReadingRoomState();
}

class _ReadingRoomState extends ConsumerState<ReadingRoom> {
  /// The narrowest the article gets to make room for the picture.
  static const double _narrowest = 520;

  late final MTPlayer _player = ref.read(playerProvider);
  late final ValueNotifier<VoidCallback?> _findHook = ref.read(
    readingFindProvider,
  );
  final _query = TextEditingController();
  final _findFocus = FocusNode();
  final _selection = SelectionListenerNotifier();
  var _finding = false;
  List<FindHit> _hits = const [];
  var _hit = 0;

  /// The paragraphs of the transcript last drawn, worked out once for it.
  Transcript? _drawn;
  List<ReadingParagraph> _paragraphs = const [];

  @override
  void initState() {
    super.initState();
    _findHook.value = _openFind;
  }

  @override
  void dispose() {
    if (_findHook.value == _openFind) _findHook.value = null;
    _query.dispose();
    _findFocus.dispose();
    _selection.dispose();
    super.dispose();
  }

  void _openFind() {
    setState(() => _finding = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _findFocus.requestFocus();
      _query.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _query.text.length,
      );
    });
  }

  void _closeFind() => setState(() {
    _finding = false;
    _hits = const [];
    _query.clear();
  });

  void _search(List<TranscriptSegment> segments) => setState(() {
    _hits = findIn(segments, _query.text);
    _hit = 0;
  });

  void _step(int by) {
    if (_hits.isEmpty) return;
    setState(() => _hit = (_hit + by) % _hits.length);
  }

  void _copy(PlaylistItem item, List<TranscriptSegment> segments) {
    if (!_selection.registered) return;
    final range = _selection.selection.range;
    if (range == null) return;
    final quote = quoteOf(_paragraphs, range.startOffset, range.endOffset);
    if (quote == null) return;
    final l = context.mtl;
    unawaited(
      Clipboard.setData(
        ClipboardData(
          text: quoteText(
            l,
            quote: quote,
            segments: segments,
            title: item.title,
            canonicalUrl: item.canonicalUrl,
          ),
        ),
      ),
    );
    showMTNotice(context, message: l.desktopQuoteCopied);
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryItemsProvider).valueOrNull ?? const [];
    return StreamBuilder<MTPlayerState>(
      stream: _player.states,
      initialData: _player.state,
      builder: (context, snap) {
        final current = (snap.data ?? _player.state).current;
        final listed = library
            .where((i) => i.canonicalUrl == widget.canonicalUrl)
            .firstOrNull;
        final item = listed != null
            ? toPlaylistItem(listed)
            : current?.canonicalUrl == widget.canonicalUrl
            ? current
            : null;
        if (item == null) {
          return Center(
            child: MTEmptyFrame(
              title: context.mtl.itemUnavailable,
              message: widget.canonicalUrl,
            ),
          );
        }
        final isCurrent = current?.canonicalUrl == item.canonicalUrl;
        return _room(context, item, isCurrent);
      },
    );
  }

  Widget _room(BuildContext context, PlaylistItem item, bool isCurrent) {
    final l = context.mtl;
    final url = item.canonicalUrl;
    final kept =
        ref.watch(transcriptLanguagesProvider(url)).valueOrNull ?? const [];
    final chosen = ref.watch(readingLanguageProvider(url));
    final transcript =
        kept.where((t) => t.language == chosen).firstOrNull ??
        ref
            .watch(
              transcriptForProvider((
                canonicalUrl: url,
                serverFilename: item.serverFilename,
              )),
            )
            .valueOrNull;
    if (transcript != _drawn) {
      _drawn = transcript;
      _paragraphs = transcript == null
          ? const []
          : paragraphsOf(transcript.segments);
    }
    final segments = transcript?.segments ?? const <TranscriptSegment>[];
    final picture = isCurrent && !item.isAudio && !ref.watch(audioOnlyProvider);
    return LayoutBuilder(
      builder: (context, box) {
        // Beside the article, which narrows for it, while the article
        // keeps a readable width; else above its title.
        final corner =
            box.maxWidth >=
            _narrowest + EmberShellSize.readingVideo + 3 * MTSpace.xl;
        final video = picture ? _Video(ref: ref) : null;
        final header = _Header(
          item: item,
          video: corner ? null : video,
          // A choice only where this computer keeps more than one.
          languages: kept.length < 2
              ? const []
              : [
                  for (final t in kept)
                    EmberPill(
                      label: mtLanguageName(
                        Transcript.baseLanguage(t.language),
                      ),
                      selected: t.language == transcript?.language,
                      onTap: () =>
                          ref
                                  .read(readingLanguageProvider(url).notifier)
                                  .state =
                              t.language,
                    ),
                ],
          export: transcript == null
              ? null
              : ReadingExportPill(
                  item: item,
                  meta: _metaOf(l, item),
                  transcript: transcript,
                  paragraphs: _paragraphs,
                ),
          onBack: () =>
              GoRouter.of(context).go(EmberRoutes.item(item.canonicalUrl)),
        );
        return Column(
          children: [
            if (_finding)
              ReadingFindBar(
                query: _query,
                focus: _findFocus,
                found: _hits.length,
                chosen: _hit,
                onChanged: (_) => _search(segments),
                onStep: _step,
                onClose: _closeFind,
              ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: segments.isEmpty
                        ? SingleChildScrollView(
                            padding: const EdgeInsets.all(MTSpace.xl),
                            child: MTReadableWidth(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  header,
                                  MTEmptyFrame(
                                    title: l.desktopNoTranscriptTitle,
                                    message: l.desktopNoTranscriptMessage,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ReadingArticle(
                            header: header,
                            segments: segments,
                            paragraphs: _paragraphs,
                            player: _player,
                            following: isCurrent,
                            hits: _hits,
                            hit: _finding && _hits.isNotEmpty ? _hit : null,
                            selection: _selection,
                            // Another clip starts there, staying in the room.
                            onJump: (line) => unawaited(
                              playFrom(
                                _player,
                                item,
                                isCurrent: isCurrent,
                                at: segments[line].start,
                              ),
                            ),
                            onCopy: () => _copy(item, segments),
                          ),
                  ),
                  if (corner && video != null)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        top: MTSpace.xl,
                        end: MTSpace.xl,
                      ),
                      child: SizedBox(
                        width: EmberShellSize.readingVideo,
                        child: video,
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The picture, small, while this clip plays.
class _Video extends StatelessWidget {
  const _Video({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(MTCorners.desktop.card),
    child: AspectRatio(
      aspectRatio: 16 / 9,
      child: ColoredBox(
        color: MTPalette.fullscreenScrim,
        child: ref.watch(videoSurfaceProvider).build(context),
      ),
    ),
  );
}

/// The way back to the clip, its title and source, and what the room does.
class _Header extends StatelessWidget {
  const _Header({
    required this.item,
    required this.video,
    required this.export,
    required this.onBack,
    this.languages = const [],
  });

  final PlaylistItem item;

  /// The transcript's languages to choose between.
  final List<Widget> languages;

  /// The export button, once there is a transcript to export.
  final Widget? export;

  /// The picture above the title, when the window has no room beside.
  final Widget? video;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l = context.mtl;
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final meta = _metaOf(l, item);
    return Padding(
      padding: const EdgeInsets.only(bottom: MTSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: MTSpace.sm,
            runSpacing: MTSpace.sm,
            children: [
              EmberPill(
                label: l.desktopReadingBack,
                icon: MTIcons.back,
                selected: false,
                onTap: onBack,
              ),
              ?export,
              ...languages,
            ],
          ),
          const SizedBox(height: MTSpace.lg),
          if (video case final video?) ...[
            Center(
              child: SizedBox(width: EmberShellSize.readingVideo, child: video),
            ),
            const SizedBox(height: MTSpace.lg),
          ],
          Text(
            item.title,
            textDirection: mtTextDirectionOf(
              item.title,
              Directionality.of(context),
            ),
            style: text.headlineSmall?.copyWith(color: p.ink),
          ),
          const SizedBox(height: MTSpace.xxs),
          Text(meta, style: text.bodySmall?.copyWith(color: p.ink3)),
          const SizedBox(height: MTSpace.sm),
          Text(
            l.desktopReadingHint,
            style: text.labelSmall?.copyWith(color: p.ink3),
          ),
        ],
      ),
    );
  }
}

/// The line under the title: channel, site and length.
String _metaOf(MTLocalizations l, PlaylistItem item) => mtMetaLine([
  ?item.uploader,
  platformLabel(l, MediaPlatform.detect(item.canonicalUrl)),
  if (item.duration case final d?) mtFormatDuration(d),
]);
