import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../../di.dart';
import '../artwork_view.dart';

/// The cover of a running download, as soon as the server lists one; the
/// card falls back to its icon until then. Server-hosted pictures go with
/// the server's headers, and nobody else's (see `imageHeadersFor`).
Widget? taskThumbnail(WidgetRef ref, DownloadTask task) => artworkFor(
  task.thumbnail,
  headers: switch (task.thumbnail) {
    final url? => ref.read(apiClientProvider)?.imageHeadersFor(url),
    null => null,
  },
  decodeWidth: 150,
);

/// The server's speed while it fetches the clip, and nothing in any other
/// phase.
String? taskSpeed(DownloadTask task) =>
    task.phase == TaskPhase.polling && task.speed != null
    ? mtFormatTransferRate(task.speed!)
    : null;
