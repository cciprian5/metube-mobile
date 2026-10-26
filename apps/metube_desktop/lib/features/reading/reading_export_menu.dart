import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_transcripts/mt_transcripts.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../data/folders_data.dart';
import '../../shell/context_menu.dart';
import '../../shell/pill.dart';
import 'reading_export.dart';
import 'reading_pdf.dart';
import 'reading_text.dart';

/// The reading room's "Export": the transcript saved for the phone, as
/// subtitles, as Markdown or as a PDF, through Windows' save dialog; a
/// notice then offers the folder it went to.
class ReadingExportPill extends ConsumerWidget {
  const ReadingExportPill({
    super.key,
    required this.item,
    required this.meta,
    required this.transcript,
    required this.paragraphs,
  });

  final PlaylistItem item;

  /// The line under the title: channel, site and length.
  final String meta;
  final Transcript transcript;
  final List<ReadingParagraph> paragraphs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.mtl;
    return Builder(
      builder: (context) => EmberPill(
        label: l.desktopExport,
        icon: MTIcons.saveTo,
        selected: false,
        onTap: () async {
          // Under the pill, from its start.
          final box = context.findRenderObject()! as RenderBox;
          final rtl = Directionality.of(context) == TextDirection.rtl;
          final at = box.localToGlobal(
            rtl
                ? box.size.bottomRight(Offset.zero)
                : box.size.bottomLeft(Offset.zero),
          );
          final form = await showEmberMenu(context, at, [
            EmberMenuEntry(
              ReadingExport.phone,
              MTIcons.offline,
              l.desktopExportPhone,
            ),
            EmberMenuEntry(
              ReadingExport.srt,
              MTIcons.transcript,
              l.desktopExportSrt,
            ),
            EmberMenuEntry(
              ReadingExport.markdown,
              MTIcons.copy,
              l.desktopExportMarkdown,
            ),
            EmberMenuEntry(
              ReadingExport.pdf,
              MTIcons.reading,
              l.desktopExportPdf,
            ),
          ]);
          if (form != null && context.mounted) {
            await _export(context, ref, form);
          }
        },
      ),
    );
  }

  Future<void> _export(
    BuildContext context,
    WidgetRef ref,
    ReadingExport form,
  ) async {
    final folders = ref.read(desktopFoldersProvider);
    final name = exportName(item.title, form);
    final segments = transcript.segments;
    final fallback = Directionality.of(context);
    final String? saved;
    if (form == ReadingExport.pdf) {
      final bytes = await pdfOf(
        fonts: await loadReadingFonts(),
        title: item.title,
        meta: meta,
        canonicalUrl: item.canonicalUrl,
        paragraphs: paragraphs,
        segments: segments,
        fallback: fallback,
      );
      saved = await folders.saveBytes(name: name, bytes: bytes);
    } else {
      saved = await folders.saveText(
        name: name,
        text: switch (form) {
          ReadingExport.phone => phoneFileOf(transcript),
          ReadingExport.srt => srtOf(segments),
          _ => markdownOf(
            title: item.title,
            meta: meta,
            canonicalUrl: item.canonicalUrl,
            paragraphs: paragraphs,
            segments: segments,
          ),
        },
      );
    }
    if (saved == null || !context.mounted) return;
    final l = context.mtl;
    showMTNotice(
      context,
      message: l.desktopExported(name),
      actionLabel: l.desktopShowInFolder,
      onAction: () => unawaited(folders.reveal(saved!)),
    );
  }
}
