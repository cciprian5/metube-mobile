import 'dart:io';

/// [name] as Windows accepts it: the characters it forbids become `_`, and
/// trailing dots and spaces, which it drops silently, go.
String windowsSafeName(String name) {
  final safe = name
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
      .replaceAll(RegExp(r'[. ]+$'), '');
  return safe.isEmpty ? '_' : safe;
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
