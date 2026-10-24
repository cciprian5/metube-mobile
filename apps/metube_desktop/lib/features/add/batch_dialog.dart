import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart' show mtFormatDuration;
import 'package:mt_ui/mt_ui.dart';

import '../../data/downloads_data.dart';
import '../../shell/shell_metrics.dart';
import '../library/artwork.dart';
import 'add_options.dart';

/// How a playlist's clips are read; a test puts its own in.
final playlistReaderProvider =
    Provider<Future<PlaylistPreview?> Function(String url)>(
      (ref) =>
          (url) => switch (PlaylistDetector.detect(url)) {
            PlaylistKind.youtube => YoutubePlaylistResolver().resolve(url),
            PlaylistKind.soundcloud => SoundCloudResolver().resolveSet(url),
            PlaylistKind.none => Future.value(),
          },
    );

/// A playlist's clips, read from its own site (never through the server,
/// so its password goes nowhere else).
final playlistPreviewProvider = FutureProvider.autoDispose
    .family<PlaylistPreview?, String>(
      (ref, url) => ref.read(playlistReaderProvider)(url),
    );

/// A YouTube playlist or a SoundCloud set: every clip with its picture and
/// length, all ticked, to untick what is not wanted; one choice for all;
/// sent one by one, and gathered into a saved list of the same name.
Future<void> showBatchDialog(BuildContext context, String url) =>
    showDialog<void>(context: context, builder: (_) => _BatchDialog(url));

class _BatchDialog extends ConsumerStatefulWidget {
  const _BatchDialog(this.url);

  final String url;

  @override
  ConsumerState<_BatchDialog> createState() => _BatchDialogState();
}

class _BatchDialogState extends ConsumerState<_BatchDialog> {
  AddChoice _choice = const AddChoice();

  /// Unticked, by link; everything else is sent.
  final _left = <String>{};

  void _send(PlaylistPreview list, List<String> urls) {
    final l = context.mtl;
    final engine = ref.read(downloadEngineProvider);
    if (engine == null) {
      showMTNotice(context, message: l.noServerTitle);
      return;
    }
    final soundOnly = list.kind == PlaylistKind.soundcloud;
    final choice = soundOnly ? _choice.copyWith(audio: true) : _choice;
    final ids = [
      for (final url in urls)
        engine
            .submit(
              url,
              choice.qualityFor(url),
              isBatchMember: urls.length > 1,
              folder: choice.folderPath,
            )
            .id,
    ];
    if (urls.length > 1) {
      unawaited(ref.read(batchCollectorProvider).begin(list.title, ids));
    }
    Navigator.of(context).pop();
    showMTNotice(
      context,
      message: l.addedNToServer(ids.length),
      kind: MTNoticeKind.done,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.mtl;
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final asked = ref.watch(playlistPreviewProvider(widget.url));
    final list = asked.valueOrNull;
    final tracks = list?.tracks ?? const <PlaylistTrack>[];
    final chosen = [
      for (final track in tracks)
        if (!_left.contains(track.url)) track,
    ];
    final total = chosen.fold(
      Duration.zero,
      (sum, track) => sum + (track.duration ?? Duration.zero),
    );
    // A watch link inside a playlist can still be added on its own.
    final single = UrlKit.youtubeVideoId(widget.url);

    final Widget body;
    if (asked.isLoading) {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MTFilmStrip(),
          const SizedBox(height: MTSpace.sm),
          Text(l.batchLoading, style: text.bodySmall),
        ],
      );
    } else if (list == null || tracks.isEmpty) {
      body = MTEmptyFrame(
        title: l.failedToLoadPlaylist,
        message: l.couldNotLoadPlaylist,
        actionLabel: l.retry,
        onAction: () => ref.invalidate(playlistPreviewProvider(widget.url)),
      );
    } else {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  mtMetaLine([
                    l.batchSelectedOf(chosen.length, tracks.length),
                    if (total > Duration.zero) mtFormatDuration(total),
                  ]),
                  style: text.labelMedium?.copyWith(color: p.ink2),
                ),
              ),
              MTLinkButton(
                label: chosen.length == tracks.length
                    ? l.deselectAll
                    : l.selectAll,
                onPressed: () => setState(() {
                  if (chosen.length == tracks.length) {
                    _left.addAll(tracks.map((t) => t.url));
                  } else {
                    _left.clear();
                  }
                }),
              ),
            ],
          ),
          const SizedBox(height: MTSpace.xs),
          Row(
            children: [
              const SizedBox(width: _tickWidth + _thumbWidth + MTSpace.sm),
              Expanded(
                child: Text(
                  l.titleLabel,
                  style: text.labelSmall?.copyWith(color: p.ink3),
                ),
              ),
              Text(
                l.columnLength,
                style: text.labelSmall?.copyWith(color: p.ink3),
              ),
            ],
          ),
          Divider(color: p.line, height: MTSpace.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: _listHeight),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: tracks.length,
              itemBuilder: (context, i) {
                final track = tracks[i];
                final on = !_left.contains(track.url);
                return InkWell(
                  onTap: () => setState(
                    () => on ? _left.add(track.url) : _left.remove(track.url),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: MTSpace.xxs),
                    child: Row(
                      children: [
                        SizedBox(
                          width: _tickWidth,
                          child: Checkbox(
                            value: on,
                            onChanged: (v) => setState(
                              () => v ?? false
                                  ? _left.remove(track.url)
                                  : _left.add(track.url),
                            ),
                          ),
                        ),
                        MTMediaThumb(
                          width: _thumbWidth,
                          height: _thumbWidth * 9 / 16,
                          child: artworkFor(
                            ref,
                            context,
                            track.thumbnail,
                            width: _thumbWidth,
                          ),
                        ),
                        const SizedBox(width: MTSpace.sm),
                        Expanded(
                          child: Text(
                            track.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textDirection: mtTextDirectionOf(
                              track.title,
                              Directionality.of(context),
                            ),
                            style: text.bodySmall?.copyWith(
                              color: on ? p.ink : p.ink3,
                            ),
                          ),
                        ),
                        if (track.duration case final d?)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(
                              start: MTSpace.sm,
                            ),
                            child: Text(
                              mtFormatDuration(d),
                              style: text.labelSmall?.tabular.copyWith(
                                color: p.ink3,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: MTSpace.md),
          AddOptions(
            choice: _choice,
            youtube: list.kind == PlaylistKind.youtube,
            audioOnly: list.kind == PlaylistKind.soundcloud,
            onChanged: (choice) => setState(() => _choice = choice),
          ),
        ],
      );
    }

    return AlertDialog(
      title: Text(
        list?.title ?? l.batchTitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      content: SizedBox(
        width: EmberShellSize.wideDialog,
        child: SingleChildScrollView(child: body),
      ),
      actions: [
        if (single != null && list != null)
          TextButton(
            onPressed: () =>
                _send(list, ['https://www.youtube.com/watch?v=$single']),
            child: Text(l.batchThisVideoOnly),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: list == null || chosen.isEmpty
              ? null
              : () => _send(list, [for (final t in chosen) t.url]),
          child: Text(l.batchDownloadSelected),
        ),
      ],
    );
  }

  static const double _tickWidth = 40;
  static const double _thumbWidth = 64;
  static const double _listHeight = 360;
}
