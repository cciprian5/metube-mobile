import 'dart:io';

import 'package:mt_core/mt_core.dart';

/// [name] as Windows accepts it: the characters it forbids become `_`, and
/// trailing dots and spaces, which it drops silently, go.
String windowsSafeName(String name) {
  final safe = name
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
      .replaceAll(RegExp(r'[. ]+$'), '');
  return safe.isEmpty ? '_' : safe;
}

/// The folder below the download folder that a server file keeps on this
/// computer: its folder on the server, each part a name Windows accepts
/// (`..` and `.` become `_`). Empty for a file at the top, and for a path
/// the traversal guard refuses: that copy fails at the guard, and no
/// folder is made on the way there.
String serverSubfolder(String serverPath) {
  if (!ServerPath.isSafe(serverPath)) return '';
  return ServerPath.folderOf(serverPath)
      .split('/')
      .where((part) => part.isNotEmpty)
      .map(windowsSafeName)
      .join(r'\');
}

/// [path], or the same name with " (2)", " (3)"… when taken, as Explorer
/// numbers a copy.
String freeTarget(String path) {
  if (!File(path).existsSync()) return path;
  final slash = path.lastIndexOf('\\');
  final dot = path.lastIndexOf('.');
  final hasExt = dot > slash + 1;
  final stem = hasExt ? path.substring(0, dot) : path;
  final ext = hasExt ? path.substring(dot) : '';
  for (var i = 2; i < 1000; i++) {
    final candidate = '$stem ($i)$ext';
    if (!File(candidate).existsSync()) return candidate;
  }
  return path;
}
