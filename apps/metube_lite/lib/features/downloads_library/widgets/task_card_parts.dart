import 'package:flutter/widgets.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../artwork_view.dart';

/// The cover of a running download, as soon as the server lists one; the
/// card falls back to its icon until then.
Widget? taskThumbnail(DownloadTask task) =>
    artworkFor(task.thumbnail, decodeWidth: 150);

/// The server's speed while it fetches the clip, and nothing in any other
/// phase (the pull to the phone has no speed reading).
String? taskSpeed(DownloadTask task) =>
    task.phase == TaskPhase.polling && task.speed != null
    ? mtFormatTransferRate(task.speed!)
    : null;
