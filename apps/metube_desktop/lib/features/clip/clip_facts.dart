import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_media/library.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../shell/video_surface.dart';

/// The file's facts under a clip's title: the quality that plays, the
/// format, the size and where it is kept, as "1080p · MKV · 412 MB · On
/// the server". Each part shows only when known.
///
/// **The quality is the picture's decoded size**, so it is shown only
/// while the clip's picture is on screen: the server's record holds the
/// quality that was asked for ("best"), not the one that came.
class ClipFacts extends ConsumerWidget {
  const ClipFacts({super.key, required this.entry, required this.picture});

  final LibraryItem entry;

  /// This clip's picture is the one playing.
  final bool picture;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.mtl;
    final p = MTThemeX.of(context).palette;
    final surface = ref.watch(videoSurfaceProvider);
    return ValueListenableBuilder<Size?>(
      valueListenable: surface.pictureSize,
      builder: (context, size, _) {
        final line = mtMetaLine([
          if (picture && size != null)
            mtLtrRun('${size.shortestSide.round()}p'),
          fileFormatOf(entry),
          if (entry.sizeBytes case final bytes?) mtFormatSize(bytes),
          if (entry.onServer) l.onServerPhase,
          if (entry.isOffline) l.filterOffline,
        ]);
        if (line.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: MTSpace.xxs),
          child: Text(
            line,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: p.ink3),
          ),
        );
      },
    );
  }
}

/// The file's format from its name, here or on the server, in capitals;
/// null when the name has none, rather than a guess.
String? fileFormatOf(LibraryItem item) {
  final name = (item.localPath ?? item.serverFilename)
      ?.split(RegExp(r'[/\\]'))
      .last;
  if (name == null) return null;
  final dot = name.lastIndexOf('.');
  if (dot <= 0 || dot == name.length - 1) return null;
  final ext = name.substring(dot + 1);
  return RegExp(r'^[A-Za-z0-9]{1,5}$').hasMatch(ext) ? ext.toUpperCase() : null;
}
