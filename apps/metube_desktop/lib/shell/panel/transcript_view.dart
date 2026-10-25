import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_transcripts/mt_transcripts.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../data/transcripts_data.dart';

/// The playing clip's transcript, lighting the line being said and keeping
/// it in view; a click on a line plays from there.
class TranscriptView extends ConsumerWidget {
  const TranscriptView({super.key, required this.item, required this.player});

  final PlaylistItem item;
  final MTPlayer player;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.mtl;
    final transcript = ref.watch(
      transcriptForProvider((
        canonicalUrl: item.canonicalUrl,
        serverFilename: item.serverFilename,
      )),
    );
    return switch (transcript) {
      AsyncData(value: final t?) when !t.isEmpty => _Lines(
        key: ValueKey(item.canonicalUrl),
        segments: t.segments,
        player: player,
      ),
      AsyncLoading() => const Center(child: MTSpinner()),
      _ => Center(
        child: SingleChildScrollView(
          child: MTEmptyFrame(
            title: l.desktopNoTranscriptTitle,
            message: l.desktopNoTranscriptMessage,
          ),
        ),
      ),
    };
  }
}

class _Lines extends StatefulWidget {
  const _Lines({super.key, required this.segments, required this.player});

  final List<TranscriptSegment> segments;
  final MTPlayer player;

  @override
  State<_Lines> createState() => _LinesState();
}

class _LinesState extends State<_Lines> {
  final _current = GlobalKey();
  StreamSubscription<Duration>? _positions;
  int? _now;

  /// When the user last scrolled by hand. Following waits a moment after
  /// it, so reading back up is not yanked down to the line being said.
  DateTime _scrolledByHand = DateTime.fromMillisecondsSinceEpoch(0);
  static const _handPause = Duration(seconds: 4);

  @override
  void initState() {
    super.initState();
    _show(widget.player.position);
    _positions = widget.player.positionStream.listen(_show);
  }

  @override
  void dispose() {
    unawaited(_positions?.cancel());
    super.dispose();
  }

  void _show(Duration position) {
    final now = segmentAt(widget.segments, position);
    if (now == _now || !mounted) return;
    setState(() => _now = now);
    if (DateTime.now().difference(_scrolledByHand) < _handPause) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _current.currentContext;
      if (target == null || !target.mounted) return;
      unawaited(
        Scrollable.ensureVisible(
          target,
          alignment: 0.3,
          duration: mtMotionDuration(context, MTMotion.medium),
          curve: MTMotion.ease,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, box) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // At most a third of the panel, so in a short window with large
          // text the hint is clipped rather than pushing the lines out. Not
          // a Flexible: beside the Expanded below it would halve the list.
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: box.maxHeight / 3),
            child: ClipRect(
              child: Text(
                context.mtl.desktopTranscriptHint,
                style: text.labelSmall?.copyWith(color: p.ink3),
              ),
            ),
          ),
          const SizedBox(height: MTSpace.sm),
          Expanded(
            child: NotificationListener<UserScrollNotification>(
              onNotification: (n) {
                if (n.direction != ScrollDirection.idle) {
                  _scrolledByHand = DateTime.now();
                }
                return false;
              },
              // A column, not a lazy list, so the line being said always has
              // a place to scroll to; a transcript is a few hundred lines.
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, line) in widget.segments.indexed)
                      _Line(
                        key: i == _now ? _current : null,
                        line: line,
                        current: i == _now,
                        onTap: () => unawaited(widget.player.seek(line.start)),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    super.key,
    required this.line,
    required this.current,
    required this.onTap,
  });

  final TranscriptSegment line;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final corner = BorderRadius.circular(MTCorners.desktop.chip);
    return Semantics(
      button: true,
      selected: current,
      child: InkWell(
        onTap: onTap,
        borderRadius: corner,
        child: AnimatedContainer(
          duration: mtMotionDuration(context, MTMotion.fast),
          padding: const EdgeInsets.symmetric(
            horizontal: MTSpace.sm,
            vertical: MTSpace.xs,
          ),
          decoration: BoxDecoration(
            color: current ? p.accentSoft : null,
            borderRadius: corner,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: MTSpace.xxl * 2,
                child: Text(
                  mtFormatDuration(line.start),
                  style: text.labelSmall?.tabular.copyWith(
                    color: current ? p.accentInk : p.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  line.text,
                  textDirection: mtTextDirectionOf(
                    line.text,
                    Directionality.of(context),
                  ),
                  style: text.bodySmall?.copyWith(
                    color: current ? p.ink : p.ink2,
                    fontWeight: current ? FontWeight.w700 : null,
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
