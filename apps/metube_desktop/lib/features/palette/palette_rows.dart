import 'package:flutter/material.dart';
import 'package:mt_media/library.dart';
import 'package:mt_media/mt_media.dart' show mtFormatDuration;
import 'package:mt_transcripts/mt_transcripts.dart';
import 'package:mt_ui/mt_ui.dart';

import 'palette_model.dart';

/// A kind of result's name above its rows.
class PaletteHeader extends StatelessWidget {
  const PaletteHeader(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(
      MTSpace.md,
      MTSpace.sm,
      MTSpace.md,
      MTSpace.xxs,
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelMedium
          ?.copyWith(color: MTThemeX.of(context).palette.ink3),
    ),
  );
}

/// A row the mouse can open too.
class PaletteRowTap extends StatelessWidget {
  const PaletteRowTap({super.key, required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, child: child);
}

/// The frame of every row: the chosen one is drawn as the sidebar draws
/// the current place.
class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.selected,
    required this.child,
    this.lead,
  });

  final MTIconData icon;
  final bool selected;
  final Widget child;

  /// Drawn in place of the icon (a moment's time).
  final Widget? lead;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    return Container(
      color: selected ? p.accentSoft : null,
      padding: const EdgeInsets.symmetric(
        horizontal: MTSpace.md,
        vertical: MTSpace.xs,
      ),
      child: Row(
        children: [
          lead ??
              MTIcon(
                icon,
                size: MTSpace.lg,
                color: selected ? p.accentInk : p.ink2,
              ),
          const SizedBox(width: MTSpace.sm),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class TitleRow extends StatelessWidget {
  const TitleRow({super.key, required this.item, required this.selected});

  final LibraryItem item;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    return _Row(
      icon: item.isAudio ? MTIcons.headphones : MTIcons.play,
      selected: selected,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodyMedium?.copyWith(
              color: selected ? p.accentInk : p.ink,
            ),
          ),
          if (item.uploader case final uploader? when uploader.isNotEmpty)
            Text(
              uploader,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.labelSmall?.copyWith(color: p.ink3),
            ),
        ],
      ),
    );
  }
}

/// A moment: when it was said, the line with the query's words lit, and
/// the clip it is in.
class SaidRow extends StatelessWidget {
  const SaidRow({
    super.key,
    required this.match,
    required this.query,
    required this.selected,
  });

  final SaidMatch match;
  final String query;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final line = match.hit.text;
    final base = text.bodyMedium?.copyWith(color: p.ink);
    var at = 0;
    final spans = <TextSpan>[];
    for (final (start, end) in SearchText.matchRanges(line, query)) {
      if (start > at) spans.add(TextSpan(text: line.substring(at, start)));
      spans.add(
        TextSpan(
          text: line.substring(start, end),
          style: TextStyle(color: p.accentInk, fontWeight: FontWeight.w700),
        ),
      );
      at = end;
    }
    if (at < line.length) spans.add(TextSpan(text: line.substring(at)));
    return _Row(
      icon: MTIcons.transcript,
      selected: selected,
      // A time reads left to right in either language.
      lead: Text(
        mtLtrRun(mtFormatDuration(match.hit.start)),
        style: text.labelMedium?.tabular.copyWith(
          color: p.accentInk,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(style: base, children: spans),
            textDirection: mtForeignLine(context, line).$1,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            match.item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.labelSmall?.copyWith(color: p.ink3),
          ),
        ],
      ),
    );
  }
}

class CommandRow extends StatelessWidget {
  const CommandRow({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
  });

  final MTIconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    return _Row(
      icon: icon,
      selected: selected,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: selected ? p.accentInk : p.ink),
      ),
    );
  }
}
